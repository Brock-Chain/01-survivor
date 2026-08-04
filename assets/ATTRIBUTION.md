# Asset attribution

**No third-party assets are used.** Every sprite, sound and note in this game originates in this
repository and ships under its licence ([MIT](../LICENSE)).

Two different kinds of origin, and the difference matters:

## Music and SFX — written

The soundtrack is **composed**, not generated. Every piece is an original work, authored as
[Strudel](https://strudel.cc) pattern code in [`audio_src/`](../audio_src/): **38 sources, ~1,125
lines** — 18 for music, 20 for sound effects.

That includes the structure, not just the notes. The four gameplay tracks are each written as **four
separate stems** — bass, drums, arp, lead — of identical length, cps and key, so the game can fade
layers in and out to follow intensity without anything restarting; the tracks are ordered around the
circle of fifths so a switch between them moves by one accidental. Keys, voicings, drum kits,
arrangement and the adaptive architecture are all authored here.

**The renderer is a compiler, not a composer.** `tools/strudel/` turns that source code into `.wav`,
the same way a compiler turns source into a binary. It makes no musical decisions. Point it at a
different `.strudel` file and you get different music, because the music is in the file.

```
python tools/build_music.py     # audio_src/*.strudel  ->  assets/audio/music/*.ogg
python tools/build_sfx.py       # audio_src/sfx/*.strudel -> assets/audio/sfx/*.wav
```

## Sprites, shaders and fonts — generated

Procedural, by a deterministic committed script — there is no hand-drawn art here and no artist to
credit, which is the point of the approach.

```
python tools/gen_assets.py
```

Then reimport in either case (`--headless --import`).

## Reproducibility

Both paths are committed, so **every asset is regenerable from a clone** — the audio needs one
`npm install` in [`tools/strudel/`](../tools/strudel/) first. The renderer is seeded, so a re-render
reproduces the committed file byte for byte (verified 2026-08-03 against `victory.wav`).

`npm install` fetches AGPL-3.0 packages that this repo declares and never redistributes; the
boundary is written out in [`tools/strudel/README.md`](../tools/strudel/README.md). It does not reach
the music: Godot plays `.ogg` files and never links Strudel, so the recordings are original works of
this project exactly like the code that describes them.

## In the repository, but not in the game

"No third-party assets" is a statement about **what ships**. A clone contains one vendored
third-party dependency, and it is worth naming rather than leaving a reader to find it:

| | |
|---|---|
| [`addons/gut/`](../addons/gut/) | **GUT** (Godot Unit Test) by bitwes — the test framework. **MIT**, with its licence committed at [`addons/gut/LICENSE.md`](../addons/gut/LICENSE.md). It also ships 25 font files (Anonymous Pro, Courier Prime, Lobster Two) for its own result GUI, covered by the SIL Open Font Licence at [`addons/gut/fonts/OFL.txt`](../addons/gut/fonts/OFL.txt) |

None of it reaches a player: both export presets carry
`exclude_filter="addons/gut/*, tests/*, scenes/dev/*, builds/*"`, so GUT and its fonts are absent
from the web and Windows builds. It is a development dependency in the same sense as the engine — the
difference is that GUT is small enough to vendor, so it is here rather than resolved.

Nothing above conflicts with this project's [MIT licence](../LICENSE): MIT and OFL both permit
redistribution with their notices intact, and both notices are intact and committed.
