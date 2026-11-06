# Bunnyball — plan to finish development

Derived from a full read of the repo at commit `fefe1ed` ("transfer repo", 20 Jun 2025):
5 Lua files totalling 2,247 lines, 652 KB of assets, plus `resources/` (source art, promo)
and `screenshots/`. Runtime claims in the review came from reading the code, not from
running it — there was no Playdate SDK on the reviewing machine and no build config in the
repo.

## Amendments

Two changes to this plan, agreed after the review. They apply to the phases named, and
everything else in the plan stands.

1. **Crank input is dropped for now.** Throw speed is instead controlled by press-and-hold
   of the throw button, scaled by the current character's strength stat. This replaces the
   crank item in Phase 3.
2. **Everything else in the plan stands.**

## Phase 0 — Make it buildable

Done. `source/pdxinfo`, a `Makefile` wrapping `pdc`, a `.gitignore` entry for the built
bundle, a real `README.md`, and these notes moved to `docs/`.

The build has not been run yet: Panic ships the Linux SDK for x86_64 only, and the machine
this was prepared on is arm64. Run `make` on a machine with the SDK to confirm it produces
`Bunnyball.pdx` and that the game reaches the main menu in the Simulator.

## Phase 1 — Fix what is broken

- `hit_palyer` typo in `characters.lua` (8 of 9 characters) — `player_hit()` reads
  `hit_player` and passes nil to `setImage`, so being hit as anything but Fluff errors.
- Scores soft-lock: the `scores` scene prints a debug line and never changes scene.
  `save_score()` is entirely commented out and `progress['scores']` is never written.
- Hard AI nil index: `opponent_act_hard` takes `balls_available[1]` with no empty check.
- Locked characters are selectable: `select_character` confirms with A without checking
  `in_table(...)`.
- Character unlock is a stub: `character_unlock = false` is a typo'd global that is never
  read, so `new_character_unlocked` is always false and the unlock path is dead.
- `opponent_no` is only reset after a tournament is *completed*, so losing and returning to
  the menu starts the next tournament at opponent 2 or 3.
- `point_total` is never reset when a new tournament starts, so it carries between runs.
- `pd.datastore.read` is trusted to return a table; a corrupt save errors on
  `progress['tournament']`. `gameWillSleep`/`gameWillTerminate` write `progress` even when
  it is nil.
- Remove debug leftovers: `pd.drawFPS(10, 10)`, the `print` calls, the `VERSION` global.

## Phase 2 — Complete the core loop

Done, on branch `phase-2-core-loop`. The rounds, per-tournament rules and pause menu items
that were listed under Phase 4 were pulled forward into this phase, so Phase 4 is now empty
apart from what Phase 3 leaves behind.

- **Rounds.** A match is best of three: the first side to win two rounds takes it. Each round
  is the old single life-bar race to zero. Between rounds health, ball positions and both
  fighters are reset, and the 3-2-1-GO countdown runs again. The HUD shows `ROUND n` and the
  round score (`player - opponent`) in the light box at the top centre of the pitch.
  `ROUNDS_TO_WIN` in `match.lua` is the tunable.
- **Scoring and persistence.** `save_score()` keeps the best run per tournament/character
  pair in `progress.scores`, keyed `'<tournament>|<character>'`, storing points, elapsed
  seconds and hearts lost. `STATS['elapsed']` accumulates play time across the rounds of a
  match; `STATS['hearts_lost']` counts hits taken. Both reset at tournament start, like
  `point_total`. `load_progress()` wraps the datastore read in `pcall` and repairs a missing
  or malformed table instead of erroring.
- **Scores screen.** Lists every saved score (tournament, animal, points, time, hearts lost),
  six rows at a time, Up/Down to scroll, A or B back to the main menu.
  **Pending art:** the scores screen background does not exist yet. ガレス will supply it;
  drop it in as `assets/backgrounds/scores.png` and change the one `gfx.image.new` call in
  `scores()` in `main.lua`. Until then the screen uses `assets/backgrounds/blank` and draws
  its text straight onto the cleared screen.
