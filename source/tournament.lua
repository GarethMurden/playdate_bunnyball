local pd <const> = playdate
local gfx <const> = pd.graphics

import 'characters.lua'

local large_font = gfx.font.new('assets/fonts/large')
local medium_font = gfx.font.new('assets/fonts/medium')
local small_font = gfx.font.new('assets/fonts/small')
local small_white_font = gfx.font.new('assets/fonts/small_white')

local arrow_down = gfx.sprite.new(gfx.image.new('assets/arrow_down'))
local splash_screen_sprite = nil
local match_end_animal_sprite = nil
local outcome_sprite = nil
local score_box_sprite = nil
local rating_sprite = nil
local a_button_sprite = nil
local banner_sprite = nil
local podium_sprite = nil
local unlock_notification_sprite = nil
local opponent_score_sprite = nil
local unlock_notification_queue = {}
local unlock_notification_timers = {}
local notification_active = false
local player_sprite = gfx.sprite.new(CHARACTERS['bunny']['assets']['idle_cpu'])
local opponent_sprites = {
	gfx.sprite.new(CHARACTERS['bunny']['assets']['idle_cpu']),
	gfx.sprite.new(CHARACTERS['bunny']['assets']['idle_cpu'])
}

function clear_tournament_sprites()
	arrow_down:remove()
	for i=1, #unlock_notification_timers do
		unlock_notification_timers[i]:remove()
	end
	unlock_notification_timers = {}
	notification_active = false
	unlock_notification_queue = {}
	-- Tournament intro
	if splash_screen_sprite ~= nil then
		splash_screen_sprite:remove()
		splash_screen_sprite = nil
	end

	-- Match end
	if match_end_animal_sprite ~= nil then
		match_end_animal_sprite:remove()
		match_end_animal_sprite = nil
		outcome_sprite:remove()
		outcome_sprite = nil
		score_box_sprite:remove()
		score_box_sprite = nil
		a_button_sprite:remove()
		a_button_sprite = nil
		rating_sprite:remove()
		rating_sprite = nil
	end

	-- Tournament end
	if banner_sprite ~= nil then
		banner_sprite:remove()
		banner_sprite = nil
		podium_sprite:remove()
		podium_sprite = nil
		player_sprite:remove()
		for i=1, #opponent_sprites do
			opponent_sprites[i]:remove()
		end
		if opponent_score_sprite ~= nil then
			opponent_score_sprite:remove()
			opponent_score_sprite = nil
		end
		if unlock_notification_sprite ~= nil then
			unlock_notification_sprite:remove()
			unlock_notification_sprite = nil
		end
	end
end

