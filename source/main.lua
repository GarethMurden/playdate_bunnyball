import 'CoreLibs/graphics'
import 'CoreLibs/sprites'
import 'CoreLibs/timer'

import 'menu.lua'
import 'tournament.lua'
import 'match.lua'

local pd <const> = playdate
local gfx <const> = pd.graphics

STATS = {
	throws = 0,
	hits = 0,
	health = 0,
	points = 0,
	point_total = 0
}
TOURNAMENT_MATCHES = {
	house = {
		'bunny',
		'hamster',
		'bird'
	},
	garden = {
		'rat',
		'cat',
		'ferret'
	},
	park = {
		'snake',
		'bugs',
		'tortoise'
	}
}

local music = pd.sound.fileplayer.new()
local current_track = nil

local progress = nil
--[[{
	tournament = 3,
	characters = {
		'bunny',
		'hamster',
		'bird',
		'rat',
		'cat',
		'ferret',
		'snake',
		'bugs',
		'tortoise'
	}
}--]]
local new_tournament_unlocked = false
local new_character_unlocked = false

local scene = nil
local tournament_name = nil
local selected_character = 'bunny'
local opponent_no = 1

local clear_save_pending = false
local clear_save_prompt_ready = false

local menu = pd.getSystemMenu()
menu:addMenuItem(
	'clear save', 
	function()
		-- destructive: ask for a second press before wiping progress
		clear_save_pending = true
		clear_save_prompt_ready = false
	end
)

function clear_save()
	progress = {
		tournament = 1,
		characters = {
			'bunny',
		},
		scores = {}
	}
	pd.datastore.write(progress, 'data', true)
end

function draw_clear_save_prompt()
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(40, 80, 320, 80)
	gfx.setColor(gfx.kColorWhite)

	local text = 'clear all progress?'
	local text_width, _ = gfx.getTextSize(text)
	gfx.drawText(
		text,
		math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
		95
	)

	text = 'A = clear    B = cancel'
	text_width, _ = gfx.getTextSize(text)
	gfx.drawText(
		text,
		math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
		125
	)
	gfx.setColor(gfx.kColorBlack)
end

function change_music(track, loop)
	if track ~= current_track then
		music:setVolume(0, 0, 0.5)
		music:stop()
		current_track = track
		music:load(track)
		music:setVolume(1)
		if loop then
			music:play(0) -- infinite loop
		else
			music:play(1)
		end
	end
end

function save_score()
	-- TODO: save score for tournament/character combination
	--[[if in_table(tournament_name .. '|' .. select_character, progress['scores']) then
		if STATS['point_total'] > progress['scores']

	end
	table.insert(progress['scores'], {tournament_name, STATS['point_total']})
	STATS = {
		throws = 0,
		hits = 0,
		health = 0,
		points = 0,
		point_total = 0
	}--]]
end

function start_match(tourament_name, opponent_num)
	clear_tournament_sprites() -- from tournament.lua
	set_tournament_timer = false
	scene = play_match(tourament_name, opponent_num, selected_character)
end

function pd.gameWillResume()
	-- Executed when game is un-paused
	progress = pd.datastore.read('data')
end

function pd.gameWillSleep()
	-- Executed when system runs out of battery
	pd.datastore.write(progress, 'data', true)
end

function pd.gameWillTerminate()
	-- Executed when game is quit
	pd.datastore.write(progress, 'data', true)
end

function pd.update()
	gfx.clear()

	if clear_save_pending then
		-- modal: the game is paused until the player confirms or cancels
		if not clear_save_prompt_ready then
			-- ignore the button press that chose the menu item
			clear_save_prompt_ready = true
		elseif pd.buttonJustPressed(pd.kButtonA) then
			clear_save_pending = false
			clear_save()
		elseif pd.buttonJustPressed(pd.kButtonB) then
			clear_save_pending = false
		end
		gfx.sprite.update()
		draw_clear_save_prompt()
		return
	end

	if scene == nil then -- initialise
		scene = 'main_menu'
		progress = pd.datastore.read('data')
		if progress == nil then
			progress = {
				tournament = 1,
				characters = {
					'bunny',
				},
				scores = {}
			}
			pd.datastore.write(progress, 'data', true)
		end

	elseif scene == 'main_menu' then
		scene = main_menu() -- from menu.lua

	elseif scene == 'credits' then
		scene = credits() -- from menu.lua

	elseif scene == 'tournament_selection' then
		scene, tournament_name = select_tournament(progress['tournament']) -- from menu.lua
	
	elseif scene == 'character_selection' then
		local next_scene, next_character = select_character(tournament_name, progress['characters']) -- from menu.lua
		scene = next_scene
		if next_character ~= nil then
			-- B backs out without choosing, so keep the previous character
			selected_character = next_character
		end
		if string.find(scene, 'tournament_') and scene ~= 'tournament_selection' then
			-- a tournament run starts here, so reset its per-run state
			opponent_no = 1
			STATS['point_total'] = 0
		end

	elseif string.find(scene, 'tournament') then
		set_tournament_timer, tournament_name = tournament_intro(scene, opponent_no) -- from tournament.lua
		if set_tournament_timer then
			pd.timer.performAfterDelay(5000, start_match, tournament_name, opponent_no)  -- from match.lua
		end

	elseif string.find(scene, 'match') then
		new_tournament_unlocked = false
		new_character_unlocked = false
		scene = play_match(nil, nil, selected_character) -- from match.lua

	elseif string.find(scene, 'winner') then
		winner = scene:gsub('winner_', '')
		if winner == 'player' then
			scene = match_end(tournament_name, selected_character, 'WIN') -- from tournament.lua
			if string.find(scene, 'tournament') then
				clear_tournament_sprites() -- from tournament.lua
				if opponent_no < 3 then
					opponent_no += 1
				else
					scene = 'finished_' .. tournament_name
				end
			end
		else
			scene = match_end(tournament_name, selected_character, 'LOSS') -- from tournament.lua
		end

	elseif string.find(scene, 'finished') then
		if progress['tournament'] == 1 and new_tournament_unlocked ~= true then
			progress['tournament'] = 2
			new_tournament_unlocked = true
		elseif progress['tournament'] == 2 and new_tournament_unlocked ~= true then
			progress['tournament'] = 3
			new_tournament_unlocked = true
		end
		-- TODO: character unlock
		character_unlock = false
		scene = tournament_end(tournament_name, selected_character, new_tournament_unlocked, new_character_unlocked)
		if scene == 'main_menu' then
			save_score()
		end

	elseif scene == 'scores' then
		-- score saving is not implemented yet, so there is nothing to list
		gfx.setFont(gfx.getSystemFont())
		local text = 'no scores recorded yet'
		local text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			100
		)
		text = 'A or B = back'
		text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			140
		)
		if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
			scene = 'main_menu'
		end

	end

	gfx.sprite.update() 
	pd.timer.updateTimers()	
end