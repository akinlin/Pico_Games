pico-8 cartridge // http://www.pico-8.com
version 32
__lua__

SCREEN_WIDTH = 128
SCREEN_HEIGHT = 128

--[[ INIT ]]
function _init()
    init_board()
    init_hud()
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
        p2_x = 70,
        p2_y = 7,
        p2_color = 7
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
end

--[[ DRAW ]]
function _draw()
	cls(0)

    draw_board()
end

function draw_board()
    -- top/bot bars
    for x=1,#walls do 
        walls[x].drawf(walls[x])
    end

    -- net
    net.drawnet()

    -- hud
    print(hud.p1_score,hud.p1_x,hud.p1_y,hud.p1_color)
    print(hud.p2_score,hud.p2_x,hud.p2_y,hud.p2_color)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
