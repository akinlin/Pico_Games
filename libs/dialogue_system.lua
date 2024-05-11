--[[ Dialogue System ]]
-- author: Alex Kinlin
-- alaph beta version

--[[ timer ]]
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
	if self.state == game_manager.states.level then
		self.level:update()
	end
end

function game_manager:draw()
	local states = {
		[game_manager.states.title] = function()
			print("title",44,60)
        end,
		[game_manager.states.menu] = function()
			print("main menu",45,60)
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
			print("press x to continue",25,60)
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
	self.textbox.sectionphrase=self.dialogue.phrase
	self.textbox.rect.color=self.dialogue.color
	self.textbox:open(function() gm:event(level.events.tb_open) end)
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
            self.textbox.sectionphrase=self.dialogue.phrase
            self.textbox:close(function () gm:event(level.events.tb_closed) end)
        end,
        [level.events.phrase_complete] = function()
            self.textbox.sectionphrase=self.dialogue.phrase
        end
    }

    local action = actions[e]
    if action then
        action()
    else
        self.dialogue:event(e)
    end
end

function level:input()
	-- pass input for pong
	-- pass input for texbox
end

function level:update()
	self.textbox:update()
end

function level:draw()
	self.textbox:draw()
end

-- [[ dialogue Object ]]
dialogue = {}

function dialogue:new(t,c)
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
	for x=1,flr(rnd(3))+3 do 
		local section = dialogue.create_section()
		add(d.sections,section)
		for y=1,flr(rnd(4))+5 do 
			local phrase = dialogue.create_phrase('phrase '..y,7)
			add(section.phrases,phrase)
		end
	end

	setmetatable(d, {
		__index = function(t, k)
			if k == "section" then
				return t.sections[t.index]
			elseif k == "phrase" then
				return t.section.phrases[t.section.index].text
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

function dialogue.create_phrase(t,c)
    local p = {
        text=t,
        color=c
    }
    return p
end

function dialogue:load_next()
	if self.complete then return end
	add_timer(3, function() gm:event(game_manager.timerevents.timer_fired) end)
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
			print(self.sectiontitle,10,64,7)
			print(self.sectionphrase,10,72,7)
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