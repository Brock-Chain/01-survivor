# 01-survivor

Micro arena survivor (Vampire-Survivors-lite) in Godot 4.7.1, GDScript. Game 1 of a 3-game learning roadmap; its "pick 1 of 3 upgrades" loop is deliberate rehearsal for a future deckbuilder. Ship target 2026-08-14: web + Windows on itch.io. **TODO.md is the source of truth for milestones and scope** — read it at session start, update it at session end.

## Commands (from this folder)

Engine: `..\..\engine\Godot_v4.7.1-stable_win64_console.exe` (always the `_console` exe).

```powershell
# after any external file changes
<console.exe> --headless --import --path .
# smoke test (~5s game time); success = exit 0 AND no SCRIPT ERROR/ERROR in output.
# KNOWN-BENIGN exception: "ERROR: N resources still in use at exit" — the audio
# server holds every stream that PLAYED during the session past the leak check
# (engine teardown ordering; _exit_tree nulling proved useless). Anything else is real.
<console.exe> --headless --path . --quit-after 300
# tests (must be green before every push)
<console.exe> --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# screenshot of the running game → Read the PNG (dir .ai\ is gitignored)
<console.exe> --path . -w --resolution 1280x720 -- --screenshot=<abs>/.ai/shot.png --shot-frame=30
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
