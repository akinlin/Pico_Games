pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

--[[
    --Branch Goals--
    x migrate all game state into game_manager
    x create a pong object to contain the game
        x assign it to level
    x synchronize the pong and dialogue objects
    x fix the game_manager update function
]]
SCORE_TO_WIN = 11

PADDLE_SPEED = 4

-- [[ HELPER FUNCTIONS ]]
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
		--if timer.tick then timer.tick() end
		if timer.time > timer.delaytime then
			--if timer.event then timer.event() end
			timer.event()
			del(timers,timer)
		end
	end
end

-- [[ Game Manager ]]
game_manager = {}
-- states and events
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
					-- if no levels loaded exit to game over
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
        -- update pong
        pong.update_game_state()
        -- update dialogue
		self.level:update()
    elseif gm.state == game_manager.states.gameover then
        update_gameover_state()
    elseif gm.state == game_manager.states.intermission then
        -- update pong
        pong.update_game_state()
	end
end

function game_manager:draw()
    pong.draw_board()

	local states = {
		[game_manager.states.title] = function()
			print("title",44,60)
        end,
		[game_manager.states.menu] = function()
			print("press ❎ to start",32,64,7)
        end,
		[game_manager.states.options] = function()
			print("options",44,60)
        end,
        [game_manager.states.level] = function()
            self.level:draw()
        end,
		[game_manager.states.gameover] = function()
			print("game over",45,60)
		end,
		[game_manager.states.intermission] = function()
            -- pong
            pong.draw_ball()
            print("press ❎ to continue",32,64,7)
		end
	}
	
	local state = states[self.state]
    if state then
        state()
    else
        printh('not draw state for '..self.state)
    end
end

-- [[ Level ]]
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
	self.textbox.rect.color=self.dialogue.color
	self.textbox:open(function() gm:event(level.events.tb_open) end)

    player1.visible = true
    player2.visible = true
end

