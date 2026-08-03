# tools/strudel — the offline renderer

Turns `audio_src/*.strudel` pattern code into audio, headless and deterministic. This is what makes
the `.ogg` files under `assets/audio/` **build artifacts** rather than binaries with no source.

```bash
npm install                 # once, here. ~85 packages, a few seconds
```

Then from the repo root:

```powershell
python tools/build_music.py         # re-renders whatever changed
python tools/build_sfx.py
```

`build_music.py` finds this folder on its own. Nothing needs an environment variable and nothing
contains a path to anybody's machine — see `tools/strudel_renderer.py` for the resolution order.

**Verified 2026-08-03:** a clean `npm install` in this folder, then re-rendering `victory.strudel`,
reproduced the existing `audio_src/victory.wav` **byte for byte** (sha256
`dddd8b8e…`, 1,993,364 bytes). The renderer seeds its RNG (`--seed`, default 12345) precisely so
that holds — superdough generates its reverb impulse response from `Math.random`, so without the
seed every render differed and nothing downstream could be compared or cached.

## What is here

| File | What |
|---|---|
| `render_superdough.mjs` | Drives the real Strudel engine offline via `OfflineAudioContext`, so a render matches what strudel.cc plays. Emits the `.wav` plus a `.events.json` note dump |
| `soundfont_loader.mjs` | Resolves `gm_*` soundfont instruments for the renderer |
| `package.json` · `package-lock.json` | Declare the dependencies. `npm install` fetches them |

`node_modules/` is **not** committed — it is ~67 MB and it is not ours to redistribute. It is
gitignored, and `npm install` rebuilds it exactly from the lockfile.

## Licensing — the boundary, stated plainly

The two `.mjs` files are **ours**, under this repository's [MIT licence](../../LICENSE), like
everything else here. They contain no third-party source.

`npm install` fetches packages that are **AGPL-3.0-or-later** — `@strudel/core`, `mini`,
`transpiler`, `tonal`, `soundfonts`, and `superdough` (plus BSD-3-Clause `node-web-audio-api`).
Three things about that, because "AGPL" tends to end conversations that should continue:

- **This repository does not redistribute them.** `package.json` names them; npm delivers them from
  the registry to your machine, under their own licence, with their own terms intact. Declaring a
  dependency is not conveying it — which is why permissively-licensed projects depend on copyleft
  build tooling all the time.
- **Your local install is yours.** Combining our script with those packages on your own machine, to
  build audio for yourself, is private use. No obligation is triggered by running this.
- **The game is untouched by any of it.** Godot plays `.ogg` files; it never links, bundles or ships
  a line of Strudel. Program output is not a derivative of the program, so the music is an original
  work of this project — see [`assets/ATTRIBUTION.md`](../../assets/ATTRIBUTION.md).

If you fork this and start redistributing the AGPL packages themselves — vendoring `node_modules`,
say, or publishing a bundle — that is a different act with different obligations. Don't.

Upstream for changes to the two `.mjs` files is the private `song-to-strudel` tooling they were
extracted from; the workspace's canonical copy is `hub/tools/strudel-render/`. Keep them in step.