function match_end(tournament_name, player_animal, outcome)
	if splash_screen_sprite == nil then
		splash_screen_sprite = gfx.sprite.new(gfx.image.new('assets/backgrounds/pitch_' .. tournament_name))
		splash_screen_sprite:moveTo(
			math.floor( pd.display.getWidth()  / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		splash_screen_sprite:add()

		local background_image = gfx.image.new('assets/match_end/banner')
		gfx.pushContext(background_image)
		gfx.setFont(large_font)
		local text_width, text_height = gfx.getTextSize(outcome)
		gfx.drawText(
			outcome,
			math.floor( 200 - (text_width / 2) ),
			math.floor( 45 - (text_height / 2) )
		)
		outcome_sprite = gfx.sprite.new(background_image)
		outcome_sprite:moveTo(
			math.floor( pd.display.getWidth()  / 2),
			50
		)
		outcome_sprite:add()
		gfx.popContext()

		local background_image = gfx.image.new('assets/match_end/score_box')
		gfx.pushContext(background_image)

		-- remaining health
		gfx.setFont(small_font)
		gfx.drawText(
			STATS['health'],
			50,
			25
		)
		-- accuracy
		gfx.drawText(
			STATS['accuracy'],
			50,
			62
		)
		score_box_sprite = gfx.sprite.new(background_image)
		score_box_sprite:moveTo(
			80,
			150
		)
		score_box_sprite:add()
		gfx.popContext()

		if outcome == 'WIN' then
			match_end_animal_sprite = gfx.sprite.new(CHARACTERS[player_animal]['assets']['idle_cpu'])
		else
			match_end_animal_sprite = gfx.sprite.new(CHARACTERS[player_animal]['assets']['hit_cpu'])
		end
		match_end_animal_sprite:setScale(2)
		match_end_animal_sprite:moveTo(
			260,
			125
		)
		match_end_animal_sprite:add()

		local background_image = gfx.image.new('assets/backgrounds/blank_with_A')
		gfx.pushContext(background_image)
		gfx.setFont(small_white_font)
		local button_text = 'next'
		if outcome ~= 'WIN' then
			button_text = 'main menu'
		end
		local text_width, _ = gfx.getTextSize(button_text)
		gfx.drawText(
			button_text,
			360 - text_width,
			225
		)
		a_button_sprite = gfx.sprite.new(background_image)
		a_button_sprite:moveTo(
			math.floor( pd.display.getWidth()  / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		a_button_sprite:add()
		gfx.popContext()

		pd.timer.performAfterDelay(1500, show_rating)
	end

	if pd.buttonJustPressed(pd.kButtonA) then
		play_sound('menu_select')
		if outcome == 'WIN' then
			return 'tournament_' .. tournament_name
		else
			return 'main_menu'
		end

	else
		if outcome == 'WIN' then
			return 'winner_player'
		else
			return 'winner_opponent'
		end
	end
end

function show_rating()
	-- rating
	local background_image = gfx.image.new('assets/match_end/medal')
	gfx.pushContext(background_image)
	local rating = 'F'
	if STATS['points'] == 100 then
		rating = 'S'
	elseif STATS['points'] >= 90 then
		rating = 'A'
	elseif STATS['points'] >= 80 then
		rating = 'B'
	elseif STATS['points'] >= 70 then
		rating = 'C'
	elseif STATS['points'] >= 60 then
		rating = 'D'
	end
	gfx.setFont(large_font)
	local text_width, _ = gfx.getTextSize(rating)
	gfx.drawText(
		rating,
		143 - math.floor( text_width / 2 ),
		133
	)
	rating_sprite = gfx.sprite.new(background_image)
	rating_sprite:moveTo(
		math.floor( pd.display.getWidth()  / 2),
		math.floor( pd.display.getHeight() / 2)
	)
	rating_sprite:add()
	gfx.popContext()
end

local create_unlock_notification

local function start_next_unlock_notification()
	if #unlock_notification_queue > 0 then
		local next_message = table.remove(unlock_notification_queue, 1)
		create_unlock_notification(next_message)
	else
		notification_active = false
	end
end

local function create_opponent_score_notification(location)
	local opponents = TOURNAMENT_MATCHES[location]
	local image = gfx.image.new('assets/notification/side')
	gfx.pushContext(image)
	gfx.setFont(medium_font)
	for i=1, #opponents do
		local animal = opponents[i]
		local row = i
		local y = 45 + (row - 1) * 50
		gfx.image.new('assets/animals/' .. animal .. '_icon'):draw(221, y - 15)
		local score = math.floor((STATS['opponent_points'] or {})[row] or 0)
		local text = tostring(score)
		local width, height = gfx.getTextSize(text)
		gfx.drawText(text, math.floor(300 - width / 2), math.floor(y - height / 2))
	end
	gfx.drawLine(176, 174, 388, 174)
	gfx.drawLine(176, 180, 388, 180)
	local total = tostring(math.floor(STATS['point_total'] or 0))
	local total_width, total_height = gfx.getTextSize(total)
	gfx.drawText(total, math.floor(300 - total_width / 2), math.floor(202 - total_height / 2))
	gfx.popContext()

	opponent_score_sprite = gfx.sprite.new(image)
	opponent_score_sprite:moveTo(520, 120)
	opponent_score_sprite:setZIndex(1000)
	opponent_score_sprite:add()
	local slide_in = pd.timer.new(300, 520, 200, pd.easingFunctions.inOutCubic)
	table.insert(unlock_notification_timers, slide_in)
	slide_in.updateCallback = function(timer)
		if opponent_score_sprite ~= nil then
			opponent_score_sprite:moveTo(timer.value, 120)
		end
	end
	slide_in.timerEndedCallback = function()
		local hold = pd.timer.performAfterDelay(3800, function()
			if opponent_score_sprite == nil then return end
			local slide_out = pd.timer.new(300, 200, 520, pd.easingFunctions.inOutCubic)
			table.insert(unlock_notification_timers, slide_out)
			slide_out.updateCallback = function(timer)
				if opponent_score_sprite ~= nil then
					opponent_score_sprite:moveTo(timer.value, 120)
				end
			end
			slide_out.timerEndedCallback = function()
				opponent_score_sprite:remove()
				opponent_score_sprite = nil
				local gap = pd.timer.performAfterDelay(250, start_next_unlock_notification)
				table.insert(unlock_notification_timers, gap)
			end
		end)
		table.insert(unlock_notification_timers, hold)
	end
end

create_unlock_notification = function(message)
	local image = gfx.image.new('assets/notification/top')
	gfx.pushContext(image)
	gfx.setFont(small_font)
	local text_width, text_height = gfx.getTextSize(message)
	gfx.drawText(message, math.floor(282.5 - text_width / 2), math.floor(37.5 - text_height / 2))
	gfx.popContext()

	unlock_notification_sprite = gfx.sprite.new(image)
	unlock_notification_sprite:moveTo(200, -120)
	unlock_notification_sprite:setZIndex(1000)
	unlock_notification_sprite:add()
	local slide_in = pd.timer.new(300, -120, 120, pd.easingFunctions.inOutCubic)
	table.insert(unlock_notification_timers, slide_in)
	slide_in.updateCallback = function(timer)
		if unlock_notification_sprite ~= nil then
			unlock_notification_sprite:moveTo(200, timer.value)
		end
	end
	slide_in.timerEndedCallback = function()
		local hold = pd.timer.performAfterDelay(3000, function()
			if unlock_notification_sprite == nil then return end
			local slide_out = pd.timer.new(300, 120, -120, pd.easingFunctions.inOutCubic)
			table.insert(unlock_notification_timers, slide_out)
			slide_out.updateCallback = function(timer)
				if unlock_notification_sprite ~= nil then
					unlock_notification_sprite:moveTo(200, timer.value)
				end
			end
			slide_out.timerEndedCallback = function()
				unlock_notification_sprite:remove()
				unlock_notification_sprite = nil
				local gap = pd.timer.performAfterDelay(500, function()
					if #unlock_notification_queue > 0 then
						local next_message = table.remove(unlock_notification_queue, 1)
						create_unlock_notification(next_message)
					else
						notification_active = false
					end
				end)
				table.insert(unlock_notification_timers, gap)
			end
		end)
		table.insert(unlock_notification_timers, hold)
	end
end

function tournament_end(tournament_name, selected_character, unlock_notifications)
	local location = tournament_name:gsub('tournament_', '')
	if splash_screen_sprite == nil then
		local splash_screen_image = gfx.image.new('assets/backgrounds/pitch_' .. location)
		splash_screen_sprite = gfx.sprite.new(splash_screen_image)
		splash_screen_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		splash_screen_sprite:add()

		local splash_screen_image = gfx.image.new('assets/backgrounds/blank_with_A')
		splash_screen_sprite = gfx.sprite.new(splash_screen_image)
		splash_screen_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		splash_screen_sprite:add()

		podium_sprite = gfx.sprite.new(gfx.image.new('assets/tournament_end/podium'))
		podium_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		podium_sprite:add()

		-- positon animal sprites on podium
		for i=2, #TOURNAMENT_MATCHES[location] do
			local animal = TOURNAMENT_MATCHES[location][i]
			opponent_sprites[i -1]:setImage(CHARACTERS[animal]['assets']['idle_cpu'])
		end
		opponent_sprites[1]:setScale(2)
		opponent_sprites[1]:moveTo(100, 74)
		opponent_sprites[1]:add()
		opponent_sprites[2]:setScale(2)
		opponent_sprites[2]:moveTo(300, 84)
		opponent_sprites[2]:add()

		player_sprite:setImage(CHARACTERS[selected_character]['assets']['idle_cpu'])
		player_sprite:setScale(2)
		player_sprite:moveTo(200, 64)
		player_sprite:add()

		if unlock_notifications ~= nil then
			for i=1, #unlock_notifications do
				table.insert(unlock_notification_queue, unlock_notifications[i])
			end
		end
		if not notification_active then
			notification_active = true
			create_opponent_score_notification(location)
		end

	end
	if pd.buttonJustPressed(pd.kButtonA) then
		play_sound('menu_select')
		clear_tournament_sprites()
		return 'main_menu'
	else
		return 'finished_' .. tournament_name
	end
end

function tournament_intro(tournament_name, opponent_num)
	local location = tournament_name:gsub('tournament_', '')
	local set_timer = false
	if splash_screen_sprite == nil then
		local splash_screen_image = gfx.image.new('assets/backgrounds/' .. tournament_name)
		gfx.pushContext(splash_screen_image)

		gfx.setFont(large_font)
		local text_width, text_height = gfx.getTextSize(location)
		gfx.drawText(
			location,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			168
		)

		gfx.setFont(small_font)
		gfx.drawText(
			'loading...',
			30,
			165
		)

		local intro_messages = {
			house =  {'the pets have',   'gathered for a',  'qualifying round'},
			garden = {"there's stiffer", 'competition in',  'the garden'},
			park =   {'this is it, the', 'best of the best','compete out here'}
		}

		gfx.drawText(
			intro_messages[location][1],
			30,
			30
		)
		gfx.drawText(
			intro_messages[location][2],
			30,
			50
		)
		gfx.drawText(
			intro_messages[location][3],
			30,
			70
		)

						gfx.popContext()

		splash_screen_sprite = gfx.sprite.new(splash_screen_image)

		set_timer = true
	end
	splash_screen_sprite:moveTo(
		math.floor( pd.display.getWidth() / 2),
		math.floor( pd.display.getHeight() / 2)
	)
	splash_screen_sprite:add()

	arrow_down:moveTo(
		280 + (48 * (opponent_num -1)),
		90
	)
	arrow_down:add()
	return set_timer, location
end