import 'CoreLibs/graphics'
import 'CoreLibs/sprites'
import 'CoreLibs/timer'

import 'sound.lua'
import 'menu.lua'
import 'tournament.lua'
import 'match.lua'

local pd <const> = playdate
local gfx <const> = pd.graphics

local medium_font = gfx.font.new('assets/fonts/medium')
local small_font = gfx.font.new('assets/fonts/small')

STATS = {
	throws = 0,
	hits = 0,
	health = 0,
	points = 0,
	point_total = 0,
	hearts_lost = 0,
	elapsed = 0
}
TOURNAMENT_MATCHES = {
	house = {
		'hamster',
		'bunny',
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
local music_scene = nil

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
	},
	scores = {
		['house|bunny'] = {tournament = 'house', character = 'bunny', points = 87, time = 143, hearts_lost = 2}
	},
	run = {tournament = 'house', opponent = 2, character = 'bunny'}
}--]]
local new_tournament_unlocked = false
local new_character_unlocked = false

local scene = nil
local tournament_name = nil
local selected_character = 'bunny'
local opponent_no = 1
-- true while a tournament run is under way, so quitting mid-run can save it
local run_active = false

local clear_save_pending = false
local clear_save_prompt_ready = false

-- pause overlay
local paused = false
local pause_ready = false
local pause_option = 1
local pause_options = {'resume', 'forfeit'}

-- scores screen
local scores_background = nil
local scores_offset = 0
local SCORES_ROWS = 6

local menu = pd.getSystemMenu()
menu:addMenuItem(
	'clear save', 
	function()
		-- destructive: ask for a second press before wiping progress
		clear_save_pending = true
		clear_save_prompt_ready = false
		-- the modal takes over; do not also show the pause overlay afterwards
		paused = false
	end
)

function default_progress()
	return {
		tournament = 1,
		characters = {
			'bunny',
		},
		scores = {}
	}
end

-- a missing or corrupt datastore must not error the game
function load_progress()
	local ok, saved = pcall(pd.datastore.read, 'data')
	if not ok or type(saved) ~= 'table' then
		return default_progress()
	end
	if type(saved['tournament']) ~= 'number' then
		saved['tournament'] = 1
	end
	if type(saved['characters']) ~= 'table' then
		saved['characters'] = {'bunny'}
	end
	if type(saved['scores']) ~= 'table' then
		saved['scores'] = {}
	end
	-- a half-written run record is dropped rather than resumed into a bad state
	local run = saved['run']
	if type(run) ~= 'table'
		or type(run['tournament']) ~= 'string'
		or TOURNAMENT_MATCHES[run['tournament']] == nil
		or type(run['opponent']) ~= 'number'
		or run['opponent'] < 1
		or run['opponent'] > #TOURNAMENT_MATCHES[run['tournament']]
		or type(run['character']) ~= 'string'
		or not in_table(run['character'], saved['characters'])
	then
		saved['run'] = nil
	end
	return saved
end

local ALL_CHARACTERS = {'bunny', 'hamster', 'bird', 'rat', 'cat', 'ferret', 'snake', 'bugs', 'tortoise'}

function unlock_character(name)
	if in_table(name, progress['characters']) then return false end
	table.insert(progress['characters'], name)
	new_character_unlocked = true
	play_sound('character_unlock')
	save_progress()
	if name ~= 'tortoise' then
		local all_others_unlocked = true
		for _, character in ipairs(ALL_CHARACTERS) do
			if character ~= 'tortoise' and not in_table(character, progress['characters']) then all_others_unlocked = false; break end
		end
		if all_others_unlocked then unlock_character('tortoise') end
	end
	return true
end

function unlock_match_rewards()
	if STATS['health_lost_this_match'] == 0 then unlock_character('bird') end
	if STATS['points'] >= 90 and STATS['points'] < 100 then unlock_character('ferret') end
	if STATS['player_rounds'] == 2 and STATS['opponent_rounds'] == 0 then unlock_character('cat') end
	if STATS['throws'] > 0 and STATS['accuracy'] == 100 then unlock_character('bugs') end
end

function save_progress()
	if progress == nil then
		return
	end
	pcall(pd.datastore.write, progress, 'data', true)
end

function clear_save()
	progress = default_progress()
	run_active = false
	save_progress()
end

-- the in-progress tournament run, so quitting mid-run resumes it
function save_run()
	if progress == nil or tournament_name == nil or not run_active then
		return
	end
	progress['run'] = {
		tournament = (tournament_name:gsub('tournament_', '')),
		opponent = opponent_no,
		character = selected_character,
		-- the run's score so far, so a resumed run keeps its totals
		point_total = STATS['point_total'],
		hearts_lost = STATS['hearts_lost'],
		elapsed = STATS['elapsed']
	}
	save_progress()
end

function clear_run()
	run_active = false
	if progress == nil then
		return
	end
	progress['run'] = nil
	save_progress()
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

