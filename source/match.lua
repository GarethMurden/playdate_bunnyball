local pd <const> = playdate
local gfx <const> = pd.graphics

import 'characters.lua'

math.randomseed(pd.getSecondsSinceEpoch())

local large_font = gfx.font.new('assets/fonts/large')

local match_in_progress = false
local current_tournament = nil
local opponent = nil
local player = nil
local top_of_field = 95
local right_of_field = 365
local bottom_of_field = 185
local left_of_field = 35
local player_carrying = nil
local opponent_carrying = nil
local opponent_health = nil
local player_health = nil
local player_stunned = false
local opponent_stunned = false
local opponent_destination = left_of_field
local match_ended = false
local cleanup_done = false
local player_step = 1
local opponent_step = 1

local countdown_sprite = nil
local background_sprite = nil
local pitch_sprite = nil
local opponent_sprite = nil
local opponent_health_sprites = {
	gfx.sprite.new(gfx.image.new('assets/health/cpu_heart'))
}
local player_sprite = nil
local player_health_sprites = {
	gfx.sprite.new(gfx.image.new('assets/health/player_heart'))
}
local ball_sprites = {
	gfx.sprite.new(gfx.image.new('assets/ball')),
	gfx.sprite.new(gfx.image.new('assets/ball')),
	gfx.sprite.new(gfx.image.new('assets/ball')),
	gfx.sprite.new(gfx.image.new('assets/ball')),
	gfx.sprite.new(gfx.image.new('assets/ball')),
	gfx.sprite.new(gfx.image.new('assets/ball')),
	gfx.sprite.new(gfx.image.new('assets/ball')),
	gfx.sprite.new(gfx.image.new('assets/ball')),
	gfx.sprite.new(gfx.image.new('assets/ball')),
	gfx.sprite.new(gfx.image.new('assets/ball'))
}
local ball_movement_timers = {
	pd.timer.new(1000, 1, 10),
	pd.timer.new(1000, 1, 10),
	pd.timer.new(1000, 1, 10),
	pd.timer.new(1000, 1, 10),
	pd.timer.new(1000, 1, 10),
	pd.timer.new(1000, 1, 10),
	pd.timer.new(1000, 1, 10),
	pd.timer.new(1000, 1, 10),
	pd.timer.new(1000, 1, 10),
	pd.timer.new(1000, 1, 10)
}

function ball_move()
	for i=1, #ball_movement_timers do
		if ball_movement_timers[i].value ~= ball_movement_timers[i].endValue then
			ball_sprites[i]:moveTo(
				ball_sprites[i].x,
				ball_movement_timers[i].value
			)
			if not ball_sprites[i]:collisionsEnabled() then
				ball_sprites[i]:setCollisionsEnabled(true)
			end 
		else
			-- Ball has reached other side, disable collisions
			if ball_sprites[i]:collisionsEnabled() then
				ball_sprites[i]:setCollisionsEnabled(false)
			end
		end 
	end -- /for i=1, #ball_movement_timers
end

