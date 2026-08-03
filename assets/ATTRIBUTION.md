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

**The audio renderer is not committed here** and is needed only to *change* the music — the `.ogg`
files it produces are committed and are what the game ships. It imports AGPL-3.0 packages, which is
why it is resolved rather than vendored into an MIT repo; see *Rebuilding the audio* in the
[README](../README.md). None of that reaches the audio itself: Godot plays `.ogg` files and never
links Strudel, so the stems are original works of this project like everything else here.
