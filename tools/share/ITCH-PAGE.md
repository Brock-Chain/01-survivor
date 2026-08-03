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
