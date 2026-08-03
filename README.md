# BESTAGON

A micro arena survivor built in Godot 4.7.1 and GDScript. Move; your weapons fire themselves. Every
third level you pick one upgrade out of three. Survive five minutes and beat what shows up and you
have won — keep going, and something worse arrives at ten.

**Every asset in this repository is generated.** Every sprite is drawn by a Python script
(`tools/gen_assets.py`), and every sound effect and music stem is written as
[Strudel](https://strudel.cc) pattern code and rendered to `.ogg`. There are no third-party assets —
see [`assets/ATTRIBUTION.md`](assets/ATTRIBUTION.md).

> Built with Claude as a deliberate experiment in AI-assisted development: the code, the generators
> and the copy are largely LLM-written, and the design decisions, direction and playtesting are not.
> No image or audio model was used — the art and music are code.

## Play it

- **Browser** — the itch.io page (currently a restricted playtest build)
- **Windows** — a standalone `.exe`; unsigned, so SmartScreen will want "More info → Run anyway"

Controls: **WASD/arrows** move · **SPACE** dash (earned by beating the 5:00 boss) · **ESC or P**
pause · **M** mute · **R** restart.

> A web build **cannot** be run by double-clicking `index.html` — browsers refuse to fetch the
> `.wasm` and `.pck` from a `file://` page. Serve it over HTTP; the packaged zip ships a
> `START-HERE.bat` that does exactly that.

## Running it from source

The engine binary lives outside this repo. Use the `_console` executable for everything automated —
the plain one detaches from the terminal and you lose all output.

```powershell
# THE GATE: import + 117 unit tests + gameplay smoke + the UI layout harness,
# with the error grep and the known-benign-noise list built in. Run this, not the pieces.
powershell -File tools/verify.ps1
powershell -File tools/verify.ps1 soak      # + an 11-minute run clearing both boss events

# build and package both platforms for release
powershell -File tools/package.ps1
```

Success is **exit 0 AND no `SCRIPT ERROR`/`ERROR` in stdout** — Godot's exit codes do not reliably
reflect script failures, so the gate greps.

## Layout

| Path | What |
|---|---|
| `scenes/` | one folder per feature; each script sits next to its `.tscn` |
| `scripts/` | autoloads and pure utilities |
| `resources/` | game data as `.tres` — enemies, upgrades, waves. Never dictionaries or JSON |
| `assets/` | generated sprites, shaders and audio |
| `tools/` | the asset/audio/upgrade generators, the verify gate, the packaging script |
| `tests/` | GUT unit tests, pure logic only |
| `scenes/dev/` | juice lab and the UI layout harness; excluded from exports |

## Conventions

Static typing everywhere. Call down, signal up. Game data lives in Resources, never in
dictionaries. Tests cover logic, never scenes — which is why UI that must fit the 640×360 viewport
is guarded by a measuring harness (`scenes/dev/pause_layout_check.gd`) rather than by eye.

## Documents

- [`BRIEF.md`](BRIEF.md) — the spec: prime directive, what counts as a defect, acceptance criteria
- [`TODO.md`](TODO.md) — milestones and scope, the source of truth for what is done
- [`DECISIONS.md`](DECISIONS.md) — why things are the way they are, with the measurements that
  forced them

Game 1 of a three-game learning roadmap; its pick-one-of-three loop is deliberate rehearsal for a
later deckbuilder.
