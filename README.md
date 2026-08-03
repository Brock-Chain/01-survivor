# BESTAGON

A micro arena survivor built in Godot 4.7.1 and GDScript. Move; your weapons fire themselves. Every
third level you pick one upgrade out of three. Survive five minutes and beat what shows up and you
have won — keep going, and something worse arrives at ten.

**Every asset in this repository is generated.** Every sprite is drawn by a Python script
(`tools/gen_assets.py`), and every sound effect and music stem is written as
[Strudel](https://strudel.cc) pattern code (`audio_src/*.strudel`) and rendered to `.ogg`. There are
no third-party assets — see [`assets/ATTRIBUTION.md`](assets/ATTRIBUTION.md).

> **And regenerable from a clone, which is a stronger claim than "generated".** Sprites rebuild with
> Python and Pillow; audio rebuilds with one `npm install` (see
> [Rebuilding the audio](#rebuilding-the-audio)). Both generators are committed here, neither
> contains a path to anybody's machine, and the audio renderer is seeded — re-rendering a stem
> reproduces the committed file **byte for byte**.

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
# THE GATE: import + 123 unit tests + gameplay smoke + the UI layout harness,
# with the error grep and the known-benign-noise list built in. Run this, not the pieces.
powershell -File tools/verify.ps1
powershell -File tools/verify.ps1 soak      # + an 11-minute run clearing both boss events

# build and package both platforms for release
powershell -File tools/package.ps1
```

Success is **exit 0 AND no `SCRIPT ERROR`/`ERROR` in stdout** — Godot's exit codes do not reliably
reflect script failures, so the gate greps.

### Rebuilding the audio

Only needed if you want to **change** the music or SFX — the `.ogg` files the game plays are
committed.

```powershell
cd tools/strudel; npm install; cd ../..    # once per clone, a few seconds
python tools/build_music.py                # re-renders whatever changed
python tools/build_sfx.py
```

The renderer ships in [`tools/strudel/`](tools/strudel/) — Strudel pattern code to `.wav`, headless
and **seeded**, so renders are byte-identical run to run. Verified: a clean install re-rendered
`victory.strudel` into a byte-for-byte copy of the committed `victory.wav`. `npm install` fetches
AGPL-3.0 packages from the registry, which this repo declares but does not redistribute
(`node_modules/` is gitignored); the boundary is written out in
[`tools/strudel/README.md`](tools/strudel/README.md). The game never links any of it — Godot plays
`.ogg` files.

`$STRUDEL_RENDERER` overrides the location if you keep a checkout elsewhere. Run either script when
it cannot resolve and it prints every path it looked in — it does not fail silently, and it contains
no absolute path to fail with. `verify.ps1` enforces that last part.

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

## Licence

[MIT](LICENSE) — code and generated assets alike. Every sprite, sound and music stem here is
produced by a committed generator, so there is no third-party asset whose terms could conflict with
that; see [`assets/ATTRIBUTION.md`](assets/ATTRIBUTION.md).

One boundary worth stating rather than leaving implicit: the audio renderer in `tools/strudel/` is
ours and MIT like the rest, but `npm install` fetches **AGPL-3.0** packages from the npm registry.
This repo declares those dependencies and never redistributes them, and the game links none of them
— Godot plays `.ogg` files. Detail in [`tools/strudel/README.md`](tools/strudel/README.md).
