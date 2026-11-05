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

## Phase 2 — Scoring, saves and progression

- Implement `save_score()`: best score per character/tournament pair, persisted.
- Build the scores screen (art does not exist yet).
- Measure elapsed match time; score time to defeat, hearts lost and throws.
- Reset per-run state (`point_total`, `opponent_no`) at tournament start.
- Save in-progress tournament state, and stop `gameWillResume` from clobbering the
  in-memory `progress` with a stale datastore read.
- Make the unlock chain match the data: `TOURNAMENT_MATCHES.house[1]` is `'bunny'`, which is
  already unlocked, so beating the house tournament currently unlocks nothing new.
- Add a confirmation to the destructive "clear save" system menu item.

## Phase 3 — Throw control

- **Press-and-hold throw** (replaces the crank item): holding A charges the throw, release
  throws; charge time maps to throw speed, scaled by the character's `strength` stat.
  Replaces the fixed `6000 / strength` throw time in `player_throw`.
- Give the throw an aim dimension so the player can lead a target.
- Use B in a match (dash, lob or cancel) and in `select_character` (back out).

## Phase 4 — Match structure and rules

- Rounds: a match is currently a single life-bar race to zero. Penguin Wars is round-based;
  add a best-of with a round counter and a reset between rounds.
- Per-tournament rules from the design notes: rule 2 (a ball not picked up for x seconds
  goes to the opponent's side) and rule 3 (no healing between rounds) are unimplemented.
- Pause menu with forfeit, as the design notes specify.

## Phase 5 — Audio

- No audio exists at all: no `.pda`/`.wav`/`.mp3` in the repo. `change_music()` is never
  called and the `music` fileplayer is created and never loaded.
- Add music and sound effects (`playdate.sound.synth` for effects), and wire
  `change_music()` into the scene changes.
- The credits screen credits "music from Dedediego" for music that does not exist yet.

## Phase 6 — Presentation and performance

- Title/logo art: the title is drawn as runtime text. Add a logo, an attract mode and a
  launch image.
- `select_character` allocates a fresh 400×240 image and re-runs `pushContext`/`drawText`
  every frame; `countdown('STOP!')` rebuilds an image every frame during the end sequence.
  Both are avoidable churn on a 168 MHz CPU.
- Add `setZIndex` in `match.lua`; the pitch sprite is added after the opponent, so draw
  order depends on insertion order.
- Consider `pd.display.setRefreshRate` and offscreen/flush usage; everything currently runs
  at the default 30 fps with a full `gfx.clear()` each frame.

## Phase 7 — Code health

- Globals: `STATS`, `VERSION`, `TOURNAMENT_MATCHES`, `ANIMALS`, `CHARACTERS` and roughly
  twenty functions are shared across five files, which makes every rename risky.
- Replace the string-based scene machine (`string.find(scene, 'tournament')` and friends)
  with a table of scene handlers.
- De-duplicate `opponent_act_medium`/`opponent_act_hard`, `player_move`/`opponent_move`, the
  two health-bar builders and the repeated "measure, centre, draw" pattern in `menu.lua`.
- Hoist hardcoded field bounds, health-bar positions, ball start positions and the 5-second
  intro delay into named constants.
- Remove dead code: the shadowed `player_health_sprites` local, the unused
  `tortoise_player_run_*` frames, `podium_sprite = nill`.
- Fix bunny's `run_sequence` repeating each frame 3× while every other character repeats 2×.
- Add a lint config and CI so the `hit_palyer` class of typo is caught.

## Asset notes

- Present and good: nine complete character sets (idle, CPU idle, hit, CPU hit, 4 run
  frames, 31×31 icon), three pitch backgrounds plus a shared overlay, three tournament intro
  backgrounds, three tournament-select backgrounds, menu/character-select/credits/blank
  backgrounds, match-end banner, medal and score box, podium and unlock notification, health
  hearts and blocks, seven stat-bar states, five bitmap fonts, arrows, padlocks, ball.
- Missing: all audio, title/logo art, pause/scores/forfeit screens.
- `bugs_hit.png` is byte-identical to `bugsCPU_hit.png`, and `bugs_idle.png` to
  `bugsCPU_idle.png`.
- Duplicates/typos in the asset folder: `hamster.png` duplicates `hamster_idle.png`;
  `fetterCPU_idle.png` is a typo'd duplicate of `ferretCPU_idle.png`.
- Unused: `backgrounds/credits_menu.png`, `backgrounds/tournament_end.png`,
  `arrow_right_long.png`, `tortoise_player_run_01–04`.
- `resources/` holds the `.ase`/`.aseprite` sources and promo art. They are not part of the
  build and nothing says which is the source of truth.
