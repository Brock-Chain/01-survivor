# BESTAGON (repo folder `01-survivor`)

Micro arena survivor (Vampire-Survivors-lite) in Godot 4.7.1, GDScript. Game 1 of a 3-game learning roadmap; its "pick 1 of 3 upgrades" loop is deliberate rehearsal for a future deckbuilder. Ships web + Windows on itch.io. **Scope is controlled by content counts and gates, never by a date** — this file used to state a ship target while `TODO.md` stated the opposite, and the two disagreed for the whole project. **TODO.md is the source of truth for milestones and scope** — read it at session start, update it at session end.

## Commands (from this folder)

Engine: `..\..\engine\Godot_v4.7.1-stable_win64_console.exe` (always the `_console` exe).

```powershell
# THE GATE. Run this, not the individual steps: import + tests + gameplay smoke +
# pause-layout harness, with the error grep and the benign-noise list built in.
powershell -File tools/verify.ps1
powershell -File tools/verify.ps1 soak     # + an 11-minute run clearing both boss events

# after any external file changes (verify.ps1 does this first anyway)
<console.exe> --headless --import --path .
# tests (must be green before every push)
<console.exe> --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# GAMEPLAY smoke. The scene MUST be named explicitly: `run/main_scene` is
# title.tscn, so `--headless --path .` boots the TITLE SCREEN, sits there and
# exits 0 no matter what is broken in gameplay. That was the documented gate for
# months and it could not fail (M6.5 review finding 29). Success = exit 0 AND the
# "BESTAGON boot OK" line present AND no SCRIPT ERROR/ERROR.
<console.exe> --headless --path . --fixed-fps 60 res://scenes/main/main.tscn --quit-after 2400
# NOTE: --dev-autopick takes the call_deferred+break path in _check_level_up and
# NEVER calls LevelUpPanel.show_offers, so an autopick soak leaves the level-up
# screen untested. The command above (no autopick) is the one that covers it.
#
# KNOWN-BENIGN at exit: "N resources still in use at exit" (the audio server holds
# every stream that played past the leak check) and "RID allocations of type ...
# leaked at exit" (renderer/physics dummies release after it). Anything else is real.
# screenshot of the running game → Read the PNG (dir .ai\ is gitignored)
# For a GAMEPLAY frame, name main.tscn (run/main_scene is the title) AND pass the dev flags, or the
# run stalls on the level-up panel: --dev-autopilot --dev-autopick --dev-godmode.
<console.exe> --path . -w --resolution 1280x720 -- --screenshot=<abs>/.ai/shot.png --shot-frame=30
# Pose any modal at its worst case and photograph it, through the layout harness. --check-hold picks
# which screen stays up (default true_ending); the capture window is only ~40 frames wide, so a
# --shot-frame past it makes the harness quit first and write nothing.
<console.exe> --path . -w --resolution 1280x720 res://scenes/dev/pause_layout_check.tscn -- --check-hold=victory --screenshot=<abs>/.ai/victory.png --shot-frame=95
# contact sheet — several frames in ONE png, for anything that MOVES (--fixed-fps is mandatory)
<console.exe> --path . -w --resolution 1280x720 --fixed-fps 60 -- --screenshot=<abs>/.ai/sheet.png --shot-frames=1,3,5,7,9,12
# juice lab — one effect, alone, shipped variant vs alternatives (scenes/dev/, excluded from exports)
<console.exe> --path . -w --resolution 1280x720 res://scenes/dev/juice_lab.tscn
<console.exe> --path . -w --resolution 1280x720 --fixed-fps 60 res://scenes/dev/juice_lab.tscn -- --lab-case=hit_flash --lab-variant=1 --screenshot=<abs>/.ai/flash.png --shot-frames=1,3,5,7,9,12
# web export (builds\ is gitignored)
<console.exe> --headless --path . --export-release "Web" builds/web/index.html
```

## Conventions (essentials — full version lives in the private hub)

- Static typing always; `snake_case` files/vars/funcs; one class per file.
- Call down, signal up. Scene scripts live next to their .tscn (`scenes/<feature>/`).
- Game data = custom Resources (.tres) in `resources/` — never dictionaries/JSON.
- Tests in `tests/unit/test_*.gd` (GUT 9.7.1), pure logic only — no scene/UI tests.
- Collision layers: named in Project Settings, never raw numbers in code comments.
- Commit `.uid` files. New scenes/scripts authored by hand: omit `uid=`, run `--import`.

## Structure

`scenes/` per-feature · `scripts/` autoloads+utils · `resources/` .tres data · `assets/` third-party art/audio (keep licenses in `assets/ATTRIBUTION.md`) · `tests/` · `addons/gut` (excluded from exports via preset `exclude_filter`).

## Division of labor

Claude builds and narrates. **Challenge systems marked HUMAN-BUILT in TODO.md are the human's to code** — Claude designs interfaces and reviews, but never writes their implementation.
