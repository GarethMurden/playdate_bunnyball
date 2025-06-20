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
local podium_sprite = nill
local unlock_notification_sprite = nil
local player_sprite = gfx.sprite.new(CHARACTERS['bunny']['assets']['idle_cpu'])
local opponent_sprites = {
	gfx.sprite.new(CHARACTERS['bunny']['assets']['idle_cpu']),
	gfx.sprite.new(CHARACTERS['bunny']['assets']['idle_cpu'])
}

function clear_tournament_sprites()
	arrow_down:remove()
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
	if banner_sprite ~= nill then
		banner_sprite:remove()
		banner_sprite = nil
		podium_sprite:remove()
		podium_sprite = nil
		player_sprite:remove()
		for i=1, #opponent_sprites do
			opponent_sprites[i]:remove()
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

function tournament_end(tournament_name, selected_character, tournament_unlock, character_unlock)
	local location = tournament_name:gsub('tournament_', '')
	if splash_screen_sprite == nil then
		local splash_screen_image = gfx.image.new('assets/backgrounds/pitch_' .. location)
		splash_screen_sprite = gfx.sprite.new(splash_screen_image)
		splash_screen_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		splash_screen_sprite:add()

		local banner_image = gfx.image.new('assets/match_end/banner')
		gfx.pushContext(banner_image)
		gfx.setFont(large_font)
		local text_width, text_height = gfx.getTextSize(math.floor(STATS['point_total']))
		gfx.drawText(
			math.floor(STATS['point_total']),
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			40 - math.floor( text_height / 2 )
		)
		banner_sprite = gfx.sprite.new(banner_image)
		banner_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			195
		)
		banner_sprite:add()
		gfx.popContext()

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

		if tournament_unlock or character_unlock then
			print('show notification')
			local notification_image = gfx.image.new('assets/tournament_end/unlock_notification')
			gfx.pushContext(notification_image)
			gfx.setFont(small_font)
			local text = ''
			if tournament_unlock then
				text = 'TOURNAMENT UNLOCKED'
			else
				text = 'ANIMAL UNLOCKED'
			end
			print(text)
			local text_width, text_height = gfx.getTextSize(text)
			gfx.drawText(
				text,
				math.floor(266 - (text_width / 2)),
				math.floor(24 - (text_height / 2))
			)
			unlock_notification_sprite = gfx.sprite.new(notification_image)
			unlock_notification_sprite:moveTo(
				math.floor( pd.display.getWidth() / 2),
				math.floor( pd.display.getHeight() / 2)
			)
			unlock_notification_sprite:add()
			gfx.popContext()
		end

	end
	if pd.buttonJustPressed(pd.kButtonA) then
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
			163
		)

		-- TODO: Different intro text for each tournament
		gfx.drawText(
			'the pets have',
			30,
			30
		)
		gfx.drawText(
			'gathered for a',
			30,
			50
		)
		gfx.drawText(
			'qualifying round',
			30,
			70
		)

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