function level:event(e)
    local actions = {
        [level.events.tb_open] = function()
            -- start text sequence
            self.dialogue:load_next()
        end,
        [level.events.tb_closed] = function()
            -- start section delay
            add_timer(5,function () self.textbox:open(function() gm:event(level.events.tb_open) end) end)
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
	-- pass input for pong
	-- pass input for texbox
end

function level:update()
	self.textbox:update()
end

function level:draw()
    pong.draw_ball()
	tb:draw()
end

--[[ INIT ]]
function _init()
    -- creates the global gm object
	gm = game_manager:new()
    gm.screenwidth = 128
    gm.screenheight = 128
	-- create textbox object
	tb = textbox:new(0,120,128,2,12)
    -- create pong object
    p = pong:new()
    p:reset_game()
	-- add 5 levels
	gm:add_level(level:new(dialogues[1],tb,p))
	gm:add_level(level:new(dialogues[2],tb,p))
	gm:add_level(level:new(dialogues[3],tb,p))
	gm:add_level(level:new(dialogues[4],tb,p))
	gm:add_level(level:new(dialogues[5],tb,p))
end

--[[ UPDATE ]]
function _update()
	gm:update()
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

--[[ DRAW ]]
function _draw()
	cls(0)

    gm:draw()

    -- debug rendering
    --draw_debug()
end

function draw_score()
    -- set enable, padding, wide, tall, inverted, dotty
    --poke(0x5f58, 0x1 | 0x2 | 0x4 | 0x8 | 0x20 | 0x40)
    --poke(0x5f58, 0x1 | 0x2 | 0x4 | 0x8)

    --print(hud.p1_score,hud.p1_x,hud.p1_y,hud.p1_color)
    --print(hud.p2_score,hud.p2_x,hud.p2_y,hud.p2_color)

    -- clear all flags, including enable
    --poke(0x5f58, 0)

    print("\^p" .. hud.p1_score,hud.p1_x,hud.p1_y,hud.p1_color)
    print("\^p" .. hud.p2_score,hud.p2_x,hud.p2_y,hud.p2_color)
end

function draw_debug()
    -- draw collsion box on wall
    for x=1,#walls do 
        if (walls[x].collision_debug_draw) then 
            if (walls[x].collsionpt) then
                rect(walls[x].collsionpt.x,walls[x].collsionpt.y,walls[x].collsionpt.x+2,walls[x].collsionpt.y+2,walls[x].collisiontextboxcolor)
            end
        end
    end

    -- debug prediction collision box drawing
    if (predictwall.collsionpt) then
        rect(predictwall.collsionpt.x,predictwall.collsionpt.y,predictwall.collsionpt.x+2,predictwall.collsionpt.y+2,predictwall.collisiontextboxcolor)
    end
    if (player1.prediction) then
        rect(player1.prediction.x,player1.prediction.y,player1.prediction.x+2,player1.prediction.y+2,player1.collisiontextboxcolor)
    end

    rect(predictwall.x,predictwall.y,predictwall.x+predictwall.width,predictwall.y+predictwall.height,8)
end

-->8
-- pong
pong = {}
pong.__index = pong
function pong:new()
	local p = {}
    setmetatable(p,pong)
	return p
end

function pong:reset_game()
    self:init_board()
    self:init_hud()
    self:init_players()
    self:init_ball()
    self:init_ai()

    timelast = time()
    dt = 0

    gm:change_state(game_manager.states.menu)
end

function pong:init_board()
    walls = {}
    local top = self:create_wall(0,-4,gm.screenwidth,3)
    add(walls, top)

    local bottom = self:create_wall(0,gm.screenheight,gm.screenwidth,3)
    add(walls, bottom)

    self:init_net()
end

function pong:init_net()
    net = {
        block_width = 0,
        block_height = 1,
        block_space = 3,
        x = 58,
        y = 0,
        color = 6,
        drawnet = function()
            ypos = net.y
            while (ypos < 128) do
                rectfill(net.x,ypos,net.x+net.block_width,ypos+net.block_height,net.color)
                ypos += net.block_height + net.block_space
            end
        end
    }
end

function pong:init_hud()
    hud = {
        p1_score = 0,
        p1_x = 25,
        p1_y = 10,
        p1_color = 7,
        -- p2 is human player
        p2_score = 0,
        p2_x = 115,
        p2_y = 10,
        p2_color = 7,
    }
end

function pong:init_players()
    -- player paddels are added to the walls array for rendering
    local paddle_width = 1
    local paddle_height = 5
    local paddle_starting_y = (gm.screenheight/2)-(paddle_height/2)
    player1 = self:create_wall(3,paddle_starting_y,paddle_width,paddle_height)
    player1.dir = 1
    -- in a 1 player game player1 is ai, add prediction member
    player1.prediction = nil
    player1.level = 8
    player1.collisiontextboxcolor = 14
    player1.visible = false
    add(walls, player1)
    -- test wall for ai prediction
    predictwall = self:create_wall(player1.x,-100,player1.width,gm.screenheight+200)
    predictwall.collisiontextboxcolor = 10
    predictwall.drawf = function(a) rect(a.x,a.y,a.x+a.width,a.y+a.height,1) end

    -- player 2 is always a human player
    player2 = self:create_wall(gm.screenwidth-paddle_width-8,paddle_starting_y,paddle_width,paddle_height)
    player2.dir = 1
    player2.visible = false
    add(walls, player2)
end

function pong:init_ball()
    MAX_ACCEL = 10
    MAX_SPEED = 160
    
    local rad = 1
    local nx = rad
    local ny = 3 + rad
    local xx = gm.screenwidth - rad
    local xy = gm.screenheight - 3 - rad
    local acc = 1
    
    ball = {
        radius = rad,
        color = 6,
        minx = nx,
        miny = ny,
        maxx = xx,
        maxy = xy,
        x = 64,
        y = rnd(xy),
        dx = (xx - nx) / (flr(rnd(7)+1) * coin_flip()),
        dy = (xy - ny) / (flr(rnd(7)+1) * coin_flip()),
        accel = acc
    }
end

function pong:init_ai()
    AILevels = {}
    self:create_aitype(0.2, 1) -- 1: ai is losing by 8
    self:create_aitype(0.3, 5) -- 2: ai is losing by 7
    self:create_aitype(0.4, 10) -- 3: ai is losing by 6
    self:create_aitype(0.5, 15) -- 4: ai is losing by 5
    self:create_aitype(0.6, 20) -- 5: ai is losing by 4
    self:create_aitype(0.7, 25) -- 6:ai is losing by 3
    self:create_aitype(0.8, 30) -- 7: ai is losing by 2
    self:create_aitype(0.9, 35) -- 8: ai is losing by 1 
    self:create_aitype(1.0, 40) -- 9: tie
    self:create_aitype(1.1, 45) -- 10: ai is winning by 1
    self:create_aitype(1.2, 50) -- 11: ai is winning by 2
    self:create_aitype(1.3, 55) -- 12: ai is winning by 3
    self:create_aitype(1.4, 60) -- 13: ai is winning by 4
    self:create_aitype(1.5, 65) -- 14: ai is winning by 5
    self:create_aitype(1.6, 70) -- 15: ai is winning by 6
    self:create_aitype(1.7, 75) -- 16: ai is winning by 7
    self:create_aitype(1.8, 80) -- 17: ai is winning by 8
end

function pong:create_aitype(reaction, error)
    a = {
        aiReaction = reaction,
        aiError = error
    }
    add(AILevels, a)
    return a
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
        color = 6,
        visible = true,
        collsion = true,
        collsionpt = nil,
        collisiontextboxcolor = 8,
        collision_debug_draw = false,
        drawf = function(a)
                    rectfill(a.x,a.y,a.x+a.width,a.y+a.height,a.color)
                end
    }

    return wall
