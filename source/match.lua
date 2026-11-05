local pd <const> = playdate
local gfx <const> = pd.graphics

import 'characters.lua'

math.randomseed(pd.getSecondsSinceEpoch())

local large_font = gfx.font.new('assets/fonts/large')
local small_font = gfx.font.new('assets/fonts/small')

-- the existing stat bars, reused as a 7-step power meter. The table is
-- 1-based, so power_bars[1] is assets/bar/0 and power_bars[7] is bar/6.
local power_bars = {
	gfx.image.new('assets/bar/0'),
	gfx.image.new('assets/bar/1'),
	gfx.image.new('assets/bar/2'),
	gfx.image.new('assets/bar/3'),
	gfx.image.new('assets/bar/4'),
	gfx.image.new('assets/bar/5'),
	gfx.image.new('assets/bar/6')
}

-- a match is best of three: the first side to win this many rounds takes it
local ROUNDS_TO_WIN = 2
-- tournament 2 rule: a ball nobody picks up for this long changes sides
local BALL_UNCLAIMED_SECONDS = 5

-- press-and-hold throw: holding A for this long charges the throw fully
local CHARGE_MAX_SECONDS = 1.0
-- a throw with no charge takes this much longer than a full-charge throw:
-- 0.5 means a tap is 1.5x the full-charge time, so it still crosses the field
local CHARGE_SLOWEST_FACTOR = 0.5
-- how far short of the opponent's line the ball can be aimed, in pixels.
-- The throw travels from the player's shoulder (y 141) to the opponent's line
-- (y 95), so 30 is the far end of the opponent's half.
local AIM_MAX_OFFSET = 30
-- one press of up/down moves the aim by this much, giving three settings
local AIM_STEP = 15

-- B dash: a short burst of speed in the direction the player is facing
local DASH_SPEED_MULTIPLIER = 3
local DASH_SECONDS = 0.15
local DASH_COOLDOWN_SECONDS = 0.6

-- explicit draw order, so layering does not depend on the order sprites happen
-- to be added. These reproduce the order the game already produced: the pitch
-- overlay is drawn over the opponent (whose feet sit under the field's top
-- edge), and the balls, player and HUD are drawn over the pitch.
local Z_BACKGROUND = 1
local Z_OPPONENT = 2
local Z_PITCH = 3
local Z_HEALTH = 4
local Z_BALLS = 5
local Z_PLAYER = 6
local Z_HUD = 7
local Z_COUNTDOWN = 8
local Z_CHARGE = 9

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

-- throw charge and aim, set while A is held with a ball
local player_charging = false
local player_charge = 0
local player_aim = 0
local player_dash_time = 0
local player_dash_cooldown = 0

-- round state
local round_number = 1
local player_rounds = 0
local opponent_rounds = 0
local round_over = false
local round_winner = nil

-- bumped whenever a match starts or is abandoned, so timers scheduled by an
-- abandoned match cannot fire into the next one
local match_id = 0

local countdown_sprite = nil
local hud_sprite = nil
local charge_sprite = nil
-- the meter is only redrawn when one of these changes, so holding A does not
-- rebuild the image every frame
local charge_bar_shown = nil
local charge_aim_shown = nil
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
	pd.timer.new(1, 1, 1),
	pd.timer.new(1, 1, 1),
	pd.timer.new(1, 1, 1),
	pd.timer.new(1, 1, 1),
	pd.timer.new(1, 1, 1),
	pd.timer.new(1, 1, 1),
	pd.timer.new(1, 1, 1),
	pd.timer.new(1, 1, 1),
	pd.timer.new(1, 1, 1),
	pd.timer.new(1, 1, 1)
}
-- seconds each ball has sat unclaimed on its side
local ball_idle_time = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
-- a ball only starts counting once it has been thrown, so the balls laid out
-- at the start of a round are not swept across the field before anyone plays
local ball_in_play = {false, false, false, false, false, false, false, false, false, false}
-- clock reading at the previous frame, for the elapsed-time and ball-idle rules
local last_elapsed = 0