- **Character unlocking.** Beating a tournament adds that tournament's first opponent to
  `progress.characters` and sets `new_character_unlocked`, which `tournament_end()` now
  reads, so the "ANIMAL UNLOCKED" box fires. `TOURNAMENT_MATCHES.house` is now
  `{'hamster', 'bunny', 'bird'}` so the first unlock is a character the player does not
  already have; garden and park already started with an unowned character. The typo'd
  `character_unlock` global is gone.
- **Per-tournament rules.** Rule 2 (garden): a ball that has been thrown and then left
  unclaimed for `BALL_UNCLAIMED_SECONDS` (5) moves to the other side of the field. Rule 3
  (park): no healing between rounds — the side that won the round keeps the hearts it has
  left, the side that lost is restored to a full bar (a round ends at zero hearts, so
  carrying that over would end the next round immediately).
- **Pause menu.** `gameWillPause` opens an overlay with Resume / Forfeit / Quit; Up/Down
  moves, A chooses, B resumes. While it is up, `pd.update` returns before any scene logic and
  before `pd.timer.updateTimers()`, so the match and its timers are frozen. Forfeit tears the
  match down and returns to tournament select; Quit saves the run and returns to the main
  menu.
- **Mid-run save.** `progress.run` holds tournament, opponent number, character and the
  run's running totals, written at run start and after each win. Relaunching resumes it.
  `gameWillResume` no longer re-reads the datastore over the in-memory `progress`; it only
  reads when there is nothing in memory, and it re-bases the match clock so time spent in
  the system menu is not counted.

Design decisions taken here:

- Round-win condition: first to 2 rounds, so a match is at most 3 rounds. A round is won by
  emptying the opponent's life bar, exactly as the old single-round match was.
- `BALL_UNCLAIMED_SECONDS = 5`. The count only starts once a ball has been thrown, so the
  balls laid out at the start of a round are not swept across the field before play begins.
- The pause overlay is reached through the system menu (`gameWillPause`), not a button in
  the match, because B is reserved for Phase 3.
- `TOURNAMENT_MATCHES.house` keeps bunny as its second opponent rather than dropping it, so
  the roster and the podium screen are unchanged.

## Phase 3 — Throw control, dash and sound effects

Done, on branch `phase-3-throw-and-sound`. Crank input is dropped entirely: no crank
handling was added anywhere.

- **Press-and-hold throw.** Holding A with a ball charges the throw; releasing A throws.
  Charge accumulates from 0 to `CHARGE_MAX_SECONDS` (1.0s) and is clamped. The throw time
  is `(6000 / strength) * (1 + CHARGE_SLOWEST_FACTOR * (1 - charge_ratio))`, where
  `charge_ratio` is charge / `CHARGE_MAX_SECONDS`. A full charge throws at the old fixed
  speed; a tap is 1.5x slower (`CHARGE_SLOWEST_FACTOR` 0.5), still enough to cross the
  field.
  The AI keeps its fixed `6000 / strength` throw.
- **Aim.** While charging, Up/Down moves the throw's landing point in 15px steps from the
  opponent's line (`top_of_field`, 95) up to `AIM_MAX_OFFSET` (30) short of it, i.e. three
  settings: full field, mid, short. The ball's end y is `top_of_field + aim`.
- **Power meter and aim on the HUD.** A 170x26 white panel at (100, 215) holding the
  existing `assets/bar/0`–`bar/6` stat bars as a 7-step power meter, plus three aim
  notches (filled = selected) and the small font's `AIM` label. No new art.
- **B = dash.** B while holding Left or Right gives `DASH_SPEED_MULTIPLIER` (3x) speed for
  `DASH_SECONDS` (0.15s), then a `DASH_COOLDOWN_SECONDS` (0.6s) cooldown. Reuses the
  existing run frames. B in a match is only the dash; the pause overlay's B-to-resume and
  the menus' B-to-back are untouched.
- **Sound effects.** New `source/sound.lua` builds every effect from
  `playdate.sound.synth` — square, triangle, sawtooth and noise waveforms with short
  ADSR envelopes. No audio files. Effects: `menu_move`, `menu_select`, `menu_back`,
  `ball_pickup`, `throw` (pitch scaled by charge), `ball_hit`, `player_hit`,
  `opponent_hit`, `countdown_tick`, `go`, `round_win`, `round_lose`, `match_win`,
  `match_lose`, `character_unlock`. `SOUND_VOLUME` (0.4) scales everything and
  `SOUND_MUTED` silences it, both in `sound.lua`. Notes are played from a pool of 8
  synths, because a synth holds only one queued note.

