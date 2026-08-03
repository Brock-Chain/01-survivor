# Asset attribution

Every sprite and sound in this game is **generated** — no third-party assets are used. Generated
assets are original works of this project and ship under the repo's licence
([MIT](../LICENSE)).

Two generators, not one:

| Assets | Generator | Regenerate with |
|---|---|---|
| Sprites, shaders, fonts | [tools/gen_assets.py](../tools/gen_assets.py) — deterministic Python, committed here | `python tools/gen_assets.py` |
| Music stems, SFX | [Strudel](https://strudel.cc) pattern code in [audio_src/](../audio_src/), rendered offline | `python tools/build_music.py` · `python tools/build_sfx.py` |

Then reimport (`--headless --import`).

Both generators are committed, so **every asset here is regenerable from a clone** — the audio needs
one `npm install` in [`tools/strudel/`](../tools/strudel/) first, and the renderer is seeded, so a
re-render reproduces the committed file byte for byte.

`npm install` fetches AGPL-3.0 packages that this repo declares but does not redistribute. That
boundary is written out in [`tools/strudel/README.md`](../tools/strudel/README.md) and does not reach
the audio itself: Godot plays `.ogg` files and never links Strudel, so the stems are original works
of this project like everything else here.
