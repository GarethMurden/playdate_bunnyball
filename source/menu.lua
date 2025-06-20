local pd <const> = playdate
local gfx <const> = pd.graphics

import 'characters.lua'

local large_font = gfx.font.new('assets/fonts/large')
local medium_font = gfx.font.new('assets/fonts/medium')
local small_white_font = gfx.font.new('assets/fonts/small_white')
local small_font = gfx.font.new('assets/fonts/small')
local tiny_font = gfx.font.new('assets/fonts/tiny')

local background_sprite = nil
local arrow_right = gfx.sprite.new(gfx.image.new('assets/arrow_right'))
local arrow_down = gfx.sprite.new(gfx.image.new('assets/arrow_down'))
local locked_tournament_01 = nil
local locked_tournament_02 = nil
local highlighted_option = 1
local highlighted_2d_option = {1, 1}
local character_sprite = gfx.sprite.new()

local statbars = {
	[0] = gfx.image.new('assets/bar/0'),
	[1] = gfx.image.new('assets/bar/1'),
	[2] = gfx.image.new('assets/bar/2'),
	[3] = gfx.image.new('assets/bar/3'),
	[4] = gfx.image.new('assets/bar/4'),
	[5] = gfx.image.new('assets/bar/5'),
	[6] = gfx.image.new('assets/bar/6')
}
local stat_hp_sprite = gfx.sprite.new(statbars[1])
local stat_spd_sprite = gfx.sprite.new(statbars[1])
local stat_str_sprite = gfx.sprite.new(statbars[1])

local padlock_icon = gfx.image.new('assets/padlock_small')
local animal_icon_sprites = {
	gfx.sprite.new(padlock_icon),
	gfx.sprite.new(padlock_icon),
	gfx.sprite.new(padlock_icon),
	gfx.sprite.new(padlock_icon),
	gfx.sprite.new(padlock_icon),
	gfx.sprite.new(padlock_icon),
	gfx.sprite.new(padlock_icon),
	gfx.sprite.new(padlock_icon),
	gfx.sprite.new(padlock_icon)
}

function credits()
	if background_sprite == nil then
		local background_image = gfx.image.new('assets/backgrounds/blank')
		gfx.pushContext(background_image)


		gfx.setFont(medium_font)
		local text = 'a game by PangolinPaw'
		local text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			25
		)
		local text = 'art by KuroganeNiello'
		local text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			55
		)
		local text = 'and music from Dedediego'
		local text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			85
		)
		local text = 'with special thanks to'
		local text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			140
		)
		local text = 'Toad and PizzaDev'
		local text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			170
		)
		local text = 'from the PlaydateSquad'
		local text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			200
		)

		gfx.popContext()

		background_sprite = gfx.sprite.new(background_image)
		background_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			math.floor( pd.display.getHeight() / 2)
		)
	end

	background_sprite:add()

	if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
		background_sprite:remove()
		background_sprite = nil
		return 'main_menu' -- next scene
	else
		return 'credits' -- next scene
	end
end

function in_table(needle, haystack)
	for index, value in ipairs(haystack) do
		if value == needle then
			return true
		end
	end
end

function main_menu()
	if background_sprite == nil then
		local background_image = gfx.image.new('assets/backgrounds/main_menu')
		gfx.pushContext(background_image)

		gfx.setFont(large_font)
		local text = 'BUNNYBALL'
		local text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			27
		)

		gfx.setFont(medium_font)
		gfx.drawText(
			'TOURNAMENT',
			50,
			110
		)
		gfx.drawText(
			'SCORES',
			50,
			140
		)
		gfx.drawText(
			'CREDITS',
			50,
			170
		)

		gfx.setFont(small_white_font)
		local text = '2023                    PangolinPaw                    v' .. VERSION
		local text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			230
		)

		gfx.popContext()

		background_sprite = gfx.sprite.new(background_image)
		background_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			math.floor( pd.display.getHeight() / 2)
		)
	end

	background_sprite:add()

	local options = {
		{
			name = 'tournament_selection',
			position = {25, 120}
		},
		{
			name = 'scores',
			position = {25, 150}
		},
		{
			name = 'credits',
			position = {25, 180}
		}
	}

	arrow_right:moveTo(
		options[highlighted_option]['position'][1],
		options[highlighted_option]['position'][2]
	)
	arrow_right:add()

	local next_scene = 'main_menu'
	if pd.buttonJustPressed(pd.kButtonDown) then
		highlighted_option += 1
		if highlighted_option > #options then
			highlighted_option = 1
		end
	elseif pd.buttonJustPressed(pd.kButtonUp) then
		highlighted_option -= 1
		if highlighted_option < 1 then
			highlighted_option = #options
		end
	elseif pd.buttonJustPressed(pd.kButtonA) then
		arrow_right:remove()
		background_sprite:remove()
		background_sprite = nil
		next_scene = options[highlighted_option]['name']
	end
	return next_scene