Design decisions taken here:

- Charge curve is linear in time, and the throw time is linear in charge. A full charge
  reproduces the pre-Phase-3 throw exactly, so the feel of a fully charged throw is the
  old throw.
- Aim is a landing-point offset rather than a lob height: the ball still travels in a
  straight line along y, it just stops short. That needed one supporting change — a ball
  is now "reachable" by a side when it has come to rest anywhere in that side's half
  (`ball_resting_on_side`), not only when it sits on the line at y 95 or 185. Without it
  an aimed ball would be unreachable by either side. The AI's ball scans use the same
  helper, so it chases aimed balls too.
- The dash is a speed multiplier on the existing movement, not a separate move, so it
  cannot leave the field bounds or desync the carried ball.
- Sound is wired in at the existing call sites only; no game logic was changed to make
  room for it. `play_sound` is a no-op when muted, so call sites need no guards.

Still pending from ガレス: music (the `music` fileplayer and `change_music()` are left in
place, unused, and the Dedediego credit stays on the credits screen) and title/logo art
(the runtime-drawn title is unchanged).

## Phase 4 — Low-risk clean-up

Done, on branch `phase-4-low-risk`. The remaining work was split into a low-risk half
(this phase) and a high-risk half (Phase 5). Phase 4 is limited to changes that cannot
alter gameplay logic, AI behaviour, movement, field maths or scene dispatch.

- **`select_character` background cached.** The 400x240 image and its `pushContext`/
  `drawText` calls for the `HP`/`STR`/`SPD` labels now run only when
  `background_sprite == nil`, the same guard the other scenes use. The highlighted
  character's name changes with the cursor, so it is drawn into its own small image,
  cached per name and rebuilt only when the highlighted name changes.
- **Countdown image cached.** `countdown()` keeps one image per word (`3`, `2`, `1`,
  `GO!`, `STOP!`) in a table and reuses it, so the 3-second end sequence no longer
  rebuilds `STOP!` every frame.
- **Explicit `setZIndex` in `match.lua`.** Named constants `Z_BACKGROUND` (1),
  `Z_OPPONENT` (2), `Z_PITCH` (3), `Z_HEALTH` (4), `Z_BALLS` (5), `Z_PLAYER` (6),
  `Z_HUD` (7), `Z_COUNTDOWN` (8), `Z_CHARGE` (9) are applied where each sprite is added.
  They reproduce the order the game already produced from insertion order, so the
  visual result is unchanged: the pitch overlay still covers the opponent's feet, and
  the balls, player, HUD, countdown and power meter still draw over the pitch.
- **Dead code.** `podium_sprite = nill` in `tournament.lua` is now `nil`. The shadowed
  `local player_health_sprites` inside `play_match` no longer exists: Phase 2 replaced
  that block with `build_health_bars()`, so there was nothing left to remove.
- **Bunny's run animation.** `run_sequence` now repeats each of its 4 frames twice
  (8 entries) like every other character, instead of three times (12 entries), so Fluff
  animates at the same rate as the rest of the cast.
- **Asset hygiene.** `animals/hamster.png` (byte-identical to `hamster_idle.png`) and
  `animals/fetterCPU_idle.png` (byte-identical to `ferretCPU_idle.png`) are deleted.
  Nothing in `source/` referenced either name, literal or concatenated. Left in place:
  `backgrounds/credits_menu.png`, `backgrounds/tournament_end.png`,
  `arrow_right_long.png` and `tortoise_player_run_01`–`04` (the tortoise frames are
  needed for Phase 5). The `bugs_hit.png` / `bugsCPU_hit.png` duplication is untouched.

Not verified by running the game: the Playdate SDK is x86_64 only and the machine this
was prepared on is arm64. Every changed call site was read, and all six Lua files pass
`luac -p` on a copy with `<const>` and `+=`/`-=` mechanically stripped.

## Phase 5 — High-risk work