end

function pong.update_game_state()
    pong.handle_game_input()

    dt = time() - timelast
    timelast = time()

    -- todo: check if ball is in the safe zone
    if (ball.x > -ball.radius) and (ball.x < gm.screenwidth + ball.radius) and 
        (ball.y < gm.screenheight+ball.radius) and (ball.y > -ball.radius) then 
        pong.update_ball(dt)
    else
        if (ball.dx > 0) then 
            hud.p1_score += 1
            if (player1.level < 17) then
                player1.level += 1
            end
        else 
            hud.p2_score += 1
            if (player1.level > 1) then
                player1.level -= 1
            end
        end
        if (hud.p1_score == SCORE_TO_WIN) or (hud.p2_score == SCORE_TO_WIN) then 
            --gm:change_state(game_manager.states.gameover)
            --player1.visible = false
            --player2.visible = false
        end
        p:init_ball()
    end

    pong.run_ai(dt, ball)
end

function pong.handle_game_input()
    local inputdx = 0
    if (btn(⬇️)) then
        if (player2.y < gm.screenheight - player2.height - 3) then
            player2.dir = 1
            inputdx = PADDLE_SPEED
        else
            player2.y = gm.screenheight - player2.height - 3
        end
    end

    if (btn(⬆️)) then
        if (player2.y > 3) then
            player2.dir = -1
            inputdx = PADDLE_SPEED
        else
            player2.y = 3
        end
    end
    player2.y += (inputdx*player2.dir)
end

function pong.accelerate(x, y, dx, dy, accel, dt)
    -- update position
    local x2 = x + (dx * dt)
    local y2 = y + (dy * dt)

    -- add acceleration
    local dx2
    if (abs(dx) < MAX_SPEED) then 
        local acceldirx
        if (dx < 0) then acceldirx = (accel*-1) else acceldirx = (accel*1) end
        dx2 = dx + (acceldirx * dt)
    else
        dx2 = dx
    end

    local dy2
    if (abs(dy) < MAX_SPEED) then 
        local acceldiry
        if (dy < 0) then acceldiry = (accel*-1) else acceldiry = (accel*1) end
        dy2 = dy + (acceldiry * dt)
    else
        dy2 = dy
    end

    -- return new position
    local p={
        nx = x2-x,
        ny = y2-y,
        x = x2,
        y = y2,
        dx = dx2,
        dy = dy2
    }

    return p
end