end

function select_character(tournament_name, unlocked_characters)
	local options = {
		{
			{
				name='bunny',
				position = { 55,  25}
			},
			{
				name = 'hamster',
				position = {100,  25}
			},
			{
				name = 'bird',
				position = {145,  25}
			}
		},
		{
			{
				name='rat',
				position = { 80,  65}
			},
			{
				name = 	'cat',
				position = {125, 65}
			},
			{
				name = 'ferret',
				position = {175, 65}
			}
		},
		{
			{
				name='snake',
				position = { 60, 105}
			},
			{
				name = 'bugs',
				position = {105, 105}
			},
			{
				name = 'tortoise',
				position = {150, 105}
			}
		}
	}

	local highlighted_character_name = options[highlighted_2d_option[1]][highlighted_2d_option[2]]['name']

	local background_image = gfx.image.new('assets/backgrounds/character_selection')
	gfx.pushContext(background_image)

	gfx.setFont(small_font)
	local text = 'HP'
	local text_width, _ = gfx.getTextSize(text)
	gfx.drawText(
		text,
		250 - text_width,
		150
	)

	local text = 'STR'
	local text_width, _ = gfx.getTextSize(text)
	gfx.drawText(
		text,
		250 - text_width,
		180
	)

	local text = 'SPD'
	local text_width, _ = gfx.getTextSize(text)
	gfx.drawText(
		text,
		250 - text_width,
		210
	)

	gfx.setFont(medium_font)
	local text = '???'
	if in_table(highlighted_character_name, unlocked_characters) then
		text = highlighted_character_name
	end
	local text_width, _ = gfx.getTextSize(text)
	gfx.drawText(
		text,
		math.floor( 100 - (text_width / 2) ),
		185
	)

	gfx.popContext()

	background_sprite = gfx.sprite.new(background_image)
	background_sprite:moveTo(
		math.floor( pd.display.getWidth() / 2),
		math.floor( pd.display.getHeight() / 2)
	)
	background_sprite:add()

	local icon_positions = {
		{ 53,  63}, {102,  63}, {148,  63},
		{ 80, 104}, {128, 104}, {173, 104},
		{ 57, 142}, {105, 142}, {151, 142}
	}
	for i=1, #ANIMALS do
		if in_table(ANIMALS[i], unlocked_characters) then
			animal_icon_sprites[i]:setImage(CHARACTERS[ANIMALS[i]]['assets']['icon'])
		else
			animal_icon_sprites[i]:setImage(padlock_icon)
		end
		animal_icon_sprites[i]:moveTo(
			icon_positions[i][1],
			icon_positions[i][2]
		)
		animal_icon_sprites[i]:setZIndex(5)
		animal_icon_sprites[i]:add()
	end


	if not(in_table(highlighted_character_name, unlocked_characters)) then
		highlighted_character_name = 'unknown'
	end
		-- blank image when highlighting a locked character
		character_sprite:setImage(CHARACTERS[highlighted_character_name]['assets']['idle_cpu'])

	character_sprite:setScale(2)
	character_sprite:moveTo(
		305,
		90
	)
	character_sprite:setZIndex(10)
	character_sprite:add()

	stat_hp_sprite:setImage(statbars[CHARACTERS[highlighted_character_name]['health']])
	stat_hp_sprite:moveTo(
		305,
		155
	)
	stat_hp_sprite:setZIndex(15)
	stat_hp_sprite:add()

	stat_str_sprite:setImage(statbars[CHARACTERS[highlighted_character_name]['strength']])
	stat_str_sprite:moveTo(
		305,
		185
	)
	stat_str_sprite:setZIndex(15)
	stat_str_sprite:add()

	stat_spd_sprite:setImage(statbars[CHARACTERS[highlighted_character_name]['speed']])
	stat_spd_sprite:moveTo(
		305,
		215
	)
	stat_spd_sprite:setZIndex(15)
	stat_spd_sprite:add()

	arrow_down:moveTo(
		options[highlighted_2d_option[1]][highlighted_2d_option[2]]['position'][1],
		options[highlighted_2d_option[1]][highlighted_2d_option[2]]['position'][2]
		
	)
	arrow_down:setZIndex(10)
	arrow_down:add()

	local selected_character = nil
	local next_scene = 'character_selection'

	if pd.buttonJustPressed(pd.kButtonDown) then
		highlighted_2d_option[1] += 1
		if highlighted_2d_option[1] > 3 then
			highlighted_2d_option[1] = 1
		end

	elseif pd.buttonJustPressed(pd.kButtonUp) then
		highlighted_2d_option[1] -= 1
		if highlighted_2d_option[1] < 1 then
			highlighted_2d_option[1] = 3
		end

	elseif pd.buttonJustPressed(pd.kButtonRight) then
		highlighted_2d_option[2] += 1
		if highlighted_2d_option[2] > 3 then
			highlighted_2d_option[2] = 1
		end

	elseif pd.buttonJustPressed(pd.kButtonLeft) then
		highlighted_2d_option[2] -= 1
		if highlighted_2d_option[2] < 1 then
			highlighted_2d_option[2] = 3
		end

	elseif pd.buttonJustPressed(pd.kButtonA) then
		background_sprite:remove()
		background_sprite = nil
		arrow_down:remove()
		character_sprite:remove()
		stat_hp_sprite:remove()
		stat_spd_sprite:remove()
		stat_str_sprite:remove()
		for i=1, #animal_icon_sprites do
			animal_icon_sprites[i]:remove()
		end
		selected_character = options[highlighted_2d_option[1]][highlighted_2d_option[2]]['name']
		next_scene = tournament_name
	end

	return next_scene, selected_character

