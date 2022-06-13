pico-8 cartridge // http://www.pico-8.com
version 32
__lua__

SCREEN_WIDTH = 128
SCREEN_HEIGHT = 128

-- GAME STATES
GS_UNINITIALIZED = 0
GS_MENU = 1
GS_GAME = 2
GS_GAMEOVER = 3

GAME_STATE = GS_UNINITIALIZED

SCORE_TO_WIN = 11

-- [[ HELPER FUNCTIONS ]]
function coin_flip()
    if rnd(2) > 1 then
        return 1
    end
    return -1
end

--[[ INIT ]]
function _init()
    reset_game()
end

function reset_game()
    init_board()
    init_hud()
    init_players()
    init_ball()
    init_ai()

    timelast = time()
    dt = 0

    GAME_STATE = GS_MENU
end

function init_board()
    walls = {}
    local top = create_wall(0,-4,SCREEN_WIDTH,3)
    add(walls, top)

    local bottom = create_wall(0,SCREEN_HEIGHT,SCREEN_WIDTH,3)
    add(walls, bottom)

    init_net()
end

function init_net()
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

function init_hud()
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

function init_players()
    -- player paddels are added to the walls array for rendering
    local paddle_width = 1
    local paddle_height = 5
    local paddle_starting_y = (SCREEN_HEIGHT/2)-(paddle_height/2)
    player1 = create_wall(3,paddle_starting_y,paddle_width,paddle_height)
    player1.dir = 1
    -- in a 1 player game player1 is ai, add prediction member
    player1.prediction = nil
    player1.level = 8
    player1.collisiontextboxcolor = 14
    add(walls, player1)
    -- test wall for ai prediction
    predictwall = create_wall(player1.x,-100,player1.width,SCREEN_HEIGHT+200)
    predictwall.collisiontextboxcolor = 10
    predictwall.drawf = function(a) rect(a.x,a.y,a.x+a.width,a.y+a.height,1) end

    -- player 2 is always a human player
    player2 = create_wall(SCREEN_WIDTH-paddle_width-8,paddle_starting_y,paddle_width,paddle_height)
    player2.dir = 1
    add(walls, player2)
end

function init_ball()
    MAX_ACCEL = 10
    MAX_SPEED = 160
    
    local rad = 1
    local nx = rad
    local ny = 3 + rad
    local xx = SCREEN_WIDTH - rad
    local xy = SCREEN_HEIGHT - 3 - rad
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

function init_ai()
    AILevels = {}
    create_aitype(0.2, 40) -- 1: ai is losing by 8
    create_aitype(0.3, 50) -- 2: ai is losing by 7
    create_aitype(0.4, 60) -- 3: ai is losing by 6
    create_aitype(0.5, 70) -- 4: ai is losing by 5
    create_aitype(0.6, 80) -- 5: ai is losing by 4
    create_aitype(0.7, 90) -- 6:ai is losing by 3
    create_aitype(0.8, 100) -- 7: ai is losing by 2
    create_aitype(0.9, 110) -- 8: ai is losing by 1 
    create_aitype(1.0, 120) -- 9: tie
    create_aitype(1.1, 130) -- 10: ai is winning by 1
    create_aitype(1.2, 140) -- 11: ai is winning by 2
    create_aitype(1.3, 150) -- 12: ai is winning by 3
    create_aitype(1.4, 160) -- 13: ai is winning by 4
    create_aitype(1.5, 170) -- 14: ai is winning by 5
    create_aitype(1.6, 180) -- 15: ai is winning by 6
    create_aitype(1.7, 190) -- 16: ai is winning by 7
    create_aitype(1.8, 200) -- 17: ai is winning by 8
end

function create_aitype(reaction, error)
    a = {
        aiReaction = reaction,
        aiError = error
    }
    add(AILevels, a)
    return a
end

