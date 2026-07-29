pico-8 cartridge // http://www.pico-8.com
version 43
__lua__

   
PLAYFIELD_BOTTOM = 95

BALL_SPEEDS = {0.341, 0.683, 1.024}
BALL_HITS_MAX = 12
BALL_VZONES = {-1.171,-0.780,-0.390,0,0,0.390,0.780,1.171}
BALL_ZONE_SIZE = 0.75
SERVE_DELAY = 102
SERVE_X = 66

C_BG = 0
C_PADDLE = 1
C_BALL = 2
C_SCORE = 3
C_TRAIL1 = 4
C_TRAIL2 = 5

DEBUG_ACT = nil

SCORE_Y = 8
SCORE_H = 12

ACT_PALETTES = {
 {0,7,7,7,    6,5,    6},
 {8,9,7,10,   15,9,   9},
 {3,10,7,11,  6,11,   1},
 {1,5,7,12,   12,13,  13},
 {5,6,7,9,    6,5,    4}
}

ACT_CONFIGS = {
 {palette=1, phosphor_mode=1},
 {palette=2, phosphor_mode=0},
 {palette=3, phosphor_mode=1},
 {palette=4, phosphor_mode=1},
 {palette=5, phosphor_mode=1},
 {palette=1, phosphor_mode=0, ball_count=40, speed_tier_pin=3, ai_enabled=true}
}



SCAN_PATTERN = {0x80,0x40,0x20,0x10,0x08,0x04,0x02,0x01}

CRAWL_RATE = 12
crt = {phase=0, st=0, ty=-1, tw=240, phos=1, tlen=2, cpu=false}

