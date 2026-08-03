pico-8 cartridge // http://www.pico-8.com
version 43
__lua__

   
PLAYFIELD_BOTTOM = 95

BALL_SPEEDS = {0.341, 0.683, 1.024}
BALL_HITS_MAX = 12
BALL_VZONES = {-1.171,-0.780,-0.390,0,0,0.390,0.780,1.171}
ball_scale = 1.4

function bspd(t)
    return BALL_SPEEDS[t] * ball_scale
end

function bvz(z)
    return BALL_VZONES[z] * ball_scale
end

BALL_ZONE_SIZE = 0.75
SERVE_DELAY = 102
SERVE_X = 66
RESOLVE_DELAY = 120
SND_HIT = 0
SND_BOUNCE = 1
SND_SCORE = 2
CD_ID = "metapong_1972_1"
ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789"
NAME_ADDR = 0x5e04

function cd_init()
    cartdata(CD_ID)
end

function cd_checkpoint()
    return mid(0, flr(dget(0)), 5)
end

function cd_save_checkpoint(n)
    dset(0, mid(0, flr(n), 5))
end

function cd_name()
    local a,b,c = peek(NAME_ADDR, 3)
    if (a+b+c == 0) return nil
    local m = #ALPHABET
    if (a > m or b > m or c > m) return nil
    return sub(ALPHABET,a,a)..sub(ALPHABET,b,b)..sub(ALPHABET,c,c)
end

function cd_save_name(a,b,c)
    poke(NAME_ADDR, a, b, c)
end

NAME_LEN = 3
BTNP_DELAY = 16
BTNP_RATE = 5

nament = {active=false, idx={1,1,1}, cur=1}

function nament:start()
    self.active = true
    self.idx = {1,1,1}
    self.cur = 1
end

function nament:update()
    local n = #ALPHABET
    if (btnp(2)) self.idx[self.cur] = (self.idx[self.cur] % n) + 1
    if (btnp(3)) self.idx[self.cur] = ((self.idx[self.cur] + n - 2) % n) + 1
    if (btnp(0)) self.cur = max(1, self.cur - 1)
    if (btnp(1)) self.cur = min(NAME_LEN, self.cur + 1)
    if btnp(5) then
        cd_save_name(self.idx[1], self.idx[2], self.idx[3])
        self.active = false
        tb:clear()
        cli_run({
            {"congrats "..cd_name(),false,45},
            {"> run attract",false,30}
        }, function() gm:to_attract() end)
    end
end

function nament:draw()
    local x = 64 - (NAME_LEN*8)/2
    for k=1,NAME_LEN do
        local c = sub(ALPHABET, self.idx[k], self.idx[k])
        print("\^w\^t"..c, x, 40, C_SCORE)
        if k == self.cur then
            rectfill(x, 54, x+6, 54, C_SCORE)
        end
        x += 8
    end
end

function cd_reset()
    memset(0x5e00, 0, 0x100)
end

C_BG = 0
C_PADDLE = 1
C_BALL = 2
C_SCORE = 3
C_TRAIL1 = 4
C_TRAIL2 = 5
C_CLI = 6
C_CLIBG = 7

DEBUG_ACT = nil
DEBUG_AI = true

SCORE_Y = 8
SCORE_H = 12
BADGE_Y = 2
NICK_Y = 1
NICK_X1 = 8
NICK_X2 = 108
COM_NAME = "com"

ACT_PALETTES = {
 {0,7,7,7,    6,5,    6},
 {8,9,7,10,   15,9,   9},
 {3,10,7,11,  6,11,   1},
 {1,5,7,12,   12,13,  13},
 {5,6,7,9,    6,5,    4},
 {0,7,7,7,    6,5,    6}
}

CLI_PALETTES = {
 {0,7,6},
 {8,10,9},
 {3,11,1},
 {1,12,13},
 {5,9,4},
 {2,11,3}
}
PAL_ATTRACT = 6

ACT_CONFIGS = {
 {palette=1, phosphor_mode=true},
 {palette=2, phosphor_mode=true, nickname="dum"},
 {palette=3, phosphor_mode=true, nickname="skr"},
 {palette=4, phosphor_mode=true, nickname="whr"},
 {palette=5, phosphor_mode=true, nickname="plr"},
 {palette=1, phosphor_mode=false, ball_count=40, speed_tier_pin=3, ai_enabled=true}
}



SCAN_PATTERN = {0x80,0x40,0x20,0x10,0x08,0x04,0x02,0x01}

