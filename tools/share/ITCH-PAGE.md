# itch.io page settings — BESTAGON

The exact values to enter at <https://itch.io/game/new>. Written for the
**restricted playtest** upload; the "at ship" column is what changes for M8.

Verified against itch's own limits before first upload: the web zip is 11 files,
42.6 MB extracted, largest single file 37.7 MB. The ceilings are 1000 files,
500 MB extracted, 200 MB per file — so there is a lot of headroom.

| Field | Playtest value | At ship (M8) |
|---|---|---|
| Title | `BESTAGON` | same |
| Project URL | `bestagon` | same |
| Short description | `A micro arena survivor. Five minutes to win. Something worse waits at ten.` | same |
| Classification | Games | same |
| Kind of project | **HTML** | same |
| Release status | **In development** | Released |
| Pricing | **No payments** | same |
| Visibility | **Restricted** + password | Public |

## The upload

Upload `builds/BESTAGON-web-<date>.zip`, then tick **"This file will be played
in the browser"**. That checkbox is the whole thing — without it the zip is just
a download.

**Embed options**

- Embed in page, viewport **1280 x 720** (the game renders a 640x360 viewport
  and scales up 2x cleanly, so this is the size it was designed against)
- **Fullscreen button**: on
- **Click to play**: on (leave default)
- **Mobile friendly**: off — it is keyboard-only
- **SharedArrayBuffer support**: **OFF**. This build is single-threaded
  (`Emscripten, single-threaded, no GDExtension support` in the browser
  console), so it does not need cross-origin isolation. Turning it on is the
  most common way a working Godot web upload starts failing.

Optionally also attach `BESTAGON-windows-<date>.zip` as a plain download for
anyone who would rather have the .exe — do **not** tick "played in the browser"
on that one.

## Sharing it privately

**Restricted + password** is the right setting for a playtest. Restricted pages
do not appear in itch's browse or search, are not indexed by external search
engines, and the password lets someone in without needing an itch.io account of
their own. The password can be embedded in the link so the tester never has to
type it.

Draft mode is *not* the right choice here: it is meant for editors, and itch's
own docs say others cannot download or purchase from it.

## AI generation disclosure — YES

itch's field reads: *"disclose if this project contains content produced by
generative AI tools such as LLMs, ChatGPT, Midjourney, Stable Diffusion, etc.,
**even if you hand-edited it**."* Answer **Yes**. Decided 2026-08-02, recorded
here so it is not re-argued at ship.

The reasoning, because the parts are not all the same:

- **Code and player-visible text** — written by an LLM and shipped in the .pck.
  This alone decides the answer.
- **Sprites (`tools/gen_assets.py`) and music (Strudel)** — deterministic,
  self-contained algorithms with no model and no dataset at render time, which
  is squarely itch's stated carve-out. But both scripts were LLM-authored, so
  the output is downstream of generative AI. Genuinely arguable either way, and
  it does not matter: the line above already settles it.

**Sub-classification (mandatory once Yes): tick all four** — Graphics, Sounds,
Text & Dialog, Code.

- **Code** — all GDScript. Not arguable.
- **Text & Dialog** — 45 upgrade names and descriptions, the title copy, the
  death-screen lines, the unlock blurbs, the true ending. The game's entire
  written surface. This is the one that is easy to forget and hardest to defend
  omitting.
- **Sounds** — no audio model ran, but the chord progressions, basslines, drum
  patterns and the four-stem intensity structure were composed by an LLM and
  then written as Strudel code. Composition is the AI part; rendering is not.
- **Graphics** — the weakest case and still worth ticking. `gen_assets.py` is
  PIL drawing polygons, bolts and chevrons with a glow pass: no model, no
  dataset. But the shapes, palette and glow were an LLM's choices, and the form
  does not distinguish "a model made the image" from "a model wrote the code
  that made the image."

The asymmetry is what decides it: under-tagging risks delisting, which itch
states outright; over-tagging costs a browse filter already accepted by
answering Yes.

No image, audio, or voice model output ships in this game. That is a materially
different position from prompt-generated art, and the page description says so
rather than leaving people to assume the tag means what it usually means.

Cost of disclosing: the project appears on itch's **AI Assisted** browse page.
Zero while Restricted (restricted projects are not on browse pages at all);
real at ship, where some jams disallow AI-assisted entries. Weighed against
itch's own warning that mis-tagging can result in delisting, and against this
project's premise being AI-assisted development in the first place.

## Genre and tags

- **Genre**: Action
- **Tags** (max 10, and itch asks you not to repeat the genre or platform):
  `survivors-like`, `roguelite`, `bullet-hell`, `arena`, `minimalist`, `neon`,
  `godot`

## Page description (paste as-is)

> A micro arena survivor built in Godot. Move, and your weapons fire themselves;
> every few levels you pick one upgrade out of three.
>
> Survive five minutes and beat what shows up, and you have won. Keep going, and
> something worse arrives at ten.
>
> **Controls** — WASD or arrows to move, SPACE to dash (earned), ESC to pause,
> M to mute, R to restart.
>
> Everything in it is generated: every sprite is drawn by a Python script in the
> repo, and every sound and music stem is written in Strudel. No third-party
> assets.

## Known-untuned, if anyone asks

The 10:00 fight's length and the difficulty of the last few minutes are first
estimates from bot soaks, awaiting a real playtest — see `TODO.md` 7.9.