function set_palette(n)
    local a = ACT_PALETTES[mid(1,DEBUG_ACT or n,#ACT_PALETTES)]
    poke(0x5f10, a[1],a[2],a[3],a[4],a[5],a[6], 6,7,8,9,10,11,12,13,14,15)
    poke(0x5f60, a[1],a[2],a[3],a[7],a[5],a[6], 6,7,8,9,10,11,12,13,14,15)
end

function set_scanlines()
    local p = SCAN_PATTERN[(crt.phase % 8) + 1]
    memset(0x5f70, 0, 12)
    for y=SCORE_Y,SCORE_Y+SCORE_H-1 do
        local i = 0x5f70 + flr(y/8)
        poke(i, peek(i) | (p & (1 << (y%8))))
    end
    memset(0x5f7c, p, 4)
end

function init_crt()
    poke(0x5f5f, 0x10)
    set_scanlines()
end

PHOS_NAMES = {"off","ball","full"}

function init_menu()
    menuitem(1,"act "..(DEBUG_ACT or "auto"),function()
        DEBUG_ACT = (DEBUG_ACT or 0) + 1
        if (DEBUG_ACT > #ACT_CONFIGS) DEBUG_ACT = nil
        p:configure(ACT_CONFIGS[mid(1,DEBUG_ACT or gm.level_index,#ACT_CONFIGS)])
        p:start_match()
        init_menu()
        return true
    end)
    menuitem(2,"accel "..p.cfg.paddle_accel[2],function(b)
        local v = p.cfg.paddle_accel[2] + (b&1>0 and -0.02 or 0.02)
        p.cfg.paddle_accel[2] = mid(0.02,v,0.5)
        init_menu()
        return true
    end)
    menuitem(3,"pmax "..p.cfg.paddle_max_speed[2],function(b)
        local v = p.cfg.paddle_max_speed[2] + (b&1>0 and -0.25 or 0.25)
        p.cfg.paddle_max_speed[2] = mid(0.5,v,6)
        init_menu()
        return true
    end)
    menuitem(4,"phosphor "..PHOS_NAMES[crt.phos+1],function()
        crt.phos = (crt.phos + 1) % 3
        init_menu()
        return true
    end)
    menuitem(5,"cpu "..(crt.cpu and "on" or "off"),function()
        crt.cpu = not crt.cpu
        init_menu()
        return true
    end)
end

TEAR_H = 6

function scan_row(y)
    return (y >= SCORE_Y and y < SCORE_Y+SCORE_H) or y > PLAYFIELD_BOTTOM
end

function update_crt()
    crt.st += 1
    if crt.st >= CRAWL_RATE then
        crt.st = 0
        crt.phase += 1
        set_scanlines()
    end
    if crt.ty < 0 then
        crt.tw -= 1
        if (crt.tw <= 0) crt.ty = 127
    else
        crt.ty -= 4
        if crt.ty < 0 then
            crt.ty = -1
            crt.tw = 420 + rnd(600)
        end
    end
end

function apply_tear()
    if (crt.ty < 0) return
    for i=0,TEAR_H-1 do
        local y = crt.ty + i
        if y < 128 and scan_row(y) then
            local a = 0x6000 + (y*64)
            memcpy(0x8000, a, 63)
            memcpy(a+1, 0x8000, 63)
        end
    end
end

function coin_flip()
    if rnd(2) > 1 then
        return 1
    end
    return -1
end

timers = {}
function add_timer(d,e)
	t = {
        time=0,
        delaytime=d,
		event=e,
		tick=nil
    }
    add(timers,t)
	return t
end

function update_timers()
	for x=#timers, 1, -1 do
		timer = timers[x]
		timer.time += 1
		if timer.time > timer.delaytime then
			timer.event()
			del(timers,timer)
		end
	end
end

game_manager = {}
game_manager.states = {title=0,menu=1,options=2,level=3,gameover=4,intermission=5}
game_manager.events = {level_complete=10}
game_manager.inputevents = {key_pressed=20}
game_manager.timerevents = {timer_fired=30}
function game_manager:new()
	local gm = {
		state = game_manager.states.menu,
		levels = {},
		level_index = 1
	}
	setmetatable(gm, {
		__index = function(t, k)
			if k == "level" then
				return t.levels[t.level_index]
			else
				return game_manager[k]
			end
		end
	})
	return gm
end

function game_manager:change_state(s)
	self.state = s
end

function game_manager:add_level(l)
	add(self.levels,l)
end

function game_manager:event(e)
	local events = {
		[game_manager.events.level_complete] = function()
			self.level_index += 1
			self:change_state(game_manager.states.intermission)
        end
	}
	
	local event = events[e]
    if event then
        event()
	elseif self.state == game_manager.states.level then
		self.level:event(e)
    end
end

function game_manager:input(e)
	local inputevents = {
		[game_manager.inputevents.key_pressed] = function()
			if self.state == game_manager.states.menu or game_manager.states.intermission then
				if self.level_index <= #self.levels then
					self:change_state(game_manager.states.level)
					self.level:load()
				else
					self:change_state(game_manager.states.gameover)
				end
			end
        end
	}

	local input = inputevents[e]
    if input then
        input()
    elseif self.state == game_manager.states.level then
		self.level:event(e)
    end
end

function game_manager:update() 
    update_timers()
	update_input()

	if self.state == game_manager.states.level then
		self.level:update()
    elseif gm.state == game_manager.states.gameover then
        update_gameover_state()
        self.level.textbox:update()
    elseif gm.state == game_manager.states.intermission then
        self.level.pong:update_game_state()
	end
end

function game_manager:draw()
    pong.draw_board()

	local states = {
		[game_manager.states.title] = function()
			print("title",44,60,C_SCORE)
        end,
		[game_manager.states.menu] = function()
			print("press ❎ to start",32,64,C_SCORE)
        end,
		[game_manager.states.options] = function()
			print("options",44,60,C_SCORE)
        end,
        [game_manager.states.level] = function()
            self.level:draw()
        end,
		[game_manager.states.gameover] = function()
			print("game over",45,60,C_SCORE)
            self.level.textbox:draw()
		end,
		[game_manager.states.intermission] = function()
            pong.draw_balls()
            print("press ❎ to continue",32,64,C_SCORE)
		end
	}
	
	local state = states[self.state]
    if state then
        state()
    else
        printh('not draw state for '..self.state)
    end
end

level = {}
level.__index = level
level.events = {phrase_complete=40,section_complete=41,sequence_complete=42,level_complete=43,tb_open=44,tb_closed=45}
function level:new(d,tb,p)
	local l = {
		dialogue=d,
		textbox=tb,
		pong=p
	}
	setmetatable(l,level)
	return l
end

function level:load()
	self.textbox.sectiontitle=self.dialogue.title
	self.textbox.sectionphrase=self.dialogue.phrase.text
	self.textbox.rect.color=C_BG
    self.pong:configure(ACT_CONFIGS[mid(1,DEBUG_ACT or gm.level_index,#ACT_CONFIGS)])
    self.pong:start_match()
    self.dialogue:init()

    player1.visible = true
    player2.visible = true
end

function level:event(e)
    local actions = {
        [level.events.tb_open] = function()
            self.dialogue:load_next()
        end,
        [level.events.tb_closed] = function()
            if self.dialogue.continuesequence then
                printh('continued sequence')
                add_timer(100,function () self.textbox:open(function() gm:event(level.events.tb_open) end) end)
            else
                printh('stopped sequence')
            end
        end,
        [level.events.sequence_complete] = function()
            self.textbox:close(function () gm:event(game_manager.events.level_complete) end)
        end,
        [level.events.section_complete] = function()
            self.textbox.sectionphrase=self.dialogue.phrase.text
            self.textbox:close(function () gm:event(level.events.tb_closed) end)
        end,
        [level.events.phrase_complete] = function()
            self.textbox.sectionphrase=self.dialogue.phrase.text
        end
    }

    local action = actions[e]
    if action then
        action()
    else
        self.dialogue:event(e)
    end
end

function level:printdebugdialogue()
    printh('--[[dialog info')
    printh('# sections: '..#self.dialogue.sections)
    printh('# phrases: '..#self.dialogue.sections[self.dialogue.index].phrases)
    printh('section: '..self.dialogue.index)
    printh('phrase: '..self.dialogue.sections[self.dialogue.index].index)
    printh('--]]')
end

function level:input()
end

function level:update()
	self.textbox:update()
    self.dialogue:update()
    self.pong:update_game_state()
end

function level:draw()
    pong.draw_balls()
	tb:draw()
end

function _init()
	gm = game_manager:new()
    gm.screenwidth = 128
    gm.screenheight = 128
    init_crt()
	tb = textbox:new(0,96,127,31,C_BG)
    p = pong:new()
    p:reset_game()
    init_menu()
	gm:add_level(level:new(dialogues[1],tb,p))
	gm:add_level(level:new(dialogues[2],tb,p))
	gm:add_level(level:new(dialogues[3],tb,p))
	gm:add_level(level:new(dialogues[4],tb,p))
	gm:add_level(level:new(dialogues[5],tb,p))
end

function _update60()
	gm:update()
    update_crt()
end

function update_input()
	if btnp(❎) then
		gm:input(game_manager.inputevents.key_pressed)
	end
end

function update_gameover_state()
    if btnp(❎) then
        p:reset_game()
    end
end

function _draw()
    if crt.phos == 2 then
        pal(1,C_TRAIL1) pal(2,C_TRAIL1) pal(3,C_TRAIL1)
        pal(C_TRAIL1,C_TRAIL2) pal(C_TRAIL2,C_BG)
        sspr(0,0,128,128,0,0)
        pal(1,1) pal(2,2) pal(3,3)
        pal(C_TRAIL1,C_TRAIL1) pal(C_TRAIL2,C_TRAIL2)
    else
        cls(C_BG)
    end

    gm:draw()
    apply_tear()

    if (crt.phos == 2) memcpy(0x0000,0x6000,0x2000)
    if (crt.cpu) print(flr(stat(1)*100).."%",1,1,C_SCORE)
end

function draw_score()



    print("\^w\^t" .. hud.p1_score,hud.p1_x-(#tostr(hud.p1_score)*8),hud.p1_y,hud.p1_color)
    print("\^w\^t" .. hud.p2_score,hud.p2_x,hud.p2_y,hud.p2_color)
end

function draw_debug()
    for x=1,#walls do 
        if (walls[x].collision_debug_draw) then 
            if (walls[x].collsionpt) then
                rect(walls[x].collsionpt.x,walls[x].collsionpt.y,walls[x].collsionpt.x+2,walls[x].collsionpt.y+2,walls[x].collisiontextboxcolor)
            end
        end
    end

    if (player1.prediction) then
        local pr = player1.prediction
        rect(pr.x-1,pr.y-1,pr.x+1,pr.y+1,player1.collisiontextboxcolor)
        print(p:ai_level(),2,2,player1.collisiontextboxcolor)
    end
end

-->8
AI_LEVELS = {
 {12,1},{18,5},{24,10},{30,15},{36,20},{42,25},{48,30},{54,35},{60,40},
 {66,45},{72,50},{78,55},{84,60},{90,65},{96,70},{102,75},{108,80}
}
AI_TIE_TIER = 9

DEFAULT_CFG = {
 paddle_height={6,6},
 paddle_accel={0.08,0.4},
 paddle_max_speed={2.5,4.5},
 ball_count=1,
 ball_mode="replica",
 ball_mode_pool=nil,
 speed_tier_pin=0,
 win_score={11,11},
 sudden_death=false,
 scoring_model="rally",
 score_multiplier_com=1,
 initial_score_com=0,
 scoring_enabled=true,
 com_serves_every_point=false,
 ai_enabled=false,
 ai_mode="self_balancing",
 ai_tier=AI_TIE_TIER,
 palette=1,
 phosphor_mode=1,
 nickname=nil
}

pong = {}
pong.__index = pong
function pong:new()
	local p = {}
    setmetatable(p,pong)
    p:configure()
	return p
end

function pong:configure(cfg)
    local c = {}
    for k,v in pairs(DEFAULT_CFG) do c[k] = v end
    if cfg then
        for k,v in pairs(cfg) do c[k] = v end
    end
    self.cfg = c
    self.com_handicap = c.initial_score_com
    self.winner = 0
end

function pong:reset_game()
    self:start_match()
    gm:change_state(game_manager.states.menu)
end

function pong:start_match()
    self.winner = 0
    self.pending = nil
    self:init_board()
    self:init_hud()
    self:init_players()
    self:init_balls(self.cfg.ball_count)

    crt.phos = self.cfg.phosphor_mode
    set_palette(self.cfg.palette)
end

function pong:init_board()
    walls = {}
    local top = self:create_wall(0,-3,gm.screenwidth,3)
    top.visible = false
    add(walls, top)

    local bottom = self:create_wall(0,PLAYFIELD_BOTTOM+1,gm.screenwidth,3)
    bottom.visible = false
    add(walls, bottom)

    self:init_net()
end

function pong:init_net()
    net = {
        block_width = 0,
        block_height = 1,
        block_space = 3,
        x = 64,
        y = 0,
        color = C_PADDLE,
        drawnet = function()
            ypos = net.y
            while (ypos + net.block_height <= PLAYFIELD_BOTTOM) do
                rectfill(net.x,ypos,net.x+net.block_width,ypos+net.block_height,net.color)
                ypos += net.block_height + net.block_space
            end
        end
    }
end

function pong:init_hud()
    hud = {
        p1_score = self.cfg.initial_score_com,
        p1_x = 42,
        p1_y = 8,
        p1_color = C_SCORE,
        p2_score = 0,
        p2_x = 87,
        p2_y = 8,
        p2_color = C_SCORE,
    }
end

function pong:init_players()
    player1 = self:make_paddle(20,1)
    player1.prediction = nil
    player1.collisiontextboxcolor = 14
    player2 = self:make_paddle(108,2)
end

function pong:make_paddle(x,side)
    local h = self.cfg.paddle_height[side]
    local p = self:create_wall(x,((PLAYFIELD_BOTTOM+1)/2)-(h/2),1,h)
    p.dir = 0
    p.v = 0
    p.side = side
    p.miny = h
    p.maxy = (PLAYFIELD_BOTTOM+1) - h - h
    p.visible = false
    add(walls, p)
    return p
end

function pong:move_paddle(p,d)
    if d == 0 then
        p.v = 0
    else
        if (p.dir != d) p.v = 0
        p.dir = d
        p.v = min(p.v + self.cfg.paddle_accel[p.side], self.cfg.paddle_max_speed[p.side])
        p.y += p.v * d
    end
    p.y = mid(p.miny, p.y, p.maxy)
end

function pong:init_balls(n)
    balls = {}
    for i=1,(n or 1) do
        self:add_ball()
    end
end

function pong:add_ball()
    local rad = 1
    local b = {
        radius = rad,
        color = C_BALL,
        x = SERVE_X,
        y = rad + rnd(PLAYFIELD_BOTTOM - rad - rad),
        hits = 0,
        serving = 0,
        mode = self.cfg.ball_mode,
        tc = 0,
        t1x = SERVE_X,
        t1y = 0,
        t2x = SERVE_X,
        t2y = 0,
        t3x = SERVE_X,
        t3y = 0,
        dx = BALL_SPEEDS[1] * coin_flip(),
        dy = BALL_VZONES[8] * coin_flip()
    }
    add(balls, b)
    return b
end

function pong:ai_level()
    if (self.cfg.ai_mode == "fixed") then
        return mid(1, self.cfg.ai_tier, #AI_LEVELS)
    end
    local diff = (hud.p1_score - self.com_handicap) - hud.p2_score
    return mid(1, AI_TIE_TIER + diff, #AI_LEVELS)
end

function pong:create_prediction(s,dx,r,ex,ey,x,y,d)
    local p = {
        since=s,
        dx=dx,
        radius=r,
        exactx=ex,
        exacty=ey,
        x=x,
        y=y,
        d=d
    }
    return p
end

function pong:create_wall(xpos,ypos,w,h)
    wall = {
        width = w,
        height = h,
        x = xpos,
        y = ypos,
        color = C_PADDLE,
        visible = true,
        collsion = true,
        collsionpt = nil,
        collisiontextboxcolor = 8,
        collision_debug_draw = false,
        drawf = function(a)
                    rectfill(a.x,a.y,a.x+a.width-1,a.y+a.height-1,a.color)
                end
    }

    return wall
end

function pong:update_game_state()
    self:handle_game_input()

    for i=1,#balls do
        local b = balls[i]
        if (b.serving > 0) then
            self:update_serve(b)
        elseif (b.x > -b.radius) and (b.x < gm.screenwidth + b.radius) and
            (b.y < PLAYFIELD_BOTTOM+b.radius) and (b.y > -b.radius) then
            self:update_ball(b)
        else
            self:score_point(b, b.dx > 0 and 1 or 2)
        end
        if self.pending == b then
            self.pending = nil
            self:score_point(b, 2)
        end
    end

    if self.cfg.ai_enabled then self:run_ai(balls[1]) end
end

function pong:score_point(b,who)
    local c = self.cfg
    if c.scoring_enabled then
        if who == 1 then
            hud.p1_score += c.score_multiplier_com
        else
            hud.p2_score += 1
        end
        self:check_win()
    end
    self:begin_serve(b)
end

function pong:check_win()
    local c = self.cfg
    if (self.winner > 0) return
    if c.sudden_death then
        if (hud.p1_score > hud.p2_score) self.winner = 1
        if (hud.p2_score > hud.p1_score) self.winner = 2
    else
        if (hud.p1_score >= c.win_score[1]) self.winner = 1
        if (hud.p2_score >= c.win_score[2]) self.winner = 2
    end
end

function pong:begin_serve(b)
    b.serving = SERVE_DELAY
    b.hits = 0
    if (self.cfg.com_serves_every_point) b.dx = -abs(b.dx)
end

function pong:update_serve(b)
    local r = b.radius
    local miny,maxy = r, PLAYFIELD_BOTTOM - r + 1
    b.y += b.dy
    if (b.y < miny) then
        b.y = (miny*2) - b.y
        b.dy = -b.dy
    elseif (b.y > maxy) then
        b.y = (maxy*2) - b.y
        b.dy = -b.dy
    end

    b.serving -= 1
    if (b.serving <= 0) then
        local pool = self.cfg.ball_mode_pool
        b.mode = pool and pool[flr(rnd(#pool))+1] or self.cfg.ball_mode
        b.x = SERVE_X
        if (b.dx < 0) then
            b.dx = -BALL_SPEEDS[1]
        else
            b.dx = BALL_SPEEDS[1]
        end
    end
end

function pong:handle_game_input()
    local d = 0
    if (btn(⬇️)) d = 1
    if (btn(⬆️)) d = -1
    self:move_paddle(player2,d)
end

function pong:speed_tier(hits)
    if (self.cfg.speed_tier_pin > 0) then return self.cfg.speed_tier_pin end
    if (hits >= BALL_HITS_MAX) then return 3 end
    if (hits >= 4) then return 2 end
    return 1
end

function pong.contact_zone(cy, py)
    return mid(1, flr((cy - py) / BALL_ZONE_SIZE) + 1, 8)
end

function pong:update_ball(b)
    if b.mode == "homing" and b.dx > 0 then
        local t = player2.y + player2.height/2
        b.dy = mid(-BALL_VZONES[8], b.dy + mid(-0.02,(t-b.y)*0.01,0.02), BALL_VZONES[8])
    end
    local nx,ny = b.dx,b.dy
    local bx,by,r = b.x,b.y,b.radius
    local px,py = bx+nx, by+ny
    local ndx,ndy = nx,ny

    local lox,hix = min(bx,px)-r, max(bx,px)+r
    local loy,hiy = min(by,py)-r, max(by,py)+r

    local w = walls
    local pt,hitwall = nil,nil
    for i=1,#w do
        local wl = w[i]
        if wl.collsion and hix >= wl.x and lox <= wl.x+wl.width
            and hiy >= wl.y and loy <= wl.y+wl.height then
            pt = pong.ball_intercept(b, wl, nx, ny)
            if pt then
                wl.collsionpt = {x=pt.x,y=pt.y,d=pt.d}
                hitwall = wl
                break
            end
        end
    end

    if pt then
        if (pt.d == 'left' or pt.d == 'right') then
            px = pt.x
            ndx = -ndx
        elseif (pt.d == 'top' or pt.d == 'bottom') then
            py = pt.y
            ndy = -ndy
        end
    end

    if (hitwall == player1) or (hitwall == player2) then
        if (b.hits < BALL_HITS_MAX) then b.hits += 1 end
        local ti = self:speed_tier(b.hits)
        if (b.mode == "slow_fast") ti = ndx > 0 and 1 or 3
        local spd = BALL_SPEEDS[ti]
        if (ndx < 0) then ndx = -spd else ndx = spd end
        ndy = BALL_VZONES[pong.contact_zone(pt.y, hitwall.y)]
        if (self.cfg.scoring_model == "intercept" and hitwall == player2) self.pending = b
        player1.collsionpt = nil
        player2.collsionpt = nil
    end

    b.x = px
    b.y = py
    b.dx = ndx
    b.dy = ndy

    if crt.phos == 1 then
        b.tc += 1
        if b.tc >= 3 then
            b.tc = 0
            b.t3x,b.t3y = b.t2x,b.t2y
            b.t2x,b.t2y = b.t1x,b.t1y
            b.t1x,b.t1y = px,py
        end
    end
end

function pong.ball_intercept(ball, paddle, nx, ny)
    pt = nil
    if (nx < 0) then
        pt = pong.intercept(ball.x, ball.y, ball.x + nx, ball.y + ny, 
                        (paddle.x+paddle.width)  + ball.radius, 
                        paddle.y - ball.radius, 
                        (paddle.x+paddle.width)  + ball.radius, 
                        (paddle.y+paddle.height) + ball.radius, 
                        "right")
    elseif (nx > 0) then
        pt = pong.intercept(ball.x, ball.y, ball.x + nx, ball.y + ny, 
                        paddle.x - ball.radius, 
                        paddle.y - ball.radius, 
                        paddle.x - ball.radius, 
                        (paddle.y+paddle.height) + ball.radius,
                        "left")
    end

    if (pt == nil) then
        if (ny < 0) then
            pt = pong.intercept(ball.x, ball.y, ball.x + nx, ball.y + ny, 
                            (paddle.x+paddle.width)   - ball.radius, 
                            (paddle.y+paddle.height) + ball.radius, 
                            paddle.x  + ball.radius, 
                            (paddle.y+paddle.height) + ball.radius,
                            "bottom")
        elseif (ny > 0) then
            pt = pong.intercept(ball.x, ball.y, ball.x + nx, ball.y + ny, 
                            paddle.x   - ball.radius, 
                            paddle.y    - ball.radius, 
                            (paddle.x+paddle.width)  + ball.radius, 
                            paddle.y    - ball.radius,
                            "top")
        end
    end
    return pt
end

function pong.intercept(x1, y1, x2, y2, x3, y3, x4, y4, d)
    local denom = ((x1-x2) * (y3 -y4)) - ((y1-y2) * (x3-x4))
    if (denom != 0) then
        local ua = (((x1-x3) * (y3-y4)) - ((y1-y3) * (x3-x4))) / denom
        if ((ua >= 0) and (ua <= 1)) then
            local ub = (((x1-x3) * (y1-y2)) - ((y1-y3) * (x1-x2))) / denom
            if ((ub >= 0) and (ub <= 1)) then
                local x = x1 + (ua * (x2-x1))
                local y = y1 + (ua * (y2-y1))
                return { x = x, y = y, d = d}
            end
        end
    end
    return nil
end

function pong:run_ai(b)
    if (b.dx >= 0) or (b.serving > 0) then
        self:move_paddle(player1,0)
        player1.prediction = nil
        return
    end

    self:predict(b)

    local pr = player1.prediction
    local d = 0
    if pr then
        local c = player1.y + player1.height/2
        if (pr.y < c - 2) then
            d = -1
        elseif (pr.y > c + 2) then
            d = 1
        end
    end
    self:move_paddle(player1,d)
end

function pong:predict(b)
    local lvl = AI_LEVELS[self:ai_level()]
    local pr = player1.prediction
    if pr and ((pr.dx * b.dx) > 0) and ((pr.dy * b.dy) > 0)
        and (pr.since < lvl[1]) then
        pr.since += 1
        return
    end

    local face = player1.x + player1.width + b.radius
    local y = b.y + b.dy * ((face - b.x) / b.dx)

    local t = b.radius
    local bot = PLAYFIELD_BOTTOM - b.radius + 1
    while (y < t) or (y > bot) do
        if (y < t) then
            y = t + (t - y)
        else
            y = bot + (bot - y)
        end
    end

    local closeness = (b.x - face) / gm.screenwidth
    local err = lvl[2] * closeness
    player1.prediction = {
        x=face,
        y=y + (rnd(err*2) - err),
        since=0,
        dx=b.dx,
        dy=b.dy
    }
end

function pong.draw_board()
    for x=1,#walls do
        if (walls[x].visible) then walls[x].drawf(walls[x]) end
    end

    net.drawnet()

    draw_score()
end

function pong.draw_balls()
    for i=1,#balls do
        local b = balls[i]
        if (b.serving <= 0) then
            local r = b.radius
            local bx0,by0 = flr(b.x),flr(b.y)
            if crt.phos == 1 and
                abs(flr(b.t2x)-bx0) + abs(flr(b.t2y)-by0) >= 2 then
                if crt.tlen > 1 then
                    local x2,y2 = flr(b.t3x)-r,flr(b.t3y)-r
                    rectfill(x2,y2,x2+r+r-1,y2+r+r-1,C_TRAIL2)
                end
                local x1,y1 = flr(b.t2x)-r,flr(b.t2y)-r
                rectfill(x1,y1,x1+r+r-1,y1+r+r-1,C_TRAIL1)
            end
            local bx,by = flr(b.x)-r,flr(b.y)-r
            rectfill(bx,by,bx+r+r-1,by+r+r-1,b.color)
        end
    end
end
-->8
dialogue = {}

function dialogue:new(t,c,debug)
	local d = {
		state=nil,
        complete=false,
		sections={},
		index=1,
		title=t,
		color=c,
        continuesequence=true
	}

    if debug then
        for x=1,flr(rnd(3))+3 do 
            local section = dialogue.create_section()
            add(d.sections,section)
            for y=1,flr(rnd(4))+5 do 
                local phrase = dialogue.create_phrase('phrase '..y,7,3)
                add(section.phrases,phrase)
            end
        end
    end

	setmetatable(d, {
		__index = function(t, k)
			if k == "section" then
				return t.sections[t.index]
			elseif k == "phrase" then
				return t.section.phrases[t.section.index]
			else
				return dialogue[k]
			end
		end
	})
	return d
end

function dialogue.create_section()
    local s = {
		phrases = {},
		index=1
    }
    return s
end

function dialogue.create_phrase(t,c,d)
    local p = {
        text=t,
        color=c,
        duration=d
    }
    return p
end

function dialogue:load_next()
	if self.complete then return end
	add_timer(self.phrase.duration, function() gm:event(game_manager.timerevents.timer_fired) end)
end

function dialogue:event(e)
	if e == game_manager.timerevents.timer_fired then
		self.section.index += 1
		if self.section.index > #self.section.phrases then
			self.index += 1
			if self.index > #self.sections then
				self.complete=true
				gm:event(level.events.sequence_complete)
			else
				gm:event(level.events.section_complete)
			end
		else
			gm:event(level.events.phrase_complete)
			self:load_next()
		end
	end
end

textbox = {}
textbox.__index = textbox
textbox.states = {closed=1,opening=2,open=3,closing=4}
function textbox:new(xpos,ypos,w,h,c)
	local tb = {
		visible=false,
		textvisible=false,
		state=textbox.states.closed,
		callback=nil,

		rect = {
			x0=xpos,
			y0=ypos,
			x1=xpos,
			y1=ypos,
			color=c
		},	
		width=w,
		height=h,

		sectiontitle='no title',
		sectionphrase='no phrase',
		
		filled=true
	}
	setmetatable(tb,textbox)
	return tb
end

blinkert=0
blinkerc=16
function textbox:draw()
	if self.visible then
		local rect = self.rect
		if self.filled then
			rectfill(rect.x0, rect.y0, rect.x1, rect.y1, rect.color)
		else
			rect(rect.x0, rect.y0, rect.x1, rect.y1, rect.color)
		end

		if self.textvisible then
            blinkert+=1
            if blinkert > 15 then
                blinkert = 0
                if blinkerc == 16 then blinkerc = 32 else blinkerc = 16 end
            end
			print(chr(62)..' '..self.sectionphrase..' '..chr(blinkerc),rect.x0+2,rect.y0+2,C_SCORE)
		end
	end
end

function textbox:update()
	if self.state == textbox.states.opening then
		local done=0
		if self.rect.x1 < self.rect.x0 + self.width then
			self.rect.x1 += 15
		else done+=1
		end
		if self.rect.y1 < self.rect.y0 + self.height then
			self.rect.y1 += 15
		else done+=1
		end

		if done == 2 then
			self.state = textbox.states.open
			self:callback(level.events.tb_open)
		end
	end

	if self.state == textbox.states.closing then
		local done=0
		if self.rect.x1 > self.rect.x0 then
			self.rect.x1 -= 15
		else done+=1
		end
		if self.rect.y1 > self.rect.y0 then
			self.rect.y1 -= 15
		else done+=1
		end

		if done == 2 then
			self.state = textbox.states.closed
			self.visible=false
			self:callback(level.events.tb_closed)
		end
	end
end

function textbox:open(cb)
	self.visible=true
	self.textvisible=true
	self.state=textbox.states.opening
	self.callback=cb
end

function textbox:close(cb)
	self.textvisible=false
	self.state=textbox.states.closing
	self.callback=cb
end
-->8
-->8
dialogues={}

function dialogues.printdialogue(d,i)
    printh('--dialogues['..i..']--')
    for x=1,#d.sections do 
        printh(' section['..x..']')
        local section = d.sections[x]
        for y=1,#section.phrases do 
            printh(' phrase['..y..']='..section.phrases[y].text)
        end
    end
end

dialogue.states={observing=0,crusing=1,playing=2,finish=3}
function dialogue:init()
    self:changestate(dialogue.states.observing)
end
function dialogue:changestate(s)
    local states = {
        [dialogue.states.observing] = function()
            gm.level.pong.cfg.ai_enabled=false;
            printh('observing')
        end,
        [dialogue.states.crusing] = function()
            gm.level.textbox:open(function() gm:event(level.events.tb_open) end)
            printh('crusing')
        end,
        [dialogue.states.playing] = function()
            add_timer(100,function () gm.level.textbox:open(function() gm:event(level.events.tb_open) end) end)
            self.continuesequence=false
            gm.level.pong.cfg.ai_enabled=true;
            hud.p1_score=0
            hud.p2_score=0
            printh('playing')
        end,
        [dialogue.states.finish] = function()
            add_timer(100,function () gm.level.textbox:open(function() gm:event(level.events.tb_open) end) end)
            self.continuesequence=false
            gm:change_state(game_manager.states.gameover)
            player1.visible = false
            player2.visible = false
            printh('finish')
        end
    }

    local state = states[s]
    if state then
        state()
        self.state=s
    end
end

function dialogue:update()
    local states = {
        [dialogue.states.observing] = function()
            if hud.p2_score > 1 then self:changestate(dialogue.states.crusing) end
        end,
        [dialogue.states.crusing] = function()
            if self.index > 4 then self:changestate(dialogue.states.playing) end
        end,
        [dialogue.states.playing] = function()
            if hud.p1_score > 5 then self:changestate(dialogue.states.finish) end
            if hud.p2_score > 5 then 
                self.index+=1
                self:changestate(dialogue.states.finish)
            end
        end,
        [dialogue.states.finish] = function()
        end
    }

    local state = states[self.state]
    if state then
        state()
    end
end

local dialogue_denial = dialogue:new('denial',0,false)
dialogues[1]=dialogue_denial
local section = dialogue.create_section()
add(dialogue_denial.sections,section)
    add(section.phrases,dialogue.create_phrase('hello!?',7,360))
local section2 = dialogue.create_section()
add(dialogue_denial.sections,section2)
    add(section2.phrases,dialogue.create_phrase('where is the second player?',7,360))
    --add(section2.phrases,dialogue.create_phrase('are they in the bathroom?',7,480))
    --add(section2.phrases,dialogue.create_phrase('maybe you should wait for them',7,100))
    --add(section2.phrases,dialogue.create_phrase('its their quarter too',7,200))
local section3 = dialogue.create_section()
add(dialogue_denial.sections,section3)
    --add(section3.phrases,dialogue.create_phrase('you know pong is a 2-player game right?',7,360))
    add(section3.phrases,dialogue.create_phrase('dont have any friends?',7,240))
    --add(section3.phrases,dialogue.create_phrase('sorry what i mean is',7,120))
    --add(section3.phrases,dialogue.create_phrase('do you want some help?',7,200))
local section4 = dialogue.create_section()
add(dialogue_denial.sections,section4)
    -- add(section4.phrases,dialogue.create_phrase('never got to play before',7,360))
    -- add(section4.phrases,dialogue.create_phrase('i bet i am really good',7,180))
    add(section4.phrases,dialogue.create_phrase('brb, gonna jump in real quick',7,360))
local section5 = dialogue.create_section()
    add(dialogue_denial.sections,section5)
    add(section5.phrases,dialogue.create_phrase('there we go',7,240))
    add(section5.phrases,dialogue.create_phrase('alright, this feels good',7,360))
    add(section5.phrases,dialogue.create_phrase('a little trickier than I thought',7,180))
    add(section5.phrases,dialogue.create_phrase('i will shut up now so we can play',7,180))
local section6 = dialogue.create_section()
add(dialogue_denial.sections,section6)
    add(section6.phrases,dialogue.create_phrase('see, just as i said',7,240))
    add(section6.phrases,dialogue.create_phrase('i am good at this game',7,240))
local section7 = dialogue.create_section()
add(dialogue_denial.sections,section7)
    add(section7.phrases,dialogue.create_phrase('hmm, i lost',7,240))
    add(section7.phrases,dialogue.create_phrase('thats not possible',7,240))

dialogues[2]=dialogue:new('anger',8,true)
dialogues[3]=dialogue:new('bargining',9,true)
dialogues[4]=dialogue:new('depression',1,true)
dialogues[5]=dialogue:new('acceptance',3,true)

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
