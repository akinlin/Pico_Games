pico-8 cartridge // http://www.pico-8.com
version 32
__lua__

SCREEN_WIDTH = 128
SCREEN_HEIGHT = 128

-- [[ HELPER FUNCTIONS ]]
function coin_flip()
    if rnd(2) > 1 then
        return 1
    end
    return -1
end

--[[ INIT ]]
function _init()
    init_board()
    init_hud()
    init_players()
    init_ball()

    timelast = time()
    dt = 0
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
        -- p2 is human player
        p1_score = 0,
        p1_x = 55,
        p1_y = 7,
        p1_color = 7,

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
    player1 = create_wall(0,paddle_starting_y,paddle_width,paddle_height)
    player1.dir = 1
    add(walls, player1)

    -- player 2 is the human player
    player2 = create_wall(SCREEN_WIDTH-paddle_width-1,paddle_starting_y,paddle_width,paddle_height)
    player2.dir = 1
    add(walls, player2)
end

function init_ball()
    local rad = .5
    local nx = rad
    local ny = 3 + rad
    local xx = SCREEN_WIDTH - rad
    local xy = SCREEN_HEIGHT - 3 - rad
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
        dy = (xy - ny) / (flr(rnd(10)+1) * coin_flip())
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
    dt = time() - timelast
    timelast = time()

    update_ball()

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

function update_ball()
    ball.x += (ball.dx * dt)
    ball.y += (ball.dy * dt)

    if ball.dx > 0 and ball.x > ball.maxx then
        ball.x = ball.maxx
        ball.dx = -ball.dx
    elseif ball.dx < 0 and ball.x < ball.minx then
        ball.x = ball.minx
        ball.dx = -ball.dx
    end

    if ball.dy > 0 and ball.y > ball.maxy then
        ball.y = ball.maxy
        ball.dy = -ball.dy
    elseif ball.dy < 0 and ball.y < ball.miny then
        ball.y = ball.miny
        ball.dy = -ball.dy
    end
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
    draw_ball()

    print(ball.dx)
    print(ball.dy)
end

function draw_board()
    -- top/bot bars
    for x=1,#walls do 
        walls[x].drawf(walls[x])
    end

    -- net
    net.drawnet()

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