CRAWL_RATE = 12
crt = {phase=0, st=0, ty=999, tw=240, phos=true, cpu=false}

function set_palette(n)
    local i = mid(1,DEBUG_ACT or n,#ACT_PALETTES)
    local a,c = ACT_PALETTES[i], CLI_PALETTES[i]
    poke(0x5f10, a[1],a[2],a[3],a[4],a[5],a[6], c[2],c[1],8,9,10,11,12,13,14,15)
    poke(0x5f60, a[1],a[2],a[3],a[7],a[5],a[6], c[3],c[1],8,9,10,11,12,13,14,15)
end

function set_scanlines()
    local p = SCAN_PATTERN[(crt.phase % 8) + 1]
    memset(0x5f70, 0, 12)
    for y=NICK_Y,SCORE_Y+SCORE_H-1 do
        local i = 0x5f70 + flr(y/8)
        poke(i, peek(i) | (p & (1 << (y%8))))
    end
    memset(0x5f7c, p, 4)
end

function init_crt()
    poke(0x5f5f, 0x10)
    set_scanlines()
end

RESET_LABELS = {"reset data","reset: sure?","reset: done"}
reset_state = 0

ACCELS = {0.1,0.15,0.2,0.25,0.3,0.4,0.5,0.6,0.8,1}
MAXSPDS = {1.5,2,2.5,3,3.5,4,4.5,5,6,7}
accel_i = 5
maxspd_i = 4
BALL_CAL = 1.4

function pd_k()
    return ball_scale / BALL_CAL
end

function pd_max()
    return MAXSPDS[maxspd_i] * pd_k()
end

function pd_accel()
    return ACCELS[accel_i] * pd_k()
end

function r2(x)
    return flr(x*100)/100
end

function menu_step(i,t,b)
    if (b&1 > 0) i -= 1
    if (b&2 > 0) i += 1
    return mid(1,i,#t)
end

function init_menu()
    menuitem(1,"act "..(DEBUG_ACT or "auto"),function()
        DEBUG_ACT = (DEBUG_ACT or 0) + 1
        if (DEBUG_ACT > #ACT_CONFIGS) DEBUG_ACT = nil
        p:configure(ACT_CONFIGS[mid(1,DEBUG_ACT or gm.level_index,#ACT_CONFIGS)])
        p:start_match()
        init_menu()
        return true
    end)
    menuitem(2,RESET_LABELS[reset_state+1],function()
        if reset_state == 1 then
            cd_reset()
            reset_state = 2
        elseif reset_state == 2 then
            reset_state = 0
        else
            reset_state = 1
        end
        init_menu()
        return true
    end)
    menuitem(3,"cpu "..(crt.cpu and "on" or "off"),function()
        crt.cpu = not crt.cpu
        init_menu()
        return true
    end)
    menuitem(4,"<accel "..ACCELS[accel_i]..">",function(b)
        accel_i = menu_step(accel_i,ACCELS,b)
        init_menu()
        return true
    end)
    menuitem(5,"<max spd "..MAXSPDS[maxspd_i]..">",function(b)
        maxspd_i = menu_step(maxspd_i,MAXSPDS,b)
        init_menu()
        return true
    end)
end

TEAR_H = 6

function scan_row(y)
    return (y >= NICK_Y and y < SCORE_Y+SCORE_H) or y > PLAYFIELD_BOTTOM
end

function update_crt()
    crt.st += 1
    if crt.st >= CRAWL_RATE then
        crt.st = 0
        crt.phase += 1
        set_scanlines()
    end
    if crt.ty > 127 then
        crt.tw -= 1
        if (crt.tw <= 0) crt.ty = 127
    else
        crt.ty -= 4
        if crt.ty <= -TEAR_H then
            crt.ty = 999
            crt.tw = 420 + rnd(600)
        end
    end
end

function apply_tear()
    if (crt.ty > 127) return
    for i=0,TEAR_H-1 do
        local y = crt.ty + i
        if y >= 0 and y < 128 and scan_row(y) then
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
game_manager.states = {attract=0,level=1}
function game_manager:new()
	local gm = {
		state = game_manager.states.attract,
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

function game_manager:start_level()
	if self.state == game_manager.states.attract then
		self:change_state(game_manager.states.level)
		self.level:load()
	end
end

function game_manager:update()
    update_timers()
	update_input()
    tb:update()
    cli_update()

    if nament.active then
        nament:update()
        return
    end

	if self.state == game_manager.states.level then
		if (cli_busy()) return
		self.level:update()
        self:check_result()
    else
        p:update_game_state()
	end
end

function game_manager:check_result()
    if (self.resolving) return
    local w = self.level.pong.winner
    if (w == 0) return
    self.resolving = true
    player1.visible = false
    player2.visible = false
    local st = self.level.stage
    if st:resolve(w) then
        st.on_complete = function() gm:resolve(w) end
    else
        add_timer(RESOLVE_DELAY, function() gm:resolve(w) end)
    end
end

function game_manager:resolve(w)
    self.resolving = false
    p.winner = 0
    if w == 2 then
        cd_save_checkpoint(self.level_index)
        self.level_index += 1
        if self.level_index > #self.levels then
            self.level_index = 1
            nament:start()
            return
        end
        self.level:load()
    else
        tb:clear()
        cli_run(CLI_ATTRACT, function() gm:to_attract() end)
    end
end

function game_manager:to_attract()
    self:change_state(game_manager.states.attract)
    p:configure(ACT_CONFIGS[1])
    set_palette(PAL_ATTRACT)
    crt.phos = ACT_CONFIGS[1].phosphor_mode
    timers = {}
    self.input_lock = true
    p:init_balls(p.cfg.ball_count)
    p:set_attract(true)
    cli_run(CLI_PROMPT)
end

function game_manager:draw()
    if (not self.booting) pong.draw_board()

	local states = {
		[game_manager.states.attract] = function()
            if not self.booting then
                pong.draw_balls()
                local n = cd_name()
                if n then
                    local t = "highscore"
                    local tx = 64 - (#t*2)
                    rectfill(tx-2,BADGE_Y-1,tx+(#t*4),BADGE_Y+13,C_BG)
                    print(t,tx,BADGE_Y,C_SCORE)
                    print(n,64-(#n*2),BADGE_Y+7,C_SCORE)
                end
            end
            tb:draw()
        end,
        [game_manager.states.level] = function()
            self.level:draw()
            if (nament.active) nament:draw()
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
function level:new(d,tb,p)
	local l = {
		stage=d,
		textbox=tb,
		pong=p
	}
	setmetatable(l,level)
	return l
end

function level:load()
    self.stage:reset()
    self.pong:configure(ACT_CONFIGS[mid(1,DEBUG_ACT or gm.level_index,#ACT_CONFIGS)])
    self.pong:start_match()

    self.pong:set_attract(false)
end

function level:input()
end

function level:update()
    self.stage:update(self.textbox)
    if (not gm.resolving) self.pong:update_game_state()
end

function level:draw()
    pong.draw_balls()
	tb:draw()
end

function _init()
	gm = game_manager:new()
    gm.screenwidth = 128
    gm.screenheight = 128
    cd_init()
    init_crt()
    palt(0,false)
    memset(0x0000,0,0x2000)
    poke(0x5f5c, BTNP_DELAY)
    poke(0x5f5d, BTNP_RATE)
    if (DEBUG_KEYS) poke(0x5f2d,1)
	tb = term:new(0,96)
    p = pong:new()
    p:reset_game()
    init_menu()
	gm:add_level(level:new(stages[1],tb,p))
	gm:add_level(level:new(stages[2],tb,p))
	gm:add_level(level:new(stages[3],tb,p))
	gm:add_level(level:new(stages[4],tb,p))
	gm:add_level(level:new(stages[5],tb,p))

    local cp = cd_checkpoint()
    if (cp >= 5) cp = 0
    gm.level_index = mid(1, cp+1, #gm.levels)

    gm.booting = true
    cli_run(CLI_BOOT, function()
        gm.booting = false
        cli_run(CLI_PROMPT)
    end)
end

function _update60()
	gm:update()
    update_crt()
    update_debug_keys()
end

DEBUG_KEYS = true

function update_debug_keys()
    if (not DEBUG_KEYS) return
    local k = stat(31)
    if (k == "") return
    if gm.state == game_manager.states.level and not nament.active then
        if (k == "c") p.winner = 2
        if (k == "v") p.winner = 1
    end
    if (k == "[") ball_scale = max(0.5, ball_scale - 0.1)
    if (k == "]") ball_scale = min(3, ball_scale + 0.1)
end

function update_input()
    if (gm.state != game_manager.states.attract) return
    if (gm.booting or (cli_busy() and cli.s != CLI_PROMPT)) return
    if gm.input_lock then
        if (btn() == 0) gm.input_lock = false
        return
    end
    for i=0,5 do
        if btnp(i) then
            cli_run(CLI_START, function() gm:start_level() end)
            return
        end
    end
end

function _draw()
    if crt.phos then
        pal(1,C_TRAIL1) pal(2,C_TRAIL1) pal(3,C_TRAIL1) pal(C_CLI,C_TRAIL1)
        pal(C_TRAIL1,C_TRAIL2) pal(C_TRAIL2,C_BG)
        sspr(0,0,128,128,0,0)
        pal(1,1) pal(2,2) pal(3,3) pal(C_CLI,C_CLI)
        pal(C_TRAIL1,C_TRAIL1) pal(C_TRAIL2,C_TRAIL2)
    else
        cls(C_BG)
    end

    gm:draw()
    apply_tear()

    if (crt.phos) memcpy(0x0000,0x6000,0x2000)
    if crt.cpu then
        local s = flr(stat(1)*100).."% b"..ball_scale.." p"..r2(pd_max()).."/"..r2(pd_accel())
        rectfill(0,0,#s*4,6,C_BG)
        print(s,1,1,C_SCORE)
    end
end

function draw_score()
    print("\^w\^t" .. hud.p1_score,hud.p1_x-(#tostr(hud.p1_score)*8),hud.p1_y,hud.p1_color)
    print("\^w\^t" .. hud.p2_score,hud.p2_x,hud.p2_y,hud.p2_color)

    if hud.nick and gm.state == game_manager.states.level then
        print(COM_NAME,NICK_X1,NICK_Y,hud.p1_color)
        print(hud.nick,NICK_X2,NICK_Y,hud.p2_color)
    end
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
 paddle_accel={0.08,0.3},
 paddle_max_speed={2.5,3},
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
 phosphor_mode=true,
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
    if (DEBUG_AI) c.ai_enabled = true
    self.cfg = c
    tb.rate = c.cli_rate or TB_REVEAL
    self.com_handicap = c.initial_score_com
    self.winner = 0
end

function pong:reset_game()
    self:start_match()
    self:set_attract(true)
    gm:change_state(game_manager.states.attract)
    set_palette(PAL_ATTRACT)
end

function pong:set_attract(on)
    self.attract = on
    for w in all(sidewalls) do
        w.collsion = on
    end
    player1.collsion = not on
    player2.collsion = not on
    player1.visible = not on
    player2.visible = not on
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

    sidewalls = {
        self:create_wall(-3,-3,3,PLAYFIELD_BOTTOM+7),
        self:create_wall(gm.screenwidth,-3,3,PLAYFIELD_BOTTOM+7)
    }
    for w in all(sidewalls) do
        w.visible = false
        add(walls, w)
    end

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
        nick = self.cfg.nickname and (cd_name() or self.cfg.nickname)
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
        local s,k = p.side,pd_k()
        local ac = (s == 2 and ACCELS[accel_i] or self.cfg.paddle_accel[s]) * k
        local mx = (s == 2 and MAXSPDS[maxspd_i] or self.cfg.paddle_max_speed[s]) * k
        p.v = min(p.v + ac, mx)
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
        dx = bspd(1) * coin_flip(),
        dy = bvz(8) * coin_flip()
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
    if (not self.attract) self:handle_game_input()

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
    self:snd(SND_SCORE)
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
            b.dx = -bspd(1)
        else
            b.dx = bspd(1)
        end
    end
end

function pong:handle_game_input()
    local d = 0
    if (btn(⬇️)) d = 1
    if (btn(⬆️)) d = -1
    self:move_paddle(player2,d)
end

function snd_type()
end

function pong:snd(n)
    if (not self.attract) sfx(n)
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
        local m = bvz(8)
        b.dy = mid(-m, b.dy + mid(-0.02,(t-b.y)*0.01,0.02), m)
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
        if (hitwall != player1 and hitwall != player2) self:snd(SND_BOUNCE)
    end

    if (hitwall == player1) or (hitwall == player2) then
        if (pt.d != "left" and pt.d != "right") then
            px = pt.x
            ndx = -nx
        end
        if (b.hits < BALL_HITS_MAX) then b.hits += 1 end
        local ti = self:speed_tier(b.hits)
        if (b.mode == "slow_fast") ti = ndx > 0 and 1 or 3
        local spd = bspd(ti)
        if (ndx < 0) then ndx = -spd else ndx = spd end
        ndy = bvz(pong.contact_zone(pt.y, hitwall.y))
        if (self.cfg.scoring_model == "intercept" and hitwall == player2) self.pending = b
        self:snd(SND_HIT)
        player1.collsionpt = nil
        player2.collsionpt = nil
    end

    b.x = px
    b.y = py
    b.dx = ndx
    b.dy = ndy
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
                            paddle.x - ball.radius, 
                            (paddle.y+paddle.height) + ball.radius, 
                            (paddle.x+paddle.width) + ball.radius, 
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
            local bx,by = flr(b.x)-r,flr(b.y)-r
            rectfill(bx,by,bx+r+r-1,by+r+r-1,b.color)
        end
    end
end
-->8
TB_ROWS = 5
TB_COLS = 31
TB_REVEAL = 2
TB_LH = 6
V_COM = 1
V_CLI = 2
V_COL = {C_SCORE,C_CLI}

term = {}
term.__index = term
function term:new(xpos,ypos)
	local tb = {
		x=xpos,
		y=ypos,
		rows={},
		vo={},
		queue={},
		src="",
		cur="",
		v=V_COM,
		i=0,
		t=0,
		rate=TB_REVEAL,
		blink=0,
		pending=nil
	}
	setmetatable(tb,term)
	return tb
end

function term:wrap(s)
	local out,line = {},""
	for w in all(split(s," ",false)) do
		local t = line == "" and w or line.." "..w
		if #t <= TB_COLS then
			line = t
		else
			if (line != "") add(out,line)
			line = w
		end
	end
	if (line != "") add(out,line)
	return out
end

function term:say(s,v,ins)
	if (self.cur != "") self:push(self.cur,self.v)
	v = v or V_COM
	if (#self.rows > 0 and v != self.v) self:push("",self.v)
	self.v = v
	self.queue = self:wrap(s)
	self:next_row()
	if ins then
		self.i = #self.src
		self.cur = self.src
		while #self.queue > 0 do
			self:push(self.cur,self.v)
			self:next_row()
			self.i = #self.src
			self.cur = self.src
		end
	end
end

function term:clear()
	self.rows = {}
	self.vo = {}
	self.queue = {}
	self.src = ""
	self.cur = ""
	self.i = 0
	self.t = 0
end

function term:next_row()
	self.src = deli(self.queue,1) or ""
	self.cur = ""
	self.i = 0
	self.t = 0
end

function term:push(row,v)
	add(self.rows,row)
	add(self.vo,v)
	while #self.rows >= TB_ROWS do
		deli(self.rows,1)
		deli(self.vo,1)
	end
end

function term:update()
	self.blink = (self.blink + 1) % 30

	if self.i < #self.src then
		self.t += 1
		if self.t >= self.rate then
			self.t = 0
			self.i += 1
			self.cur = sub(self.src,1,self.i)
			snd_type()
		end
	elseif #self.queue > 0 then
		self:push(self.cur,self.v)
		self:next_row()
	end

	if self.pending then
		local c = self.pending
		self.pending = nil
		c()
	end
end

function term:draw()
	rectfill(self.x,self.y,127,127,C_CLIBG)
	local y = self.y + 1
	for i=1,#self.rows do
		print(self.rows[i], self.x+2, y, V_COL[self.vo[i]])
		y += TB_LH
	end
	local c = self.cur
	if (self.blink < 15) c = c..chr(16)
	print(c, self.x+2, y, V_COL[self.v])
end

function term:done()
	return self.i >= #self.src and #self.queue == 0
end

CLI_BOOT = {
	{"pico-8 cli",true},
	{"(c) lexaloffle games llp",true,30},
	{"> load pong.p8",false,20},
	{"> run",false,20}
}
CLI_ATTRACT = {{"> run attract",false,30}}
CLI_PROMPT = {{"> press any button"}}
CLI_START = {{"> run game",false,15}}

cli = {s=nil,i=0,t=0,cb=nil}

function cli_run(s,cb)
	cli.s = s
	cli.i = 0
	cli.t = 0
	cli.cb = cb
end

function cli_busy()
	return cli.s != nil
end

function cli_update()
	if (not cli.s) return
	if (not tb:done()) return
	if cli.t > 0 then
		cli.t -= 1
		return
	end
	if cli.i >= #cli.s then
		local c = cli.cb
		cli.s = nil
		cli.cb = nil
		if (c) c()
		return
	end
	cli.i += 1
	local e = cli.s[cli.i]
	tb:say(e[1],V_CLI,e[2])
	cli.t = e[3] or 0
end

-->8
-->8
T_SHORT = 45
T_MED = 90
T_LONG = 180

stage = {}
stage.__index = stage

function stage:new(t)
	local st = {
		title=t,
		sections={},
		index=1,
		li=1,
		said=false,
		t=0,
		complete=false,
		machine=nil,
		on_complete=nil,
		win_section=nil,
		lose_section=nil
	}
	setmetatable(st,stage)
	return st
end

function stage:section(lines)
	local sec = {lines=lines}
	add(self.sections,sec)
	self.flow_end = #self.sections
	return sec
end

function stage:branch(lines)
	add(self.sections,{lines=lines})
	return #self.sections
end

function line(text,dur)
	return {text=text,dur=dur or T_MED}
end

function stage:cur()
	local sec = self.sections[self.index]
	return sec and sec.lines[self.li]
end

function stage:goto_section(i)
	if (not self.sections[i]) return
	self.index = i
	self.li = 1
	self.said = false
	self.t = 0
	self.complete = false
end

function stage:advance()
	self.said = false
	self.t = 0
	local sec = self.sections[self.index]
	self.li += 1
	if self.li > #sec.lines then
		if self.stop_at_end then
			self.li = #sec.lines
			self:finish()
			return
		end
		self.li = 1
		self.index += 1
		if self.index > self.flow_end then
			self.index = self.flow_end
			self.li = #sec.lines
			self:finish()
		end
	end
end

function stage:finish()
	if (self.complete) return
	self.complete = true
	local c = self.on_complete
	if c then
		self.on_complete = nil
		c()
	end
end

function stage:reset()
	self.index = 1
	self.li = 1
	self.said = false
	self.t = 0
	self.complete = false
	self.stop_at_end = false
	self.on_complete = nil
	if (self.init) self:init()
end

function stage:resolve(w)
	local i = w == 2 and self.win_section or self.lose_section
	if (not i) return false
	self:goto_section(i)
	self.stop_at_end = true
	return true
end

function stage:update(tb)
	if (self.machine) self:machine()
	if (self.complete) return

	local ln = self:cur()
	if (not ln) return

	if not self.said then
		tb:say(ln.text)
		self.said = true
		self.t = 0
		return
	end

	if (not tb:done()) return

	self.t += 1
	if (self.t >= ln.dur) self:advance()
end

-->8
stages = {}

local denial = stage:new("denial")
stages[1] = denial

denial:section({
	line("hello!?",T_LONG)
})
denial:section({
	line("where is the second player?",T_LONG),
	line("are they in the bathroom?",T_LONG),
	line("maybe you should wait for them",T_SHORT),
	line("its their quarter too",T_MED)
})
denial:section({
	line("you know pong is a 2-player game right?",T_LONG),
	line("dont have any friends?",T_MED),
	line("sorry what i mean is",T_SHORT),
	line("do you want some help?",T_MED)
})
denial:section({
	line("never got to play before",T_LONG),
	line("i bet i am really good",T_MED),
	line("brb, gonna jump in real quick",T_LONG)
})
denial:section({
	line("there we go",T_MED),
	line("alright, this feels good",T_LONG),
	line("a little trickier than I thought",T_MED),
	line("i will shut up now so we can play",T_MED)
})
denial.lose_section = denial:branch({
	line("see, just as i said",T_MED),
	line("i am good at this game",T_MED)
})
denial.win_section = denial:branch({
	line("hmm, i lost",T_MED),
	line("thats not possible",T_MED)
})

function denial:init()
	self.armed = DEBUG_AI
end

function denial:machine()
	if not self.armed and hud.p2_score > 1 then
		self.armed = true
		gm.level.pong.cfg.ai_enabled = true
		hud.p1_score = 0
		hud.p2_score = 0
	end
end

for i=2,5 do
	local st = stage:new("act"..i)
	stages[i] = st
	for a=1,3 do
		local ls = {}
		for b=1,3 do
			add(ls,line("act "..i.." section "..a.." line "..b,T_MED))
		end
		st:section(ls)
	end
	st.win_section = st:branch({line("act "..i.." you win",T_MED)})
	st.lose_section = st:branch({line("act "..i.." you lose",T_MED)})
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000201002335000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000201001735000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001f01001735000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
