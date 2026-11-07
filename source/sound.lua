local pd <const> = playdate
local snd <const> = pd.sound

-- every effect is scaled by this, so one number turns the whole game down
SOUND_VOLUME = 0.4
-- set to true to silence every effect without touching the call sites
SOUND_MUTED = false

-- A synth holds one queued note, so effects are played from a small pool of
-- synths rather than one synth per effect: that keeps the number of audio
-- sources low and lets a sound retrigger while its tail is still ringing.
local POOL_SIZE = 8
local synth_pool = {}
-- the audio time each pooled synth is free again
local synth_free_at = {}
local next_synth = 1

-- Each effect is a list of steps. A step is one note:
--   wave    one of the playdate.sound.kWave* constants
--   pitch   in Hz
--   length  seconds the note is held
--   delay   seconds after the effect starts
--   volume  0 to 1, before SOUND_VOLUME
--   attack, decay, sustain, release  the envelope, with defaults below
local effects = {}

local function add_effect(name, steps)
	effects[name] = steps
end

-- menus
add_effect('menu_move', {
	{wave = snd.kWaveSquare, pitch = 660, length = 0.04, decay = 0.02, release = 0.02, volume = 0.5}
})
add_effect('menu_select', {
	{wave = snd.kWaveSquare, pitch = 660, length = 0.05, volume = 0.6},
	{wave = snd.kWaveSquare, pitch = 990, length = 0.08, delay = 0.05, volume = 0.6}
})
add_effect('menu_back', {
	{wave = snd.kWaveSquare, pitch = 440, length = 0.05, volume = 0.5},
	{wave = snd.kWaveSquare, pitch = 330, length = 0.08, delay = 0.05, volume = 0.5}
})

-- the match
add_effect('ball_pickup', {
	{wave = snd.kWaveTriangle, pitch = 880, length = 0.06, volume = 0.6}
})
-- the pitch of this one is scaled by the throw's charge, see play_sound
add_effect('throw', {
	{wave = snd.kWaveSquare, pitch = 330, length = 0.10, volume = 0.5}
})
add_effect('ball_hit', {
	{wave = snd.kWaveNoise, pitch = 220, length = 0.06, attack = 0.001, decay = 0.05, release = 0.02, volume = 0.7}
})
add_effect('player_hit', {
	{wave = snd.kWaveSawtooth, pitch = 110, length = 0.18, volume = 0.7}
})
add_effect('opponent_hit', {
	{wave = snd.kWaveSawtooth, pitch = 165, length = 0.18, volume = 0.7}
})
add_effect('countdown_tick', {
	{wave = snd.kWaveSquare, pitch = 440, length = 0.08, volume = 0.5}
})
add_effect('go', {
	{wave = snd.kWaveSquare, pitch = 880, length = 0.25, volume = 0.7}
})
add_effect('round_win', {
	{wave = snd.kWaveTriangle, pitch = 660, length = 0.10, volume = 0.6},
	{wave = snd.kWaveTriangle, pitch = 880, length = 0.16, delay = 0.10, volume = 0.6}
})
add_effect('round_lose', {
	{wave = snd.kWaveTriangle, pitch = 330, length = 0.10, volume = 0.6},
	{wave = snd.kWaveTriangle, pitch = 220, length = 0.18, delay = 0.10, volume = 0.6}
})
add_effect('match_win', {
	{wave = snd.kWaveSquare, pitch = 660, length = 0.10, volume = 0.6},
	{wave = snd.kWaveSquare, pitch = 880, length = 0.10, delay = 0.10, volume = 0.6},
	{wave = snd.kWaveSquare, pitch = 1320, length = 0.24, delay = 0.20, volume = 0.6}
})
add_effect('match_lose', {
	{wave = snd.kWaveSawtooth, pitch = 220, length = 0.14, volume = 0.6},
	{wave = snd.kWaveSawtooth, pitch = 165, length = 0.14, delay = 0.14, volume = 0.6},
	{wave = snd.kWaveSawtooth, pitch = 110, length = 0.30, delay = 0.28, volume = 0.6}
})
add_effect('character_unlock', {
	{wave = snd.kWaveTriangle, pitch = 660, length = 0.08, volume = 0.6},
	{wave = snd.kWaveTriangle, pitch = 880, length = 0.08, delay = 0.08, volume = 0.6},
	{wave = snd.kWaveTriangle, pitch = 1320, length = 0.20, delay = 0.16, volume = 0.6}
})

-- a synth that is free at audio time `when`, or the next one in the rotation
-- if every synth in the pool is busy. A synth with a note queued for later is
-- busy until that note has finished, so a queued note is never overwritten.
local function take_synth(when)
	for i=1, POOL_SIZE do
		local synth = synth_pool[i]
		if synth ~= nil and (synth_free_at[i] or 0) <= when then
			return synth, i
		end
	end
	local index = next_synth
	local synth = synth_pool[index]
	if synth == nil then
		synth = snd.synth.new(snd.kWaveSquare)
		synth_pool[index] = synth
	end
	next_synth += 1
	if next_synth > POOL_SIZE then
		next_synth = 1
	end
	return synth, index
end

-- pitch_scale multiplies every note's pitch, so one effect can be reused at
-- different pitches (the throw uses it for its charge)
function play_sound(name, pitch_scale)
	if SOUND_MUTED or SOUND_VOLUME <= 0 then
		return
	end
	local steps = effects[name]
	if steps == nil then
		return
	end
	pitch_scale = pitch_scale or 1
	local now = snd.getCurrentTime()
	for i=1, #steps do
		local step = steps[i]
		local delay = step['delay'] or 0
		local length = step['length'] or 0.08
		local release = step['release'] or 0.04
		local synth, index = take_synth(now + delay)
		synth:setWaveform(step['wave'])
		synth:setADSR(
			step['attack'] or 0.005,
			step['decay'] or 0.04,
			step['sustain'] or 0,
			release
		)
		synth:playNote(
			step['pitch'] * pitch_scale,
			(step['volume'] or 1) * SOUND_VOLUME,
			length,
			now + delay
		)
		synth_free_at[index] = now + delay + length + release
	end
end
