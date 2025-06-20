import 'CoreLibs/graphics'
import 'CoreLibs/sprites'
import 'CoreLibs/timer'

import 'menu.lua'
import 'tournament.lua'
import 'match.lua'

local pd <const> = playdate
local gfx <const> = pd.graphics

VERSION = '0.3'
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

local menu = pd.getSystemMenu()
menu:addMenuItem(
	'clear save', 
	function()
		print('progress reset')
		progress = {
			tournament = 1,
			characters = {
				'bunny',
			},
			scores = {}
		}
		pd.datastore.write(progress, 'data', true)
	end
)

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
		scene, selected_character = select_character(tournament_name, progress['characters']) -- from menu.lua

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
					opponent_no = 1
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
		print(' [ DEBUG ] : show scores')
		
	end

	gfx.sprite.update() 
	pd.timer.updateTimers()	
	pd.drawFPS(10, 10)
end