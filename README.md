# Bunnyball

A one-on-one ball game for the [Playdate](https://play.date/), inspired by
[Penguin Wars](https://en.wikipedia.org/wiki/Penguin_Wars) on the Game Boy.

Pick up balls and throw them at your opponent until their hearts run out. Work through
three tournaments — House, Garden and Park — each with tougher opponents and a different
AI. Winning a tournament unlocks the next one.

## Controls

| Screen | Controls |
| --- | --- |
| Main menu | Up / Down to move, A to select |
| Tournament select | Left / Right to move, A to select, B to go back |
| Character select | D-pad to move around the 3×3 grid, A to confirm |
| Match | Left / Right to move, A to pick up a ball, A again to throw it |
| Match end | A to continue |
| Credits | A or B to go back |

## Building

You need the [Playdate SDK](https://play.date/dev/) installed, with `pdc` (the Playdate
compiler) on your `PATH`. The SDK is available for macOS, Windows and Linux (x86_64).

Set `PLAYDATE_SDK_PATH` to the SDK directory — `pdc` uses it to find the SDK, and the
`run` target uses it to find the Simulator:

```sh
export PLAYDATE_SDK_PATH=/path/to/PlaydateSDK
export PATH="$PLAYDATE_SDK_PATH/bin:$PATH"
```

Then, from the repo root:

```sh
make
```

That runs:

```sh
pdc source Bunnyball.pdx
```

and produces the `Bunnyball.pdx` bundle in the repo root. `make clean` removes it.

If you would rather not use `make`, the `pdc` line above is the whole build.

## Running in the Playdate Simulator

Open the bundle in the Simulator, either by launching the Simulator and choosing
**File → Open** and selecting `Bunnyball.pdx`, or by dragging the bundle onto the Simulator
window. With `PLAYDATE_SDK_PATH` set you can also do both steps at once:

```sh
make run
```

To run on hardware, sideload the `Bunnyball.pdx` bundle to your Playdate — see
[the Playdate sideloading docs](https://help.play.date/developer/sideloading/).

## Project layout

```
source/            Lua source and assets — this is what pdc compiles
  main.lua         scene loop, save data, system menu
  menu.lua         main menu, credits, tournament select, character select
  tournament.lua   tournament intro, match end, tournament end
  match.lua        the match itself: movement, throwing, collisions, health
  characters.lua   character stats and sprite sets
  pdxinfo          game metadata read by pdc
  assets/          sprites, backgrounds, fonts
docs/design.md     the original design notes
docs/plan.md       the plan for finishing the game
resources/         .ase/.aseprite source art and promo art (not part of the build)
screenshots/       development screenshots and GIFs
```

## Design notes and plan

- [docs/design.md](docs/design.md) — the original design notes for the game.
- [docs/plan.md](docs/plan.md) — what is left to do to finish it, phase by phase.

## Credits

- Game by PangolinPaw (Gareth Murden)
- Art by KuroganeNiello
- Music from Dedediego
- Special thanks to Toad and PizzaDev from the PlaydateSquad

## Licence

No licence has been chosen for this project yet, so all rights are reserved. Add a
`LICENSE` file before publishing or accepting contributions.