function schedule_match_timer(delay, callback, ...)
	local id = match_id
	local args = {...}
	pd.timer.performAfterDelay(delay, function()
		if id == match_id then
			callback(table.unpack(args))
		end
	end)
end

-- a ball can be picked up by a side once it has come to rest in that side's
-- half. Aimed throws land short of the opponent's line, so "at the line" is
-- not enough to decide who can reach a ball.
function ball_resting_on_side(i, side)
	if ball_movement_timers[i].value ~= ball_movement_timers[i].endValue then
		return false
	end
	local middle_of_field = (top_of_field + bottom_of_field) / 2
	if side == 'player' then
		return ball_sprites[i].y > middle_of_field
	else
		return ball_sprites[i].y < middle_of_field
	end
end

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

-- tournament 2 rule: a ball left unclaimed for BALL_UNCLAIMED_SECONDS moves to
-- the other side of the field
function ball_unclaimed_rule(delta)
	if current_tournament ~= 'garden' then
		return
	end
	for i=1, #ball_sprites do
		local carried = (player_carrying == i) or (opponent_carrying == i)
		local moving = ball_movement_timers[i].value ~= ball_movement_timers[i].endValue
		if carried or moving then
			ball_idle_time[i] = 0
		elseif not ball_in_play[i] then
			ball_idle_time[i] = 0
		else
			ball_idle_time[i] += delta
			if ball_idle_time[i] >= BALL_UNCLAIMED_SECONDS then
				ball_idle_time[i] = 0
				local new_y = top_of_field
				if ball_resting_on_side(i, 'opponent') then
					new_y = bottom_of_field
				end
				ball_sprites[i]:moveTo(
					ball_sprites[i].x,
					new_y
				)
				-- a finished timer, so ball_move leaves the ball where it is
				ball_movement_timers[i] = pd.timer.new(1, new_y, new_y)
			end
		end
	end
end

function reset_ball_idle_timers()
	for i=1, #ball_idle_time do
		ball_idle_time[i] = 0
		ball_in_play[i] = false
	end
end

-- one image per countdown word, built the first time that word is shown and
-- reused after that, so the end-of-round 'STOP!' does not rebuild its image
local countdown_images = {}