function pong.update_ball(dt)
    local pos = pong.accelerate(ball.x, ball.y, ball.dx, ball.dy, ball.accel, dt)

    -- loop all walls until a collsion is detected
    local x = 1
    local pt = nil
    while (pt == nil) and (x <= #walls) do
        if (walls[x].collsion) then
            pt = pong.ball_intercept(ball, walls[x], pos.nx, pos.ny)
            if (pt) then
                walls[x].collsionpt = {x=pt.x,y=pt.y,d=pt.d}
            end
        end
        x += 1
    end

    if pt then
        if (pt.d == 'left' or pt.d == 'right') then
            pos.x = pt.x
            pos.dx = -pos.dx
        elseif (pt.d == 'top' or pt.d == 'bottom') then
            pos.y = pt.y
            pos.dy = -pos.dy
        end
    end

    -- add/remove spin based on paddle direction
    if (player1.collsionpt) or (player2.collsionpt) then
        if (player1.collsionpt) then
            pong.apply_spin(player1, pos)
            player1.collsionpt = nil
        else
            pong.apply_spin(player2, pos)
            player2.collsionpt = nil
        end
    end

    ball.x = pos.x
    ball.y = pos.y
    ball.dx = pos.dx
    ball.dy = pos.dy
end

function pong.apply_spin(collision_wall, pos)
    if (collision_wall.dir == -1) then
        local delta
        if (pos.dy < 0) then delta = .5 else delta = 1.5 end
        pos.dy = pos.dy * delta
    elseif (collision_wall.dir == 1) then
        local delta
        if (pos.dy > 0) then delta = .5 else delta = 1.5 end
        pos.dy = pos.dy * delta
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
    -- todo: add support for a screen bounding box 
    -- clipping the line extentions so the numbers dont go above 32K
    if (x1 > 140) then x1 = 140 elseif (x1 < -50) then x1 = -50 end
    if (x2 > 140) then x2 = 140 elseif (x2 < -50) then x2 = -50 end
    if (x3 > 140) then x3 = 140 elseif (x3 < -50) then x3 = -50 end
    if (x4 > 140) then x4 = 140 elseif (x4 < -50) then x4 = -50 end
     
    if (y1 > 140) then y1 = 140 elseif (y1 < -50) then y1 = -50 end
    if (y2 > 140) then y2 = 140 elseif (y2 < -50) then y2 = -50 end
    if (y3 > 140) then y3 = 140 elseif (y3 < -50) then y3 = -50 end
    if (y4 > 140) then y4 = 140 elseif (y4 < -50) then y4 = -50 end

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

function pong.run_ai(dt, ball)
    -- check if the ball is coming or going
    if (((ball.x < player1.x) and (ball.dx < 0)) or
        ((ball.x > player1.x+player1.width) and (ball.dx > 0))) then
        player1.dir = 0
        return
    end

    -- if coming predict the intersection point
    pong.predict(ball, dt)

    if (player1.prediction) then
        if (player1.prediction.y < (player1.y + player1.height/2 - 2)) then
            player1.dir = -1
        elseif (player1.prediction.y > ((player1.y+player1.height) - player1.height/2 + 2)) then
            player1.dir = 1
        else
            player1.dir = 0
        end
    end
    player1.y += (PADDLE_SPEED*player1.dir)
    if (player1.y < 3) then
        player1.y = 3
    end
    if (player1.y > gm.screenheight - player1.height - 3) then
        player1.y = gm.screenheight - player1.height - 3
    end
end

function pong.predict(ball, dt)
    -- only re-predict if the ball changed direction, or its been some amount of time since last prediction
    if (player1.prediction) then
        if ((player1.prediction.dx * ball.dx) > 0) and
            ((player1.prediction.dy * ball.dy) > 0) and
            (player1.prediction.since < AILevels[player1.level].aiReaction) then
                player1.prediction.since += dt
                return
        end
    end

    local pt = pong.ball_intercept(ball, predictwall, ball.dx * 2, ball.dy * 2)

    if (pt) then
        predictwall.collsionpt = {x=pt.x,y=pt.y,d=pt.d}
        local t = 3 + ball.radius
        local b = gm.screenheight - 3 - ball.radius

        while ((pt.y < t) or (pt.y > b)) do
            if (pt.y < t) then
                pt.y = t + (t - pt.y)
            elseif (pt.y > b) then
                pt.y = t + (b - t) - (pt.y - b)
            end
        end
        player1.prediction = {x=pt.x,y=pt.y,d=pt.d}
    else
        player1.prediction = nil
        predictwall.collsionpt = nil
    end

    if (player1.prediction) then
        player1.prediction.since = 0
        player1.prediction.dx = ball.dx
        player1.prediction.dy = ball.dy
        player1.prediction.radius = ball.radius
        player1.prediction.exactX = player1.prediction.x
        player1.prediction.exactY = player1.prediction.y
        local closeness = 0
        if (ball.dx < 0) then closeness = (ball.x - (player1.x+player1.width)) / gm.screenwidth else closeness = (player1.x - ball.x) / gm.screenwidth end
        local error = AILevels[player1.level].aiError * closeness
        player1.prediction.y = player1.prediction.y + (rnd(error*2) - error)
    end
end

function pong.draw_board()
    -- draw walls
    for x=1,#walls do
        if (walls[x].visible) then walls[x].drawf(walls[x]) end
    end

    -- net
    net.drawnet()

    -- hud
    draw_score()
end

function pong.draw_ball()
    rectfill(ball.x,ball.y,ball.x+ball.radius,ball.y+ball.radius,ball.color)
    --circfill(ball.x, ball.y, ball.radius, ball.color)
end
-->8
-- dialogue system
dialogue = {}

function dialogue:new(t,c,debug)
	local d = {
		complete=false,
		sections={},
		index=1,
		title=t,
		color=c
	}

	-- todo: review best options for storing/loading dialogue
	-- debug dialogue creation 
	-- between 3-5 sections
	-- between 5-8 phrases
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
		-- increment phrase index
		self.section.index += 1
		if self.section.index > #self.section.phrases then
			-- increment section index
			self.index += 1
			if self.index > #self.sections then
				-- sequence complete, fire event for handing at game_manager
				self.complete=true
				gm:event(level.events.sequence_complete)
			else
				-- section complete, fire event for handling at level
				gm:event(level.events.section_complete)
			end
		else
			-- keep timer going and load next phrase
			gm:event(level.events.phrase_complete)
			self:load_next()
		end
	end
end

--[[ textbox ]]
textbox = {}
textbox.__index = textbox
textbox.states = {closed=1,opening=2,open=3,closing=4}
function textbox:new(xpos,ypos,w,h,c)
	local tb = {
		visible=false,
		textvisible=false,
		state=textbox.states.closed,
		callback=nil,

		-- UI box
		rect = {
			x0=xpos,
			y0=ypos,
			x1=xpos,
			y1=ypos,
			color=c
		},	
		width=w,
		height=h,

		-- Debug print
		sectiontitle='no title',
		sectionphrase='no phrase',
		
		-- Customizations
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

		-- Debug print
		if self.textvisible then
            blinkert+=1
            if blinkert > 7 then
                blinkert = 0
                if blinkerc == 16 then blinkerc = 32 else blinkerc = 16 end
            end
			--print(self.sectiontitle,10,64,7)
			print(chr(62)..' '..self.sectionphrase..' '..chr(blinkerc),rect.x0+2,rect.y0+2,7)
		end
	end
end

function textbox:update()
	-- animate
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
-- rigid bodies
-->8
-- diaglogue
dialogues={}

function printdialogue(d,i)
    printh('--dialogues['..i..']--')
    for x=1,#d.sections do 
        printh(' section['..x..']')
        local section = d.sections[x]
        for y=1,#section.phrases do 
            printh(' phrase['..y..']='..section.phrases[y].text)
        end
    end
end
-- starts on player score at 2
-- open textbox
-- displays 'hello' for 6 seconds = 30*6=180
-- close textbox
-- wait 10 seconds
-- open textbox
-- display 'where is..' for 6 seconds = 30*6=180
-- display 'are they..' for 8 seconds = 30*8=240
-- close textbox
-- end level

local dialogue_denial = dialogue:new('denial',0,false)
dialogues[1]=dialogue_denial
local section = dialogue.create_section()
add(dialogue_denial.sections,section)
    add(section.phrases,dialogue.create_phrase('hello!?',7,180))
local section2 = dialogue.create_section()
add(dialogue_denial.sections,section2)
    add(section2.phrases,dialogue.create_phrase('where is the second player?',7,180))
    add(section2.phrases,dialogue.create_phrase('are they in the bathroom?',7,240))
    add(section2.phrases,dialogue.create_phrase('maybe you should wait for them',7,50))
    add(section2.phrases,dialogue.create_phrase('its their quarter too',7,100))
local section3 = dialogue.create_section()
add(dialogue_denial.sections,section3)
    add(section3.phrases,dialogue.create_phrase('you know pong is a 2-player game right?',7,180))
    add(section3.phrases,dialogue.create_phrase('is it?...',7,50))
    add(section3.phrases,dialogue.create_phrase('that you..',7,50))
    add(section3.phrases,dialogue.create_phrase('dont have any friends?',7,180))
    add(section3.phrases,dialogue.create_phrase('i mean if so, thats fine',7,100))
    add(section3.phrases,dialogue.create_phrase('i dont have any either',7,180))
    add(section3.phrases,dialogue.create_phrase('i just...',7,60))
    add(section3.phrases,dialogue.create_phrase('sorry what i mean is',7,30))
    add(section3.phrases,dialogue.create_phrase('do you want some help?',7,100))
    add(section3.phrases,dialogue.create_phrase('i could play',7,150))
local section4 = dialogue.create_section()
add(dialogue_denial.sections,section4)
    add(section4.phrases,dialogue.create_phrase('kinda excited, actually',7,120))
    add(section4.phrases,dialogue.create_phrase('never got to play before',7,180))
    add(section4.phrases,dialogue.create_phrase('i bet i am really good',7,90))
    add(section4.phrases,dialogue.create_phrase('like super good i bet',7,90))
    add(section4.phrases,dialogue.create_phrase('brb, gonna jump in real quick',7,180))


dialogues[2]=dialogue:new('anger',8,true)
dialogues[3]=dialogue:new('bargining',9,true)
dialogues[4]=dialogue:new('depression',1,true)
dialogues[5]=dialogue:new('acceptance',3,true)

printdialogue(dialogue_denial,1)
printdialogue(dialogues[2],2)
printdialogue(dialogues[3],3)
printdialogue(dialogues[4],4)
printdialogue(dialogues[5],5)

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
