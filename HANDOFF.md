# Session handoff — 2026-08-02

Transient. Delete once the next session has absorbed it. `TODO.md` is the durable
source of truth; `BRIEF.md` is the spec; `DECISIONS.md` is why things are the way
they are.

## Where we are

**V1.Final, shipping as "PRISM".** Agreed cycle:

```
M6 (audio) → M6.5 design review → grill on findings
  → ONE apply pass (findings + the second boss, built together)
  → M7 ship → hub/memory capture → V2
```

Done this session: rarity system (5 tiers, 38 upgrades, 11 unique mechanics),
superlinear XP, three soundtracks with adaptive layers + rotation, 64s escalating
title theme, victory merge, score viewer, power-ups, pause/build sheet + QOL,
Splitter and Ram. 79/79 GUT green.

## Do next, in order

1. **SFX pass.** Replace all 8 stdlib WAVs in Strudel, add ~8 missing cues
   (boss telegraph — currently it plays the LEVEL-UP jingle, which teaches the
   player exactly the wrong thing — boss spawn, boss death, enemy bolt, power-up
   pickup, health pickup, shield expiring, crit), plus pitch-varied sets for the
   sounds heard hundreds of times (hit, shoot, pop). `Sfx` autoload needs
   variation support. Target ~20 sounds.
2. **More shooting variants** (playtest ask, not yet started). See below.
3. **Rename everything to PRISM** — title screen, window title, export presets,
   README, itch page.
4. **M6.5** — the design review. Shape is in `hub/pipeline/game-milestones.md`.
5. **M7** — ship. The human owns the itch.io account; prepare everything up to
   the upload.

## Open playtest feedback, unaddressed

- **"We need more shooting variants."** Only one projectile weapon plus the
  orbital. Candidates: a spread/shotgun weapon, a beam, a mortar/lob. The
  `WeaponResource` model already supports a second `Kind`; adding a third is the
  intended extension point.
- **Title theme peak** was revised this session to eight 4-bar steps with
  monotonically opening filters. NOT yet heard by the human — verify first.
- **Boss HP** (`resources/enemies/prism.tres`, 900 × 2 at 5:00) is tuned from
  one measured human DPS figure, never re-verified after the rarity change.
  Rarity changed player power; re-measure.
- **Rarity feel** — the distribution is verified by bot, never by a human. Does
  pulling a Legendary actually feel like anything?

## Two failure modes that bit repeatedly — read this

1. **A silent string-replace.** Authoring edits via `str.replace` that does not
   match reports nothing and leaves plausible code that never runs. It shipped
   twice in one session: the rarity card visuals (`_apply_rarity` defined, never
   called) and the music selector (patch landed inside the wrong function).
   **Grep the CALL SITE, not the definition, after every scripted edit.**
2. **GUT does not load scene scripts.** A parse/compile error in a `.gd` attached
   to a scene passes the whole unit suite. Only the headless smoke run catches
   it. Always run both:
   ```
   <console.exe> --headless --path . --quit-after 300
   ```

## Commands

```bash
# game (from games/01-survivor)
../../engine/Godot_v4.7.1-stable_win64_console.exe --headless --path . --import
../../engine/Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 300
../../engine/Godot_v4.7.1-stable_win64_console.exe --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# soak (fixed-fps is mandatory; name the scene, the title waits for a click)
../../engine/Godot_v4.7.1-stable_win64_console.exe --headless --path . res://scenes/main/main.tscn \
  --fixed-fps 60 --quit-after 22000 -- --dev-godmode --dev-stats --dev-autopick --dev-autocontinue

# music: edit audio_src/*.strudel, then
python tools/build_music.py            # --force to rebuild everything

# SONG VISUALISER  (this is the one that was asked about)
python tools/score_viewer.py           # all tracks -> .ai/score.html
python tools/score_viewer.py gameplay  # one track  -> .ai/score_gameplay.html
#   then open the .html in a browser. Roll/Code tabs; Code shows the Strudel
#   highlighting bar-by-bar as it plays.

# telemetry from real playtests
python tools/analyze_telemetry.py
```

## Suggested opening prompt for the next session

> Continuing V1.Final of the survivor game (shipping as PRISM) in
> `D:\Github\Godot\games\01-survivor`. Read `HANDOFF.md`, `TODO.md` and
> `BRIEF.md` first. Next up is the SFX pass (M6), then more shooting variants,
> then the rename to PRISM, then the M6.5 design review whose shape is in
> `hub/pipeline/game-milestones.md`. I'll playtest just before M6.5.