function draw_pause_menu()
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(100, 60, 200, 90)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(100, 60, 200, 90)

	gfx.setFont(medium_font)
	local text = 'PAUSED'
	local text_width, _ = gfx.getTextSize(text)
	gfx.drawText(
		text,
		math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
		72
	)

	gfx.setFont(small_font)
	for i=1, #pause_options do
		text = pause_options[i]
		text_width, _ = gfx.getTextSize(text)
		local x = math.floor( (pd.display.getWidth() / 2) - (text_width / 2) )
		local y = 100 + ((i - 1) * 22)
		if i == pause_option then
			gfx.image.new('assets/arrow_right'):draw(x - (math.floor(text_width / 2) + 5), y - 8)
		end
		gfx.drawText(text, x, y)
	end
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

-- best score per tournament/character pair, with the time and hearts lost of
-- that best run
function save_score()
	if progress == nil or tournament_name == nil then
		return
	end
	local location = tournament_name:gsub('tournament_', '')
	local key = location .. '|' .. selected_character
	local record = {
		tournament = location,
		character = selected_character,
		points = math.floor(STATS['point_total']),
		time = math.floor(STATS['elapsed']),
		hearts_lost = STATS['hearts_lost']
	}
	local best = progress['scores'][key]
	if type(best) ~= 'table' then
		-- nothing saved yet, or a corrupt entry
		best = nil
	end
	if best == nil or record['points'] > best['points'] then
		progress['scores'][key] = record
		save_progress()
	end
end

function format_time(seconds)
	seconds = math.floor(seconds or 0)
	return string.format('%d:%02d', math.floor(seconds / 60), seconds % 60)
end

function sorted_scores()
	local list = {}
	for _, record in pairs(progress['scores']) do
		-- skip anything a corrupt save left behind
		if type(record) == 'table' and type(record['points']) == 'number' then
			table.insert(list, record)
		end
	end
	table.sort(list, function(a, b)
		if a['tournament'] ~= b['tournament'] then
			return a['tournament'] < b['tournament']
		end
		return a['character'] < b['character']
	end)
	return list
end

