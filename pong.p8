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

    timelast = time()
    dt = 0

    GAME_STATE = GS_MENU
end

function init_board()
    walls = {}
    local top = create_wall(0,0,SCREEN_WIDTH,3)
    add(walls, top)

    local bottom = create_wall(0,SCREEN_HEIGHT-3,SCREEN_WIDTH,3)
    add(walls, bottom)

    net = {
        block_width = 1,
        block_height = 1,
        block_space = 3,
        x = 64-.5,
        y = 0,
        color = 7,
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
        p1_x = 55,
        p1_y = 7,
        p1_color = 7,
        -- p2 is human player
        p2_score = 0,
        p2_x = 68,
        p2_y = 7,
        p2_color = 7,

        -- test variables
        test_p1_timedx = time(),
        test_p2_timedx = time(),
        test_p1_resettime = rnd(3),
        test_p2_resettime = rnd(3)
    }
end

function init_players()
    -- player paddels are added to the walls array for rendering
    local paddle_width = 2
    local paddle_height = 16
    local paddle_starting_y = (SCREEN_HEIGHT/2)-(paddle_height/2)
    player1 = create_wall(10,paddle_starting_y,paddle_width,paddle_height)
    player1.dir = 1
    add(walls, player1)

    -- player 2 is the human player
    player2 = create_wall(SCREEN_WIDTH-paddle_width-10,paddle_starting_y,paddle_width,paddle_height)
    player2.dir = 1
    add(walls, player2)
end

function init_ball()
    local rad = 1
    local nx = rad
    local ny = 3 + rad
    local xx = SCREEN_WIDTH - rad
    local xy = SCREEN_HEIGHT - 3 - rad
    local acc = 1
    MAX_ACCEL = 10
    MAX_SPEED = 150
    ball = {
        radius = rad,
        color = 9,
        minx = nx,
        miny = ny,
        maxx = xx,
        maxy = xy,
        x = rnd(xx),
        y = rnd(xy),
        dx = (xx - nx) / (flr(rnd(10)+1) * coin_flip()),
        dy = (xy - ny) / (flr(rnd(10)+1) * coin_flip()),
        accel = acc
    }
end

function create_wall(xpos,ypos,w,h)
    wall = {
        width = w,
        height = h,
        x = xpos,
        y = ypos,
        color = 7,
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

    update_ball(dt)

    -- test score changes
    if time() - hud.test_p1_timedx > hud.test_p1_resettime then
        hud.p1_score = flr(rnd(9))
        hud.test_p1_timedx = time()
        hud.test_p1_resettime = rnd(3)
    end
    if time() - hud.test_p2_timedx > hud.test_p2_resettime then
        hud.p2_score = flr(rnd(9))
        hud.test_p2_timedx = time()
        hud.test_p2_resettime = rnd(3)
    end

    -- test paddle movement
    test_update_paddle(player1)
    test_update_paddle(player2)
end

function handle_game_input()
    if btnp(❎) then
        GAME_STATE = GS_GAMEOVER
    end
end

function update_gameover_state()
    if btnp(❎) then
        reset_game()
    end
end

function accelerate(x, y, dx, dy, accel, dt)
    local x2 = x + (dx * dt)
    local y2 = y + (dy * dt)

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

    if pos.dx > 0 and pos.x > ball.maxx then
        pos.x = ball.maxx
        pos.dx = -pos.dx
        if (ball.accel < MAX_ACCEL) then ball.accel += 3 end
    elseif pos.dx < 0 and pos.x < ball.minx then
        pos.x = ball.minx
        pos.dx = -pos.dx
        if (ball.accel < MAX_ACCEL) then ball.accel += 3 end
    end

    if pos.dy > 0 and pos.y > ball.maxy then
        pos.y = ball.maxy
        pos.dy = -pos.dy
        if (ball.accel < MAX_ACCEL) then ball.accel += 3 end
    elseif pos.dy < 0 and pos.y < ball.miny then
        pos.y = ball.miny
        pos.dy = -pos.dy
        if (ball.accel < MAX_ACCEL) then ball.accel += 3 end
    end

    paddle = nil
    if (pos.dx < 0) then paddle = player1 else paddle = player2 end
    local pt = ball_intercept(ball, paddle, pos.nx, pos.ny)

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
    if (paddle.up) then
        local delta
        if (pos.dy < 0) then delta = .5 delta = 1.5 end
        pos.dy = pos.dy * delta
    elseif (paddle.down) then
        local delta
        if (pos.dy > 0) then delta = .5 delta = 1.5 end
        pos.dy = pos.dy * delta
    end

    ball.x = pos.x
    ball.y = pos.y
    ball.dx = pos.dx
    ball.dy = pos.dy
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
                            (paddle.x+paddle.width)  + ball.radius, 
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
    return nil;
end

function test_update_paddle(a)
    a.y += (1.5*a.dir)
    if a.y > 128 - a.height or a.y < 0 then
        a.dir *= -1
    end

    if flr(rnd(100)) == 5 then a.dir *= -1 end
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
        print("game over",45,64,7)
    end

    print(ball.dx)
    print(ball.dy)
end

function draw_board()
    -- top/bot bars
    for x=1,#walls do 
        walls[x].drawf(walls[x])
    end

    -- net
    if (GAME_STATE == GS_GAME) then
        net.drawnet()
    end

    -- hud
    print("\^p" .. hud.p1_score,hud.p1_x,hud.p1_y,hud.p1_color)
    print("\^p" .. hud.p2_score,hud.p2_x,hud.p2_y,hud.p2_color)
end

function draw_ball()
    circfill(ball.x, ball.y, ball.radius, ball.color)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