end

function select_tournament(unlocked_tournaments)
	if background_sprite == nil then
		local background_image = gfx.image.new('assets/backgrounds/tournament_selection_0' .. unlocked_tournaments)
		gfx.pushContext(background_image)

		gfx.setFont(medium_font)
		local text = 'SELECT TOURNAMENT'
		local text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			27
		)

		gfx.setFont(tiny_font)
		local text = 'house'
		local text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			80 - math.floor( text_width / 2),
			200
		)

		if unlocked_tournaments >= 2 then
			local text = 'garden'
			local text_width, _ = gfx.getTextSize(text)
			gfx.drawText(
				text,
				200 - math.floor( text_width / 2),
				200
			)
		end

		if unlocked_tournaments >= 3 then
			local text = 'park'
			local text_width, _ = gfx.getTextSize(text)
			gfx.drawText(
				text,
				320 - math.floor( text_width / 2),
				200
			)
		end
		
		gfx.popContext()

		background_sprite = gfx.sprite.new(background_image)
		background_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			math.floor( pd.display.getHeight() / 2)
		)
	end

	background_sprite:add()

	if unlocked_tournaments < 2 and locked_tournament_01 == nil then
		locked_tournament_01 = gfx.sprite.new(gfx.image.new('assets/padlock'))
		locked_tournament_01:moveTo(
			201,
			136
		)
		locked_tournament_01:setZIndex(10)
		locked_tournament_01:add()

	end

	if unlocked_tournaments < 3 and locked_tournament_02 == nil then
		locked_tournament_02 = gfx.sprite.new(gfx.image.new('assets/padlock'))
		locked_tournament_02:moveTo(
			325,
			136
		)
		locked_tournament_02:setZIndex(10)
		locked_tournament_02:add()
	end

	local options = {
		{
			name = 'tournament_house',
			position = {80, 75}
		},
		{
			name = 'tournament_garden',
			position = {202, 75}
		},
		{
			name = 'tournament_park',
			position = {325, 75}
		}
	}

	arrow_down:moveTo(
		options[highlighted_option]['position'][1],
		options[highlighted_option]['position'][2]
	)
	arrow_down:add()

	local next_scene = 'tournament_selection'

	if pd.buttonJustPressed(pd.kButtonRight) then
		highlighted_option += 1
		if highlighted_option > #options then
			highlighted_option = 1
		end
	elseif pd.buttonJustPressed(pd.kButtonLeft) then
		highlighted_option -= 1
		if highlighted_option < 1 then
			highlighted_option = #options
		end
	elseif pd.buttonJustPressed(pd.kButtonA) then
		if highlighted_option <= unlocked_tournaments then
			arrow_down:remove()
			background_sprite:remove()
			background_sprite = nil
			if locked_tournament_01 ~= nil then
				locked_tournament_01:remove()
				locked_tournament_01 = nil
			end
			if locked_tournament_02 ~= nil then
				locked_tournament_02:remove()
				locked_tournament_02 = nil
			end
			next_scene = 'character_selection'
		end
	elseif pd.buttonJustPressed(pd.kButtonB) then
		arrow_down:remove()
		background_sprite:remove()
		background_sprite = nil
		if locked_tournament_01 ~= nil then
			locked_tournament_01:remove()
			locked_tournament_01 = nil
		end
		if locked_tournament_02 ~= nil then
			locked_tournament_02:remove()
			locked_tournament_02 = nil
		end
		next_scene = 'main_menu'
	end
	return next_scene, options[highlighted_option]['name']
end