function scores()
	-- TODO: the scores screen art is not available yet. ガレス will supply a
	-- background image; drop it in as assets/backgrounds/scores.png and swap
	-- the line below to load it. Until then the plain blank background is used
	-- and the text is drawn straight onto the cleared screen.
	if scores_background == nil then
		scores_background = gfx.image.new('assets/backgrounds/blank')
	end
	scores_background:draw(0, 0)

	local list = sorted_scores()

	gfx.setFont(medium_font)
	local text = 'SCORES'
	local text_width, _ = gfx.getTextSize(text)
	gfx.drawText(
		text,
		math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
		12
	)

	gfx.setFont(small_font)
	if #list == 0 then
		text = 'no scores recorded yet'
		text_width, _ = gfx.getTextSize(text)
		gfx.drawText(
			text,
			math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
			100
		)
	else
		-- column headings
		gfx.drawText('tournament', 20, 40)
		gfx.drawText('animal', 120, 40)
		gfx.drawText('pts', 220, 40)
		gfx.drawText('time', 270, 40)
		gfx.drawText('hearts', 330, 40)

		if pd.buttonJustPressed(pd.kButtonDown) then
			scores_offset += 1
			if scores_offset > #list - SCORES_ROWS then
				scores_offset = math.max(#list - SCORES_ROWS, 0)
			end
			play_sound('menu_move')
		elseif pd.buttonJustPressed(pd.kButtonUp) then
			scores_offset -= 1
			if scores_offset < 0 then
				scores_offset = 0
			end
			play_sound('menu_move')
		end

		for i=1, SCORES_ROWS do
			local record = list[scores_offset + i]
			if record ~= nil then
				local y = 40 + (i * 22)
				gfx.drawText(record['tournament'], 20, y)
				gfx.drawText(record['character'], 120, y)
				gfx.drawText(tostring(record['points']), 220, y)
				gfx.drawText(format_time(record['time']), 270, y)
				gfx.drawText(tostring(record['hearts_lost']), 330, y)
			end
		end
	end

	text = 'A or B = back'
	text_width, _ = gfx.getTextSize(text)
	gfx.drawText(
		text,
		math.floor( (pd.display.getWidth() / 2) - (text_width / 2) ),
		220
	)

	if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
		scores_offset = 0
		play_sound('menu_back')
		return 'main_menu'
	end
	return 'scores'
end

function start_match(tourament_name, opponent_num)
	clear_tournament_sprites() -- from tournament.lua
	set_tournament_timer = false
	scene = play_match(tourament_name, opponent_num, selected_character)
end

function pd.gameWillPause()
	-- Executed when the system menu opens. pd.update stops being called, so the
	-- match cannot advance; the pause overlay takes over when the menu closes.
	if scene ~= nil and string.find(scene, 'match') then
		paused = true
		pause_ready = false
		pause_option = 1
	end
end

function pd.gameWillResume()
	-- Executed when the system menu closes. The wall clock keeps running while
	-- the menu is open, so the match's elapsed time and the unclaimed-ball
	-- timers skip that gap. The in-memory progress is the source of truth now
	-- that runs are saved as they happen, so only read the datastore when there
	-- is nothing in memory to keep.
	resume_match_clock() -- from match.lua
	if clear_save_pending then
		-- the clear-save modal is showing instead of the pause overlay
		paused = false
	end
	if progress == nil then
		progress = load_progress()
	end
end

function pd.gameWillSleep()
	-- Executed when system runs out of battery
	save_run()
	save_progress()
end

function pd.gameWillTerminate()
	-- Executed when game is quit
	save_run()
	save_progress()
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
			play_sound('menu_select')
			clear_save()
		elseif pd.buttonJustPressed(pd.kButtonB) then
			clear_save_pending = false
			play_sound('menu_back')
		end
		gfx.sprite.update()
		draw_clear_save_prompt()
		return
	end

	if paused then
		-- the match is frozen: no scene logic and no timers run while paused
		if not pause_ready then
			-- ignore the press that closed the system menu
			pause_ready = true
		elseif pd.buttonJustPressed(pd.kButtonDown) then
			pause_option += 1
			if pause_option > #pause_options then
				pause_option = 1
			end
			play_sound('menu_move')
		elseif pd.buttonJustPressed(pd.kButtonUp) then
			pause_option -= 1
			if pause_option < 1 then
				pause_option = #pause_options
			end
			play_sound('menu_move')
		elseif pd.buttonJustPressed(pd.kButtonA) then
			local choice = pause_options[pause_option]
			paused = false
			play_sound('menu_select')
			if choice == 'resume' then
				gfx.sprite.redrawBackground()
				resume_match_clock() -- from match.lua
			else
				-- quit keeps the run saved, so relaunching resumes it
				save_run()
				if string.find(scene, 'match') then
					abandon_match() -- from match.lua
				end
				scene = 'main_menu'
			end
		elseif pd.buttonJustPressed(pd.kButtonB) then
			paused = false
			play_sound('menu_back')
			gfx.sprite.redrawBackground()
			resume_match_clock() -- from match.lua
		end
		gfx.sprite.update()
		draw_pause_menu()
		return
	end

	if scene == nil then -- initialise
		scene = 'main_menu'
		progress = load_progress()
		if progress['run'] ~= nil then
			-- resume the tournament run that was in progress when the game quit
			local run = progress['run']
			tournament_name = 'tournament_' .. run['tournament']
			opponent_no = run['opponent']
			selected_character = run['character']
			STATS['point_total'] = run['point_total'] or 0
			STATS['hearts_lost'] = run['hearts_lost'] or 0
			STATS['elapsed'] = run['elapsed'] or 0
			run_active = true
			scene = tournament_name
		end

	elseif scene == 'main_menu' then
		if music_scene ~= scene then
			change_music('assets/music/title', false)
			music_scene = scene
		end
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
			STATS['hearts_lost'] = 0
			STATS['elapsed'] = 0
			run_active = true
			save_run()
		end

	elseif string.find(scene, 'finished') then
		if progress['tournament'] == 1 and new_tournament_unlocked ~= true then
			progress['tournament'] = 2
			new_tournament_unlocked = true
			save_progress()
		elseif progress['tournament'] == 2 and new_tournament_unlocked ~= true then
			progress['tournament'] = 3
			new_tournament_unlocked = true
			save_progress()
		end
		-- beating a tournament unlocks that tournament's first opponent
		local location = tournament_name:gsub('tournament_', '')
		local unlock = TOURNAMENT_MATCHES[location][1]
		if not in_table(unlock, progress['characters']) then
			table.insert(progress['characters'], unlock)
			new_character_unlocked = true
			play_sound('character_unlock')
			save_progress()
		end
		scene = tournament_end(tournament_name, selected_character, new_tournament_unlocked, new_character_unlocked)
		if scene == 'main_menu' then
			save_score()
			clear_run()
		end

	elseif string.find(scene, 'tournament') then
		set_tournament_timer, tournament_name = tournament_intro(scene, opponent_no) -- from tournament.lua
		if set_tournament_timer then
			pd.timer.performAfterDelay(5000, start_match, tournament_name, opponent_no)  -- from match.lua
		end

	elseif string.find(scene, 'match') then
		change_music('assets/music/theme', true)
		new_tournament_unlocked = false
		new_character_unlocked = false
		scene = play_match(nil, nil, selected_character) -- from match.lua

	elseif string.find(scene, 'winner') then
		winner = scene:gsub('winner_', '')
		if winner == 'player' then
			change_music('assets/music/win', false)
			unlock_match_rewards()
			scene = match_end(tournament_name, selected_character, 'WIN') -- from tournament.lua
			if string.find(scene, 'tournament') then
				clear_tournament_sprites() -- from tournament.lua
				if opponent_no < 3 then
					opponent_no += 1
					save_run()
				else
					scene = 'finished_' .. tournament_name
				end
			end
		else
			change_music('assets/music/lose', false)
			scene = match_end(tournament_name, selected_character, 'LOSS') -- from tournament.lua
			if scene == 'main_menu' then
				-- the run is over
				clear_run()
			end
		end

	elseif scene == 'scores' then
		scene = scores()

	end

	gfx.sprite.update() 
	pd.timer.updateTimers()	
end