Done, on branch `phase-5-high-risk`, based on `phase-4-low-risk`.

- **Named layout/timing constants.** Field edges and midpoint, health-bar heart
  positions and spacing, all ten ball start positions, and the five-second intro
  delay are named constants. The AI midpoint checks now use the shared field
  midpoint rather than querying display width. Existing numeric values are retained.
- **Deduplicated logic.** Medium/hard AI wandering and hard-AI retreat destinations
  share helpers. Player/opponent movement shares an animation/movement routine;
  player-side assets fall back to the regular run sequence for other characters.
  Health bars share a directional builder while preserving their separate heart
  assets and positions. `menu.lua` uses `draw_centered` for repeated centered text.
- **Tortoise player frames.** Tortoise player movement uses the existing
  `tortoise_player_run_01`–`04` image assets; the CPU continues using the CPU-side
  sequence.
- **Scene dispatch.** `pd.update` now dispatches exact scene names through a handler
  table. The `winner_*` and `finished_tournament_*` states are distinct, avoiding
  substring collisions; transitions and the existing update/timer order remain in
  the same branches.
- **Menu refresh rate deferred.** No `setRefreshRate` call is added. Menus run in the
  same `pd.update` loop as scene transitions and the pause/clear-save overlays, and
  there is no isolated menu loop or measured timing evidence to establish that
  changing refresh rate would leave input and timer behavior unchanged. Keeping the
  default is the safer choice.

The broader globals and lint/CI observations from the original review are not part
of the accepted Phase 5 implementation scope. No other Phase 3 work was changed.

The game was not built or run: the Playdate SDK is x86_64-only, while HomeServer is
arm64. All six Lua source files pass `luac -p` on temporary copies after mechanically
removing Playdate-specific `<const>` and compound-assignment syntax. This checks
ordinary Lua syntax only, not Playdate API behavior or runtime visuals; run the
Simulator and hardware checks on the SDK-equipped Windows machine.

## Still pending from ガレス

- **Music.** No `.pda`/`.wav`/`.mp3` in the repo. `change_music()` is never called and the
  `music` fileplayer is created and never loaded. ガレス will supply the wav files; then
  load them and wire `change_music()` into the scene changes. The credits screen credits
  "music from Dedediego" for music that does not exist yet; the credit stays until the
  music arrives.
- **Title/logo art.** The title is drawn as runtime text. ガレス will supply the
  background and logo art; until then the runtime-drawn title stays as it is. An attract
  mode and a launch image are still open.
- **Scores screen background.** The screen uses `assets/backgrounds/blank` and draws its
  text straight onto the cleared screen. Drop the art in as
  `assets/backgrounds/scores.png` and change the one `gfx.image.new` call in `scores()`
  in `main.lua`.
- **Pause/forfeit art.** The pause overlay is drawn with the bitmap fonts.

## Asset notes

- Present and good: nine complete character sets (idle, CPU idle, hit, CPU hit, 4 run
  frames, 31×31 icon), three pitch backgrounds plus a shared overlay, three tournament intro
  backgrounds, three tournament-select backgrounds, menu/character-select/credits/blank
  backgrounds, match-end banner, medal and score box, podium and unlock notification, health
  hearts and blocks, seven stat-bar states, five bitmap fonts, arrows, padlocks, ball.
- Missing: music, title/logo art, the scores screen background (all pending from ガレス),
  and dedicated pause/forfeit art (the pause overlay is drawn with the bitmap fonts).
  Sound effects need no assets: they are synthesised in `source/sound.lua`.
- `bugs_hit.png` is byte-identical to `bugsCPU_hit.png`, and `bugs_idle.png` to
  `bugsCPU_idle.png`.
- The duplicate/typo'd files `hamster.png` and `fetterCPU_idle.png` were deleted in
  Phase 4.
- Unused, kept deliberately: `backgrounds/credits_menu.png`,
  `backgrounds/tournament_end.png` (may serve pending art) and `arrow_right_long.png`;
  `tortoise_player_run_01–04` are kept for Phase 5.
- `resources/` holds the `.ase`/`.aseprite` sources and promo art. They are not part of the
  build and nothing says which is the source of truth.