function create_prediction(s,dx,r,ex,ey,x,y,d)
    p = {
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

function create_wall(xpos,ypos,w,h)
    wall = {
        width = w,
        height = h,
        x = xpos,
        y = ypos,
        color = 6,
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

--[[ UPDATE ]]
function _update()
    if GAME_STATE == GS_MENU then
        update_menu_state()
    elseif GAME_STATE == GS_GAME then
        update_game_state()
    elseif GAME_STATE == GS_GAMEOVER then
        update_gameover_state()
    end
end

function update_menu_state()
    if btnp(❎) then
        GAME_STATE = GS_GAME
    end
end

function update_game_state()
    handle_game_input()

    dt = time() - timelast
    timelast = time()

    -- todo: check if ball is in the safe zone
    if (ball.x > -ball.radius) and (ball.x < SCREEN_WIDTH + ball.radius) and 
        (ball.y < SCREEN_HEIGHT+ball.radius) and (ball.y > -ball.radius) then 
        update_ball(dt)
    else
        if (ball.dx > 0) then hud.p1_score += 1 else hud.p2_score += 1 end
        if (hud.p1_score == SCORE_TO_WIN) or (hud.p2_score == SCORE_TO_WIN) then GAME_STATE = GS_GAMEOVER end
        init_ball()
    end

    run_ai(dt, ball)
end

function handle_game_input()
    local inputdx = 0
    if (btn(⬇️)) then
        if (player2.y < SCREEN_HEIGHT - player2.height - 3) then
            player2.dir = 1
            inputdx = 1.5
        else
            player2.y = SCREEN_HEIGHT - player2.height - 3
        end
    end

    if (btn(⬆️)) then
        if (player2.y > 3) then
            player2.dir = -1
            inputdx = 1.5
        else
            player2.y = 3
        end
    end
    player2.y += (inputdx*player2.dir)
end

function update_gameover_state()
    if btnp(❎) then
        reset_game()
    end
end

function accelerate(x, y, dx, dy, accel, dt)
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
    p={
        nx = x2-x,
        ny = y2-y,
        x = x2,
        y = y2,
        dx = dx2,
        dy = dy2
    }

    return p
end

function update_ball(dt)
    local pos = accelerate(ball.x, ball.y, ball.dx, ball.dy, ball.accel, dt)

    -- loop all walls until a collsion is detected
    local x = 1
    local pt = nil
    while (pt == nil) and (x <= #walls) do
        if (walls[x].collsion) then
            pt = ball_intercept(ball, walls[x], pos.nx, pos.ny)
            if (pt) then
                walls[x].collsionpt = {x=pt.x,y=pt.y,d=pt.d}
            end
        end
        x += 1
    end

    if pt then
        if (pt.d == 'left' or pt.d == 'right') then
            pos.x = pt.x;
            pos.dx = -pos.dx;
        elseif (pt.d == 'top' or pt.d == 'bottom') then
            pos.y = pt.y;
            pos.dy = -pos.dy;
        end
    end

    -- add/remove spin based on paddle direction
    if (player1.collsionpt) or (player2.collsionpt) then
        if (player1.collsionpt) then
            apply_spin(player1, pos)
            player1.collsionpt = nil
        else
            apply_spin(player2, pos)
            player2.collsionpt = nil
        end
    end

    ball.x = pos.x
    ball.y = pos.y
    ball.dx = pos.dx
    ball.dy = pos.dy
end

function apply_spin(collision_wall, pos)
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

function ball_intercept(ball, paddle, nx, ny)
    pt = nil
    if (nx < 0) then
        pt = intercept(ball.x, ball.y, ball.x + nx, ball.y + ny, 
                        (paddle.x+paddle.width)  + ball.radius, 
                        paddle.y - ball.radius, 
                        (paddle.x+paddle.width)  + ball.radius, 
                        (paddle.y+paddle.height) + ball.radius, 
                        "right")
    elseif (nx > 0) then
        pt = intercept(ball.x, ball.y, ball.x + nx, ball.y + ny, 
                        paddle.x - ball.radius, 
                        paddle.y - ball.radius, 
                        paddle.x - ball.radius, 
                        (paddle.y+paddle.height) + ball.radius,
                        "left")
    end

    if (pt == nil) then
        if (ny < 0) then
            pt = intercept(ball.x, ball.y, ball.x + nx, ball.y + ny, 
                            (paddle.x+paddle.width)   - ball.radius, 
                            (paddle.y+paddle.height) + ball.radius, 
                            paddle.x  + ball.radius, 
                            (paddle.y+paddle.height) + ball.radius,
                            "bottom")
        elseif (ny > 0) then
            pt = intercept(ball.x, ball.y, ball.x + nx, ball.y + ny, 
                            paddle.x   - ball.radius, 
                            paddle.y    - ball.radius, 
                            (paddle.x+paddle.width)  + ball.radius, 
                            paddle.y    - ball.radius,
                            "top")
        end
    end
    return pt
end

function intercept(x1, y1, x2, y2, x3, y3, x4, y4, d)
    local denom = ((y4-y3) * (x2-x1)) - ((x4-x3) * (y2-y1))
    if (denom != 0) then
        local ua = (((x4-x3) * (y1-y3)) - ((y4-y3) * (x1-x3))) / denom
        if ((ua >= 0) and (ua <= 1)) then
            local ub = (((x2-x1) * (y1-y3)) - ((y2-y1) * (x1-x3))) / denom
            if ((ub >= 0) and (ub <= 1)) then
                local x = x1 + (ua * (x2-x1))
                local y = y1 + (ua * (y2-y1))
                return { x = x, y = y, d = d}
            end
        end
    end
    return nil
end

function run_ai(dt, ball)
    -- check if the ball is coming or going
    if (((ball.x < player1.x) and (ball.dx < 0)) or
        ((ball.x > player1.x+player1.width) and (ball.dx > 0))) then
        player1.dir = 0
        return
    end

    -- if coming predict the intersection point
    predict(ball, dt);

    if (player1.prediction) then
        if (player1.prediction.y < (player1.y + player1.height/2 - 5)) then
            player1.dir = -1
        elseif (player1.prediction.y > ((player1.y+player1.height) - player1.height/2 + 5)) then
            player1.dir = 1
        else
            player1.dir = 0
        end
    end
    player1.y += (1.5*player1.dir)
    if (player1.y < 3) then
        player1.y = 3
    end
    if (player1.y > SCREEN_HEIGHT - player1.height - 3) then
        player1.y = SCREEN_HEIGHT - player1.height - 3
    end
end

function predict(ball, dt)
    -- only re-predict if the ball changed direction, or its been some amount of time since last prediction
    if (player1.prediction) then
        if ((player1.prediction.dx * ball.dx) > 0) and
            ((player1.prediction.dy * ball.dy) > 0) and
            (player1.prediction.since < AILevels[player1.level].aiReaction) then
                player1.prediction.since += dt
                return
        end
    end

    local pt = ball_intercept(ball, predictwall, ball.dx * 2, ball.dy * 2)

    if (pt) then
        predictwall.collsionpt = {x=pt.x,y=pt.y,d=pt.d}
        local t = 3 + ball.radius
        local b = SCREEN_HEIGHT - 3 - ball.radius

        while ((pt.y < t) or (pt.y > b)) do
            if (pt.y < t) then
                pt.y = t + (t - pt.y)
            elseif (pt.y > b) then
                pt.y = t + (b - t) - (pt.y - b);
            end
        end
        player1.prediction = {x=pt.x,y=pt.y,d=pt.d}
    else
        player1.prediction = nil
        predictwall.collsionpt = nil
    end

    if (player1.prediction) then
        player1.prediction.since = 0;
        player1.prediction.dx = ball.dx;
        player1.prediction.dy = ball.dy;
        player1.prediction.radius = ball.radius;
        player1.prediction.exactX = player1.prediction.x;
        player1.prediction.exactY = player1.prediction.y;
        local closeness = 0
        if (ball.dx < 0) then closeness = (ball.x - (player1.x+player1.width)) / SCREEN_WIDTH else closeness = (player1.x - ball.x) / SCREEN_WIDTH end
        local error = AILevels[player1.level].aiError * closeness;
        player1.prediction.y = player1.prediction.y + (rnd(error*2) - error);
    end
end

--[[ DRAW ]]
function _draw()
	cls(0)

    draw_board()

    if (GAME_STATE == GS_GAME) then
        draw_ball()
    elseif (GAME_STATE == GS_MENU) then
        print("press ❎ to start",32,64,7)
    elseif (GAME_STATE == GS_GAMEOVER) then
        if (hud.p2_score > hud.p1_score) then
            print("you win!!",45,64,7)
        else
            print("you lose!!",45,64,7)
        end
    end

    -- debug rendering
    --draw_debug()
end

function draw_board()
    -- draw walls
    for x=1,#walls do 
        walls[x].drawf(walls[x])
    end

    -- net
    if (GAME_STATE == GS_GAME) then
        net.drawnet()
    end

    -- hud
    draw_score()
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

function draw_ball()
    rectfill(ball.x,ball.y,ball.x+ball.radius,ball.y+ball.radius,ball.color)
    --circfill(ball.x, ball.y, ball.radius, ball.color)
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
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