function countdown(number)
	if type(number) == 'number' then
		play_sound('countdown_tick')
	elseif number == 'GO!' then
		play_sound('go')
	end

	if countdown_sprite == nil then
		countdown_sprite = gfx.sprite.new()
		countdown_sprite:setZIndex(Z_COUNTDOWN)
	end
	
	countdown_sprite:remove()

	if number ~= nil then
		local background_image = countdown_images[number]
		if background_image == nil then
			background_image = gfx.image.new('assets/backgrounds/blank')
			gfx.pushContext(background_image)

			gfx.setFont(large_font)
			local text_width, text_height = gfx.getTextSize(number)
			gfx.drawText(
				number,
				math.floor( (pd.display.getWidth()  / 2) - (text_width / 2) ),
				math.floor( (pd.display.getHeight() / 2) - (text_height / 2) ) + 20
			)

			gfx.popContext()
			countdown_images[number] = background_image
		end

		countdown_sprite:setImage(background_image)
		countdown_sprite:moveTo(
			math.floor( pd.display.getWidth()  / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		countdown_sprite:add()
	else
		match_in_progress = true
	end
end

function match_loop(delta)
	-- time to defeat: seconds of play, counted across every round of the match
	STATS['elapsed'] += delta

	-- Player actions
	if #player_sprite:overlappingSprites() > 0 then
		player_hit()
	end
	if not player_stunned then
		player_move(player_carrying, delta)

		-- A picks a ball up and starts charging in the same press, so a tap
		-- throws straight away (as before) and holding charges the throw.
		-- Releasing A throws.
		if pd.buttonJustPressed(pd.kButtonA) then
			if player_carrying == nil then
				player_carrying = player_pickup()
			end
			if player_carrying then
				player_charging = true
				player_charge = 0
				player_aim = 0
			end
		end
		if player_charging then
			if player_carrying == nil then
				player_charging = false
			elseif pd.buttonIsPressed(pd.kButtonA) then
				player_charge += delta
				if player_charge > CHARGE_MAX_SECONDS then
					player_charge = CHARGE_MAX_SECONDS
				end
				-- up aims deeper, down aims shorter
				if pd.buttonJustPressed(pd.kButtonUp) then
					player_aim -= AIM_STEP
					if player_aim < 0 then
						player_aim = 0
					end
				elseif pd.buttonJustPressed(pd.kButtonDown) then
					player_aim += AIM_STEP
					if player_aim > AIM_MAX_OFFSET then
						player_aim = AIM_MAX_OFFSET
					end
				end
			else
				player_throw(player_carrying, player_charge, player_aim)
				player_carrying = nil
				player_charging = false
			end
		end
	end
	-- outside the stun check, so the meter disappears as soon as a hit
	-- cancels the charge
	update_charge_hud()

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
	ball_unclaimed_rule(delta)

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
	-- hearts_lost and elapsed are per tournament run, like point_total, so they
	-- are reset when a run starts (main.lua) rather than per match
	last_elapsed = pd.getElapsedTime()

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
	opponent_step = 1

	player_charging = false
	player_charge = 0
	player_aim = 0
	player_dash_time = 0
	player_dash_cooldown = 0

	round_number = 1
	player_rounds = 0
	opponent_rounds = 0
	round_over = false
	round_winner = nil

	countdown_sprite = nil
	hud_sprite = nil
	charge_sprite = nil
	charge_bar_shown = nil
	charge_aim_shown = nil
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
		pd.timer.new(1, 1, 1),
		pd.timer.new(1, 1, 1),
		pd.timer.new(1, 1, 1),
		pd.timer.new(1, 1, 1),
		pd.timer.new(1, 1, 1),
		pd.timer.new(1, 1, 1),
		pd.timer.new(1, 1, 1),
		pd.timer.new(1, 1, 1),
		pd.timer.new(1, 1, 1),
		pd.timer.new(1, 1, 1)
	}
	reset_ball_idle_timers()
end

-- player_blocks / opponent_blocks: how many health blocks to draw. nil means
-- a full bar for that character.
function build_health_bars(player_blocks, opponent_blocks)
	for i=1, #player_health_sprites do
		player_health_sprites[i]:remove()
	end
	for i=1, #opponent_health_sprites do
		opponent_health_sprites[i]:remove()
	end

	if player_blocks == nil then
		player_blocks = CHARACTERS[player]['health']
	end
	if opponent_blocks == nil then
		opponent_blocks = CHARACTERS[opponent]['health']
	end

	player_health_sprites = {
		gfx.sprite.new(gfx.image.new('assets/health/player_heart'))
	}
	player_health_sprites[1]:moveTo(
		380,
		215
	)
	player_health_sprites[1]:setZIndex(Z_HEALTH)
	player_health_sprites[1]:add()
	local horizontal_position = 376
	for i=1, player_blocks do
		horizontal_position -= 13
		local health_block = gfx.sprite.new(gfx.image.new('assets/health/block'))
		health_block:setZIndex(Z_HEALTH)
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

	opponent_health_sprites = {
		gfx.sprite.new(gfx.image.new('assets/health/cpu_heart'))
	}
	opponent_health_sprites[1]:moveTo(
		25,
		20
	)
	opponent_health_sprites[1]:setZIndex(Z_HEALTH)
	opponent_health_sprites[1]:add()
	horizontal_position = 42
	for i=1, opponent_blocks do
		local health_block = gfx.sprite.new(gfx.image.new('assets/health/block'))
		health_block:setZIndex(Z_HEALTH)
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
end

function place_balls()
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
		ball_sprites[i]:setZIndex(Z_BALLS)
		ball_sprites[i]:add()
		-- a finished timer: the ball is at rest, so ball_move leaves it alone
		-- and its collisions stay off until it is thrown
		ball_movement_timers[i] = pd.timer.new(
			1,
			ball_start_positions[i][2],
			ball_start_positions[i][2]
		)
		ball_idle_time[i] = 0
		ball_in_play[i] = false
	end
end

function place_fighters()
	opponent_sprite:setImage(CHARACTERS[opponent]['assets']['idle_cpu'])
	opponent_sprite:moveTo(
		math.floor( pd.display.getWidth() / 2),
		70
	)
	opponent_sprite:setCollisionsEnabled(true)

	player_sprite:setImage(CHARACTERS[player]['assets']['idle_player'])
	player_sprite:moveTo(
		math.floor( pd.display.getWidth() / 2),
		170
	)
	player_sprite:setCollisionsEnabled(true)
end

-- round counter and round wins, drawn over the pitch
function build_hud()
	if hud_sprite == nil then
		hud_sprite = gfx.sprite.new()
	end
	hud_sprite:remove()

	-- sits in the light box at the top centre of the pitch background
	local hud_image = gfx.image.new(120, 26)
	gfx.pushContext(hud_image)
	gfx.setFont(small_font)

	local text = 'ROUND ' .. round_number
	local text_width, _ = gfx.getTextSize(text)
	gfx.drawText(
		text,
		math.floor( (120 - text_width) / 2 ),
		0
	)

	-- rounds won: player first, then opponent
	text = player_rounds .. ' - ' .. opponent_rounds
	text_width, _ = gfx.getTextSize(text)
	gfx.drawText(
		text,
		math.floor( (120 - text_width) / 2 ),
		13
	)
	gfx.popContext()

	hud_sprite:setImage(hud_image)
	hud_sprite:moveTo(
		200,
		21
	)
	hud_sprite:setZIndex(Z_HUD)
	hud_sprite:add()
end

-- power meter and aim, drawn while A is held with a ball. Reuses the stat
-- bars as a 7-step meter and the small font for the label, on a white panel
-- so it reads over any of the three pitch backgrounds.
function update_charge_hud()
	if not player_charging then
		if charge_sprite ~= nil then
			charge_sprite:remove()
			charge_sprite = nil
		end
		charge_bar_shown = nil
		charge_aim_shown = nil
		return
	end

	local charge_ratio = player_charge / CHARGE_MAX_SECONDS
	if charge_ratio > 1 then
		charge_ratio = 1
	end
	-- 0 to 6, then shifted to the table's 1-based index
	local bar_index = math.floor((charge_ratio * 6) + 0.5) + 1
	local aim_level = math.floor((player_aim / AIM_STEP) + 0.5)

	if charge_sprite ~= nil
		and charge_bar_shown == bar_index
		and charge_aim_shown == aim_level
	then
		return
	end
	charge_bar_shown = bar_index
	charge_aim_shown = aim_level

	if charge_sprite == nil then
		charge_sprite = gfx.sprite.new()
	end
	charge_sprite:remove()

	local meter_image = gfx.image.new(170, 26)
	gfx.pushContext(meter_image)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0, 0, 170, 26)
	power_bars[bar_index]:draw(2, 5)

	-- aim: three notches, the filled one is where the ball will land.
	-- top is deep (the opponent's line), bottom is short.
	gfx.setColor(gfx.kColorBlack)
	for i=0, 2 do
		local y = 4 + (i * 7)
		if i == aim_level then
			gfx.fillRect(104, y, 8, 5)
		else
			gfx.drawRect(104, y, 8, 5)
		end
	end
	gfx.setFont(small_font)
	gfx.drawText('AIM', 116, 6)
	gfx.popContext()

	charge_sprite:setImage(meter_image)
	charge_sprite:moveTo(100, 215)
	charge_sprite:setZIndex(Z_CHARGE)
	charge_sprite:add()
end

function start_next_round()
	round_number += 1
	round_over = false
	match_in_progress = false
	if countdown_sprite ~= nil then
		countdown_sprite:remove()
		countdown_sprite = nil
	end

	player_carrying = nil
	opponent_carrying = nil
	player_stunned = false
	opponent_stunned = false
	opponent_destination = left_of_field
	player_step = 1
	opponent_step = 1
	player_charging = false
	player_charge = 0
	player_aim = 0
	player_dash_time = 0
	player_dash_cooldown = 0
	if charge_sprite ~= nil then
		charge_sprite:remove()
		charge_sprite = nil
	end
	charge_bar_shown = nil
	charge_aim_shown = nil

	-- tournament 3 rule: no healing between rounds. The side that won the round
	-- keeps the hearts it has left, so damage carries forward. The side that
	-- lost is restored to a full bar, because a round ends at zero hearts and
	-- carrying that over would end the next round before it started.
	if current_tournament == 'park' then
		if round_winner == 'player' then
			build_health_bars(#player_health_sprites - 1, nil)
		else
			build_health_bars(nil, #opponent_health_sprites - 1)
		end
	else
		build_health_bars()
	end

	place_balls()
	place_fighters()
	build_hud()
end

-- called when the pause overlay closes, so the time spent paused is not
-- counted towards the match's elapsed time
function resume_match_clock()
	last_elapsed = pd.getElapsedTime()
end

-- tear a match down without running its end sequence (forfeit or quit)
function abandon_match()
	match_id += 1
	if background_sprite ~= nil then
		background_sprite:remove()
	end
	if opponent_sprite ~= nil then
		opponent_sprite:remove()
	end
	if pitch_sprite ~= nil then
		pitch_sprite:remove()
	end
	if countdown_sprite ~= nil then
		countdown_sprite:remove()
	end
	if hud_sprite ~= nil then
		hud_sprite:remove()
	end
	if charge_sprite ~= nil then
		charge_sprite:remove()
		charge_sprite = nil
	end
	if player_sprite ~= nil then
		player_sprite:remove()
	end
	for i=1, #player_health_sprites do
		player_health_sprites[i]:remove()
	end
	for i=1, #opponent_health_sprites do
		opponent_health_sprites[i]:remove()
	end
	for i=1, #ball_sprites do
		ball_sprites[i]:remove()
	end
	initialise()
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
			if ball_resting_on_side(i, 'opponent') then
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
		ball_in_play[opponent_carrying] = true
		ball_movement_timers[opponent_carrying] = pd.timer.new(
			6000 / CHARACTERS[opponent]['strength'],-- duration
			top_of_field + ball_sprites[opponent_carrying].height,	-- start
			bottom_of_field,				-- end
			pd.easingFunctions.outBack 	-- easing function
		)
		play_sound('throw', 0.8)
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
	local picked_up = false
	for i=1, #ball_sprites do
		if ball_resting_on_side(i, 'opponent') then
			if ball_sprites[i].x >= reach[1] and ball_sprites[i].x <= reach[2] then
				ball_sprites[i]:moveTo(
					opponent_sprite.x - CHARACTERS[opponent]['carry_position'][1],
					opponent_sprite.y + CHARACTERS[opponent]['carry_position'][2]
				)
				opponent_carrying = i
				picked_up = true
			end -- /ball_sprites[i].x >= reach...
		end -- /ball resting in the opponent's half
	end -- /for i=1, #ball_sprites
	if picked_up then
		play_sound('ball_pickup')
	end
end

function opponent_act_medium()
	local balls_available = {}
	for i=1, #ball_sprites do
		if ball_resting_on_side(i, 'opponent') then
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
		if ball_resting_on_side(i, 'opponent') then
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
	play_sound('ball_hit')
	play_sound('opponent_hit')
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
	schedule_match_timer(1500, opponent_release_stun)
end

function opponent_release_stun()
	opponent_stunned = false
	opponent_sprite:setImage(
		CHARACTERS[opponent]['assets']['idle_cpu']
	)
	schedule_match_timer(1500, opponent_enable_collisions)
end

function player_enable_collisions()
	player_sprite:setCollisionsEnabled(true)
end

function player_hit()
	STATS['hearts_lost'] += 1
	play_sound('ball_hit')
	play_sound('player_hit')
	player_stunned = true
	player_charging = false
	player_sprite:setCollisionsEnabled(false)
	player_sprite:setImage(
		CHARACTERS[player]['assets']['hit_player']
	)
	player_health_sprites[#player_health_sprites]:remove()
	table.remove(
		player_health_sprites,
		#player_health_sprites
	)
	schedule_match_timer(1500, player_release_stun)
end

function player_move(carrying, delta)
	delta = delta or 0

	-- dash and its cooldown run on the frame clock
	if player_dash_cooldown > 0 then
		player_dash_cooldown -= delta
		if player_dash_cooldown < 0 then
			player_dash_cooldown = 0
		end
	end
	if player_dash_time > 0 then
		player_dash_time -= delta
		if player_dash_time < 0 then
			player_dash_time = 0
		end
	end

	local moving_left = pd.buttonIsPressed(pd.kButtonLeft)
	local moving_right = pd.buttonIsPressed(pd.kButtonRight)

	-- B dashes in the direction the player is moving, if the cooldown is up
	if pd.buttonJustPressed(pd.kButtonB)
		and player_dash_cooldown <= 0
		and (moving_left or moving_right)
	then
		player_dash_time = DASH_SECONDS
		player_dash_cooldown = DASH_COOLDOWN_SECONDS
	end

	local speed = CHARACTERS[player]['speed']
	if player_dash_time > 0 then
		speed = speed * DASH_SPEED_MULTIPLIER
	end

	if moving_left then
		player_step -= 1
		if player_step < 1 then
			player_step = #CHARACTERS[player]['assets']['run_sequence']
		end
		player_sprite:setImage(
			CHARACTERS[player]['assets']['run_sequence'][player_step]
		)
		
		if (player_sprite.x - speed) < left_of_field then
			player_sprite:moveTo(
				left_of_field,
				player_sprite.y
			)
		else
			player_sprite:moveTo(
				player_sprite.x - speed,
				player_sprite.y
			)
		end
		if carrying ~= nil then
			ball_sprites[carrying]:moveTo(
				player_sprite.x - CHARACTERS[player]['carry_position'][1],
				player_sprite.y + CHARACTERS[player]['carry_position'][2]
			)
		end

	elseif moving_right then
		player_step += 1
		if player_step > #CHARACTERS[player]['assets']['run_sequence'] then
			player_step = 1
		end
		player_sprite:setImage(
			CHARACTERS[player]['assets']['run_sequence'][player_step],
			'flipX'
		)
		if (player_sprite.x + speed) > right_of_field then
			player_sprite:moveTo(
				right_of_field,
				player_sprite.y
			)
		else
			player_sprite:moveTo(
				player_sprite.x + speed,
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
		if ball_resting_on_side(i, 'player') then
			if ball_sprites[i].x >= reach[1] and ball_sprites[i].x <= reach[2] then
				ball_sprites[i]:moveTo(
					player_sprite.x - CHARACTERS[player]['carry_position'][1],
					player_sprite.y + CHARACTERS[player]['carry_position'][2]
				)
				play_sound('ball_pickup')
				return i
			end -- /ball_sprites[i].x >= reach...
		end -- /ball resting in the player's half
	end -- /for i=1, #ball_sprites
end

function player_release_stun()
	player_stunned = false
	player_sprite:setImage(
		CHARACTERS[player]['assets']['idle_player']
	)
	schedule_match_timer(1500, player_enable_collisions)
end

-- charge is seconds of held A, aim is pixels short of the opponent's line
function player_throw(carrying, charge, aim)
	STATS['throws'] += 1
	ball_in_play[carrying] = true

	charge = charge or 0
	aim = aim or 0
	local charge_ratio = charge / CHARGE_MAX_SECONDS
	if charge_ratio > 1 then
		charge_ratio = 1
	end

	-- a full charge throws at the old fixed speed; no charge is
	-- CHARGE_SLOWEST_FACTOR slower, so a tap still crosses the field
	local duration = (6000 / CHARACTERS[player]['strength'])
		* (1 + (CHARGE_SLOWEST_FACTOR * (1 - charge_ratio)))

	ball_movement_timers[carrying] = pd.timer.new(
		duration,					-- duration
		player_sprite.y - (player_sprite.height - CHARACTERS[player]['hitbox'][2]),	-- start
		top_of_field + aim,			-- end
		pd.easingFunctions.outBack 	-- easing function
	)

	-- the throw gets higher as the charge builds
	play_sound('throw', 0.7 + (0.6 * charge_ratio))
end

function play_match(tourament_name, opponent_num, selected_character)
	if tourament_name ~= nil then
		initialise()
		match_id += 1

		current_tournament = tourament_name
		opponent = TOURNAMENT_MATCHES[current_tournament][opponent_num]
		player = selected_character

		local background_image = gfx.image.new('assets/backgrounds/pitch_' .. tourament_name)
		background_sprite = gfx.sprite.new(background_image)
		background_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		background_sprite:setZIndex(Z_BACKGROUND)
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
		opponent_sprite:setZIndex(Z_OPPONENT)
		opponent_sprite:add()

		local pitch_image = gfx.image.new('assets/backgrounds/pitch')
		pitch_sprite = gfx.sprite.new(pitch_image)
		pitch_sprite:moveTo(
			math.floor( pd.display.getWidth() / 2),
			math.floor( pd.display.getHeight() / 2)
		)
		pitch_sprite:setZIndex(Z_PITCH)
		pitch_sprite:add()

		build_health_bars()
		place_balls()

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
		player_sprite:setZIndex(Z_PLAYER)
		player_sprite:add()

		build_hud()
	end

	-- seconds since the previous frame, for the elapsed-time and ball-idle rules
	local now = pd.getElapsedTime()
	local delta = now - last_elapsed
	last_elapsed = now

	local winner = nil
	if match_in_progress == false then
		if countdown_sprite == nil then
			countdown(3)
			schedule_match_timer(1000, countdown, 2)
			schedule_match_timer(2000, countdown, 1)
			schedule_match_timer(3000, countdown, 'GO!')
			schedule_match_timer(4000, countdown, nil)
		end
	elseif not round_over then
		winner = match_loop(delta)
	end

	if winner ~= nil then
		-- the round is over
		round_over = true
		round_winner = winner
		if winner == 'player' then
			player_rounds += 1
			play_sound('round_win')
		else
			opponent_rounds += 1
			play_sound('round_lose')
		end
		build_hud()
		player_charging = false
		if charge_sprite ~= nil then
			charge_sprite:remove()
			charge_sprite = nil
		end
		charge_bar_shown = nil
		charge_aim_shown = nil
		countdown('STOP!')
		for i=1, #ball_sprites do
			ball_sprites[i]:remove()
		end
		player_stunned = true
		opponent_stunned = true
		if player_rounds >= ROUNDS_TO_WIN or opponent_rounds >= ROUNDS_TO_WIN then
			match_ended = true
			schedule_match_timer(3000, cleanup)
		else
			schedule_match_timer(3000, start_next_round)
		end
	end

	if match_ended and cleanup_done then
		match_in_progress = false
		countdown(nil)
		STATS['health'] = math.floor(#player_health_sprites / (CHARACTERS[player]['health'] +1) * 100)
		if STATS['throws'] > 0 then
			STATS['accuracy'] = math.floor(STATS['hits'] / STATS['throws'] * 100)
		else
			STATS['accuracy'] = 0
		end
		STATS['points'] = (STATS['accuracy'] + STATS['health']) / 2 -- max score = 100
		STATS['point_total'] += STATS['points']
		if round_winner == 'player' then
			play_sound('match_win')
		else
			play_sound('match_lose')
		end
		return 'winner_' .. round_winner
	end

	return 'match_' .. current_tournament
end

function cleanup()
	if background_sprite ~= nil then
		background_sprite:remove()
	end
	if opponent_sprite ~= nil then
		opponent_sprite:remove()
	end
	if pitch_sprite ~= nil then
		pitch_sprite:remove()
	end
	if countdown_sprite ~= nil then
		countdown_sprite:remove()
	end
	countdown_sprite = nil
	if hud_sprite ~= nil then
		hud_sprite:remove()
	end
	if charge_sprite ~= nil then
		charge_sprite:remove()
		charge_sprite = nil
	end
	for i=1, #player_health_sprites do
		player_health_sprites[i]:remove()
	end
	for i=1, #opponent_health_sprites do
		opponent_health_sprites[i]:remove()
	end
	if player_sprite ~= nil then
		player_sprite:remove()
	end
	cleanup_done = true
end