function countdown(number)
	if countdown_sprite == nil then
		countdown_sprite = gfx.sprite.new()
	end
	
	countdown_sprite:remove()

	if number ~= nil then
		local background_image = gfx.image.new('assets/backgrounds/blank')
		gfx.pushContext(background_image)

		gfx.setFont(large_font)
		local text_width, text_height = gfx.getTextSize(number)
		gfx.drawText(
			number,
			math.floor( (pd.display.getWidth()  / 2) - (text_width / 2) ),
			math.floor( (pd.display.getHeight() / 2) - (text_height / 2) ) + 20
		)

		countdown_sprite:setImage(background_image)
		countdown_sprite:moveTo(
			math.floor( pd.display.getWidth()  / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		countdown_sprite:add()
		gfx.popContext()
	else
		match_in_progress = true
	end
end

function match_loop()
	-- Player actions
	if #player_sprite:overlappingSprites() > 0 then
		player_hit()
	end
	if not player_stunned then
		player_move(player_carrying)
		
		if pd.buttonJustPressed(pd.kButtonA) then
			if player_carrying then
				player_throw(player_carrying)
				player_carrying = nil
			else
				player_carrying = player_pickup()
			end
		end
	end

	-- Opponent actions
	if #opponent_sprite:overlappingSprites() > 0 then
		opponent_hit()
	end
	if not opponent_stunned then
		if current_tournament == 'house' then
			opponent_act_easy()
		elseif current_tournament == 'garden' then
			opponent_act_medium()
		else
			opponent_act_hard()
		end
	end

	-- Ball movement
	ball_move()

	-- Check for winner
	if #player_health_sprites < 1 then
		return 'opponent'
	elseif #opponent_health_sprites < 1 then
		return 'player'
	else
		return nil
	end
end

function opponent_enable_collisions()
	opponent_sprite:setCollisionsEnabled(true)
end

function distance(start_x, end_x)
	return math.abs(start_x - end_x)
end

function initialise()
	STATS['throws'] 	= 0
	STATS['hits'] 		= 0
	STATS['accuracy'] 	= 0
	STATS['health'] 	= 0
	STATS['points'] 	= 0

	match_in_progress = false
	current_tournament = nil
	opponent = nil
	player = nil
	top_of_field = 95
	right_of_field = 365
	bottom_of_field = 185
	left_of_field = 35
	player_carrying = nil
	opponent_carrying = nil
	opponent_health = nil
	player_health = nil
	player_stunned = false
	opponent_stunned = false
	opponent_destination = left_of_field
	match_ended = false
	cleanup_done = false
	player_step = 1

	countdown_sprite = nil
	background_sprite = nil
	pitch_sprite = nil
	opponent_sprite = nil
	opponent_health_sprites = {
		gfx.sprite.new(gfx.image.new('assets/health/cpu_heart'))
	}
	player_sprite = nil
	player_health_sprites = {
		gfx.sprite.new(gfx.image.new('assets/health/player_heart'))
	}
	ball_sprites = {
		gfx.sprite.new(gfx.image.new('assets/ball')),
		gfx.sprite.new(gfx.image.new('assets/ball')),
		gfx.sprite.new(gfx.image.new('assets/ball')),
		gfx.sprite.new(gfx.image.new('assets/ball')),
		gfx.sprite.new(gfx.image.new('assets/ball')),
		gfx.sprite.new(gfx.image.new('assets/ball')),
		gfx.sprite.new(gfx.image.new('assets/ball')),
		gfx.sprite.new(gfx.image.new('assets/ball')),
		gfx.sprite.new(gfx.image.new('assets/ball')),
		gfx.sprite.new(gfx.image.new('assets/ball'))
	}
	ball_movement_timers = {
		pd.timer.new(1000, 1, 10),
		pd.timer.new(1000, 1, 10),
		pd.timer.new(1000, 1, 10),
		pd.timer.new(1000, 1, 10),
		pd.timer.new(1000, 1, 10),
		pd.timer.new(1000, 1, 10),
		pd.timer.new(1000, 1, 10),
		pd.timer.new(1000, 1, 10),
		pd.timer.new(1000, 1, 10),
		pd.timer.new(1000, 1, 10)
	}
end

function opponent_act_easy()
	local destination = nil
	if opponent_carrying then
		opponent_move(player_sprite.x)
		opponent_throw()

	else
		local nearest_ball = nil
		local nearest_ball_distance = 800
		for i=1, #ball_sprites do
			if distance(ball_sprites[i].y, top_of_field) < 3 then
				if nearest_ball == nil then
					nearest_ball = i
				else
					local ball_distance = distance(
						ball_sprites[nearest_ball].x,
						opponent_sprite.x 
					)
					if ball_distance < nearest_ball_distance then
						nearest_ball_distance = ball_distance
						nearest_ball = i
					end
				end
			end
		end -- /for
		if nearest_ball == nil then
			if distance(opponent_destination, opponent_sprite.x) < CHARACTERS[opponent]['speed'] then
				opponent_destination = math.random(right_of_field)
				if opponent_destination < left_of_field then
					opponent_destination = left_of_field
				end
			end
			opponent_move(opponent_destination)
		else
			opponent_move(ball_sprites[nearest_ball].x)
			opponent_pickup()
		end
	end -- /opponent_carrying
end

function opponent_throw()
	if distance(opponent_sprite.x, player_sprite.x) < opponent_sprite.width / 4 then
		ball_movement_timers[opponent_carrying] = pd.timer.new(
			6000 / CHARACTERS[opponent]['strength'],-- duration
			top_of_field + ball_sprites[opponent_carrying].height,	-- start
			bottom_of_field,				-- end
			pd.easingFunctions.outBack 	-- easing function
		)
		opponent_carrying = nil
	end
end

function opponent_move(destination)
	if destination > opponent_sprite.x then
		opponent_step += 1
		if opponent_step > #CHARACTERS[opponent]['assets']['run_sequence'] then
			opponent_step = 1
		end
		opponent_sprite:setImage(
			CHARACTERS[opponent]['assets']['run_sequence'][opponent_step],
			'flipX'
		)
		opponent_sprite:moveTo(
			opponent_sprite.x + CHARACTERS[opponent]['speed'],
			opponent_sprite.y
		)
		if opponent_carrying ~= nil then
			ball_sprites[opponent_carrying]:moveTo(
				opponent_sprite.x - CHARACTERS[opponent]['carry_position'][1],
				opponent_sprite.y + CHARACTERS[opponent]['carry_position'][2]
			)
		end
	else
		opponent_step -= 1
		if opponent_step == 0 then
			opponent_step = #CHARACTERS[opponent]['assets']['run_sequence']
		end
		opponent_sprite:setImage(
			CHARACTERS[opponent]['assets']['run_sequence'][opponent_step]
		)
		opponent_sprite:moveTo(
			opponent_sprite.x - CHARACTERS[opponent]['speed'],
			opponent_sprite.y
		)
		if opponent_carrying ~= nil then
			ball_sprites[opponent_carrying]:moveTo(
				opponent_sprite.x + CHARACTERS[opponent]['carry_position'][1],
				opponent_sprite.y + CHARACTERS[opponent]['carry_position'][2]
			)
		end
	end
end

function opponent_pickup()
	local reach = {
		opponent_sprite.x - math.floor(opponent_sprite.width / 2),
		opponent_sprite.x + math.floor(opponent_sprite.width / 2)
	}
	for i=1, #ball_sprites do
		if distance(ball_sprites[i].y, top_of_field) < 3 then
			if ball_sprites[i].x >= reach[1] and ball_sprites[i].x <= reach[2] then
				ball_sprites[i]:moveTo(
					opponent_sprite.x - CHARACTERS[opponent]['carry_position'][1],
					opponent_sprite.y + CHARACTERS[opponent]['carry_position'][2]
				)
				opponent_carrying = i
			end -- /ball_sprites[i].x >= reach...
		end -- /ball_sprites[i].y == bottom_of_field
	end -- /for i=1, #ball_sprites
end

function opponent_act_medium()
	local balls_available = {}
	for i=1, #ball_sprites do
		if distance(ball_sprites[i].y, top_of_field) < 3 then
			table.insert(balls_available, i)
		end
	end
	if opponent_carrying then
		-- print('Carrying')
		if #balls_available >= 4 then
			-- print('5+ balls available')
			-- print('Move to player')
			opponent_destination = player_sprite.x
			opponent_move(opponent_destination)
			opponent_throw()
		else
			-- print('< 5 balls available')
			-- print('Move at random')
			if distance(opponent_destination, opponent_sprite.x) < CHARACTERS[opponent]['speed'] then
				opponent_destination = math.random(right_of_field)
				if opponent_destination < left_of_field then
					opponent_destination = left_of_field
				end
			end
			opponent_move(opponent_destination)
		end

	else
		-- print('Not carrying')
		if #balls_available > 0 then
			-- print('Ball available')
			local nearest_ball = balls_available[1]
			local nearest_ball_distance = 800
			for i=1, #balls_available do
				local ball_distance = distance(ball_sprites[balls_available[i]].x, opponent_sprite.x)
				if ball_distance < nearest_ball_distance then
					nearest_ball_distance = ball_distance
					nearest_ball = balls_available[i]
				end
			end
			-- print('Move to nearest ball')
			opponent_destination = ball_sprites[nearest_ball].x
			opponent_move(opponent_destination)
			opponent_pickup()
		else
			-- print('No ball available')
			-- print('Move at random')
			if distance(opponent_destination, opponent_sprite.x) < CHARACTERS[opponent]['speed'] then
				opponent_destination = math.random(right_of_field)
				if opponent_destination < left_of_field then
					opponent_destination = left_of_field
				end
			end
			opponent_move(opponent_destination)
		end
	end
end

function opponent_act_hard()
	local balls_on_left = {}
	local balls_on_right = {}
	for i=1, #ball_sprites do
		if distance(ball_sprites[i].y, top_of_field) < 3 then
			if ball_sprites[i].x > (pd.display.getWidth() / 2) then
				table.insert(balls_on_right, i)
			else
				table.insert(balls_on_left, i)
			end

		end
	end

	if opponent_carrying then
		-- Carrying
		if #balls_on_left + #balls_on_right >= 5 then
			-- Balls available
			if distance(player_sprite.x, opponent_sprite.x) < 100 then
				-- print('Player nearby')
				opponent_move(player_sprite.x)
				opponent_throw()
			else
				-- Player not nearby
				if distance(opponent_destination, opponent_sprite.x) < CHARACTERS[opponent]['speed'] then
					-- print('Move away from player')
					if player_sprite.x > (pd.display.getWidth() / 2) then 
						opponent_destination = math.random((pd.display.getWidth() / 2))
						if opponent_destination < left_of_field then
							opponent_destination = left_of_field
						end
					elseif player_sprite.x < (pd.display.getWidth() / 2) then
						opponent_destination = math.random(right_of_field)
						if opponent_destination < (pd.display.getWidth() / 2) then
							opponent_destination = right_of_field
						end
					end
				end
				opponent_move(opponent_destination)
			end

		else
			-- Too few balls available
			-- print('No balls, move away from player')
			if distance(opponent_destination, opponent_sprite.x) < CHARACTERS[opponent]['speed'] then
				-- print('Move away from player')
				if player_sprite.x > (pd.display.getWidth() / 2) then 
					opponent_destination = math.random((pd.display.getWidth() / 2))
					if opponent_destination < left_of_field then
						opponent_destination = left_of_field
					end
				elseif player_sprite.x < (pd.display.getWidth() / 2) then
					opponent_destination = math.random(right_of_field)
					if opponent_destination < (pd.display.getWidth() / 2) then
						opponent_destination = right_of_field
					end
				end
			end
			opponent_move(opponent_destination)
		end
	else
		-- Not carrying
		-- Move to side with most balls & pick one up
		local balls_available = {}
		if #balls_on_left > #balls_on_right then
			balls_available = balls_on_left
		else
			balls_available = balls_on_right
		end
		if #balls_available > 0 then
			local nearest_ball = balls_available[1]
			local nearest_ball_distance = 800
			for i=1, #balls_available do
				local ball_distance = distance(ball_sprites[balls_available[i]].x, opponent_sprite.x)
				if ball_distance < nearest_ball_distance then
					nearest_ball_distance = ball_distance
					nearest_ball = balls_available[i]
				end
			end
			opponent_destination = ball_sprites[nearest_ball].x
			opponent_move(opponent_destination)
			opponent_pickup()
		else
			-- no ball to chase, so wander like the other difficulties do
			if distance(opponent_destination, opponent_sprite.x) < CHARACTERS[opponent]['speed'] then
				opponent_destination = math.random(right_of_field)
				if opponent_destination < left_of_field then
					opponent_destination = left_of_field
				end
			end
			opponent_move(opponent_destination)
		end
	end
end

function opponent_hit()
	STATS['hits'] += 1
	opponent_stunned = true
	opponent_sprite:setCollisionsEnabled(false)
	opponent_sprite:setImage(
		CHARACTERS[opponent]['assets']['hit_cpu']
	)
	opponent_health_sprites[#opponent_health_sprites]:remove()
	table.remove(
		opponent_health_sprites,
		#opponent_health_sprites
	)
	pd.timer.new(1500, opponent_release_stun)
end

function opponent_release_stun()
	opponent_stunned = false
	opponent_sprite:setImage(
		CHARACTERS[opponent]['assets']['idle_cpu']
	)
	pd.timer.new(1500, opponent_enable_collisions)
end

function player_enable_collisions()
	player_sprite:setCollisionsEnabled(true)
end

function player_hit()
	player_stunned = true
	player_sprite:setCollisionsEnabled(false)
	player_sprite:setImage(
		CHARACTERS[player]['assets']['hit_player']
	)
	player_health_sprites[#player_health_sprites]:remove()
	table.remove(
		player_health_sprites,
		#player_health_sprites
	)
	pd.timer.new(1500, player_release_stun)
end

function player_move(carrying)
	if pd.buttonIsPressed(pd.kButtonLeft) then
		player_step -= 1
		if player_step < 1 then
			player_step = #CHARACTERS[player]['assets']['run_sequence']
		end
		player_sprite:setImage(
			CHARACTERS[player]['assets']['run_sequence'][player_step]
		)
		
		if (player_sprite.x - CHARACTERS[player]['speed']) < left_of_field then
			player_sprite:moveTo(
				left_of_field,
				player_sprite.y
			)
		else
			player_sprite:moveTo(
				player_sprite.x -= CHARACTERS[player]['speed'],
				player_sprite.y
			)
		end
		if carrying ~= nil then
			ball_sprites[carrying]:moveTo(
				player_sprite.x - CHARACTERS[player]['carry_position'][1],
				player_sprite.y + CHARACTERS[player]['carry_position'][2]
			)
		end

	elseif pd.buttonIsPressed(pd.kButtonRight) then
		player_step += 1
		if player_step > #CHARACTERS[player]['assets']['run_sequence'] then
			player_step = 1
		end
		player_sprite:setImage(
			CHARACTERS[player]['assets']['run_sequence'][player_step],
			'flipX'
		)
		if (player_sprite.x + CHARACTERS[player]['speed']) > right_of_field then
			player_sprite:moveTo(
				right_of_field,
				player_sprite.y
			)
		else
			player_sprite:moveTo(
				player_sprite.x += CHARACTERS[player]['speed'],
				player_sprite.y
			)
		end
		if carrying ~= nil then
			ball_sprites[carrying]:moveTo(
				player_sprite.x + CHARACTERS[player]['carry_position'][1],
				player_sprite.y + CHARACTERS[player]['carry_position'][2]
			)
		end

	else
		if player_sprite.x < pd.display.getWidth() / 2 then
			player_sprite:setImage(
				CHARACTERS[player]['assets']['idle_player'],
				'flipX'
			)
		else
			player_sprite:setImage(
				CHARACTERS[player]['assets']['idle_player']
			)
		end
	end

	-- TODO: handle tortoise's different CPU & player run frames
end

function player_pickup()
	local reach = {
		player_sprite.x - math.floor(player_sprite.width / 2),
		player_sprite.x + math.floor(player_sprite.width / 2)
	}
	for i=1, #ball_sprites do
		if distance(ball_sprites[i].y, bottom_of_field) < 3 then
			if ball_sprites[i].x >= reach[1] and ball_sprites[i].x <= reach[2] then
				ball_sprites[i]:moveTo(
					player_sprite.x - CHARACTERS[player]['carry_position'][1],
					player_sprite.y + CHARACTERS[player]['carry_position'][2]
				)
				return i
			end -- /ball_sprites[i].x >= reach...
		end -- /ball_sprites[i].y == bottom_of_field
	end -- /for i=1, #ball_sprites
end

function player_release_stun()
	player_stunned = false
	player_sprite:setImage(
		CHARACTERS[player]['assets']['idle_player']
	)
	pd.timer.new(1500, player_enable_collisions)
end

function player_throw(carrying)
	STATS['throws'] += 1
	ball_movement_timers[carrying] = pd.timer.new(
		6000 / CHARACTERS[player]['strength'],-- duration
		player_sprite.y - (player_sprite.height - CHARACTERS[player]['hitbox'][2]),	-- start
		top_of_field,				-- end
		pd.easingFunctions.outBack 	-- easing function
	)
end

function play_match(tourament_name, opponent_num, selected_character)
	if tourament_name ~= nil then
		initialise()

		current_tournament = tourament_name
		opponent = TOURNAMENT_MATCHES[current_tournament][opponent_num]
		player = selected_character

		local background_image = gfx.image.new('assets/backgrounds/pitch_' .. tourament_name)
		background_sprite = gfx.sprite.new(background_image)
		background_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		background_sprite:add()

		opponent_sprite = gfx.sprite.new(CHARACTERS[opponent]['assets']['idle_cpu'])
		opponent_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			70
		)
		opponent_sprite:setCollideRect(
			CHARACTERS[opponent]['hitbox'][1] / 2,
			CHARACTERS[opponent]['hitbox'][2],
			opponent_sprite.width - CHARACTERS[opponent]['hitbox'][1], 
			opponent_sprite.height - CHARACTERS[opponent]['hitbox'][2]
		)
		opponent_sprite:add()

		local pitch_image = gfx.image.new('assets/backgrounds/pitch')
		pitch_sprite = gfx.sprite.new(pitch_image)
		pitch_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		pitch_sprite:add()

		-- Health bars
		if #player_health_sprites < 1 then
			local player_health_sprites = {
				gfx.sprite.new(gfx.image.new('assets/health/player_heart'))
			}
		end
		player_health_sprites[1]:moveTo(
			380,
			215
		)
		player_health_sprites[1]:add()
		local horizontal_position = 376
		for i=1, CHARACTERS[player]['health'] do
			horizontal_position -= 13
			local health_block = gfx.sprite.new(gfx.image.new('assets/health/block'))
			health_block:moveTo(
				horizontal_position,
				215
			)
			health_block:add()
			table.insert(
				player_health_sprites,
				health_block
			)
		end

		if #opponent_health_sprites < 1 then
			opponent_health_sprites = {
				gfx.sprite.new(gfx.image.new('assets/health/cpu_heart'))
			}
		end
		opponent_health_sprites[1]:moveTo(
			25,
			20
		)
		opponent_health_sprites[1]:add()
		local horizontal_position = 42
		for i=1, CHARACTERS[opponent]['health'] do
			local health_block = gfx.sprite.new(gfx.image.new('assets/health/block'))
			health_block:moveTo(
				horizontal_position,
				20
			)
			health_block:add()
			table.insert(
				opponent_health_sprites,
				health_block
			)
			horizontal_position += 13
		end

		local ball_start_positions = {
			{ 45, bottom_of_field},
			{ 65, bottom_of_field},
			{ 85, bottom_of_field},
			{105, bottom_of_field},
			{125, bottom_of_field},
			{260, top_of_field},
			{280, top_of_field},
			{300, top_of_field},
			{320, top_of_field},
			{340, top_of_field}
		}
		for i=1, #ball_sprites do
			ball_sprites[i]:moveTo(
				ball_start_positions[i][1],
				ball_start_positions[i][2]
			)
			ball_sprites[i]:setCollideRect(
				2,
				2,
				ball_sprites[i].width - 4, 
				ball_sprites[i].height - 4
			)
			ball_sprites[i]:add()
		end

		player_sprite = gfx.sprite.new(CHARACTERS[player]['assets']['idle_player'])
		player_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			170
		)
		player_sprite:setCollideRect(
			CHARACTERS[player]['hitbox'][1] / 2,
			CHARACTERS[player]['hitbox'][2],
			player_sprite.width - CHARACTERS[player]['hitbox'][1], 
			player_sprite.height - CHARACTERS[player]['hitbox'][2]
		)
		player_sprite:add()

	end

	local winner = nil
	if match_in_progress == false then
		if countdown_sprite == nil then
			countdown(3)
			pd.timer.performAfterDelay(1000, countdown, 2)
			pd.timer.performAfterDelay(2000, countdown, 1)
			pd.timer.performAfterDelay(3000, countdown, 'GO!')
			pd.timer.performAfterDelay(4000, countdown, nil)
		end
	else

		winner = match_loop()
	end

	if winner == nil then
		return 'match_' .. current_tournament
	else
		countdown('STOP!')
		STATS['health'] = math.floor(#player_health_sprites / (CHARACTERS[player]['health'] +1) * 100)
		if STATS['throws'] > 0 then
			STATS['accuracy'] = math.floor(STATS['hits'] / STATS['throws'] * 100)
		else
			STATS['accuracy'] = 0
		end
		STATS['points'] = (STATS['accuracy'] + STATS['health']) / 2 -- max score = 100
		STATS['point_total'] += STATS['points']
		for i=1, #ball_sprites do
			ball_sprites[i]:remove()
		end
		player_stunned = true
		opponent_stunned = true
		if cleanup_done then
			match_in_progress = false
			countdown(nil)
			return 'winner_' .. winner
		else
			if not match_ended then
				match_ended = true
				pd.timer.performAfterDelay(3000, cleanup)
			end
			return 'match_' .. current_tournament
		end
	end
end

function cleanup()
	background_sprite:remove()
	opponent_sprite:remove()
	pitch_sprite:remove()
	countdown_sprite:remove()
	countdown_sprite = nil
	for i=1, #player_health_sprites do
		player_health_sprites[i]:remove()
	end
	for i=1, #opponent_health_sprites do
		opponent_health_sprites[i]:remove()
	end
	player_sprite:remove()
	cleanup_done = true
end