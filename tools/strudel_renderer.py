"""Locate the offline Strudel renderer, without hardcoding anyone's disk.

`build_music.py` and `build_sfx.py` both shell out to `render_superdough.mjs` to
turn `audio_src/*.strudel` into audio. That renderer is a separate tool, and it
used to be referenced by an absolute path into a private repo — which made this
repo's claim that its `.ogg` files are regenerable build artifacts FALSE for
everyone who cloned it. Resolution order, first hit wins:

    1. $STRUDEL_RENDERER            an explicit path, overrides everything
    2. tools/strudel/render_superdough.mjs      a copy vendored into this repo
    3. ../../hub/tools/strudel-render/...       the hub's canonical copy

Nothing here is silent: if none resolve, `explain()` prints all three places it
looked and what to do about it.
"""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME = "render_superdough.mjs"

CANDIDATES: list[tuple[str, Path]] = [
    # DELIBERATELY EMPTY, and this comment is the decision rather than a TODO.
    # This repo is MIT; the renderer imports AGPL-3.0 packages (@strudel/*,
    # superdough). Dropping it in here would put an AGPL-adjacent file inside a
    # permissive repo whose clean licence story is the point -- so if it is ever
    # vendored, it goes in this directory WITH ITS OWN LICENSE, named as such in
    # the README. The slot exists so that is a copy plus a LICENSE, not a code
    # change; nothing about the game is affected either way, since Godot plays
    # .ogg files and never links Strudel.
    ("vendored in this repo", ROOT / "tools" / "strudel" / NAME),
    # Assumes the documented workspace layout: games/NN-name/ beside hub/.
    ("the hub's copy", ROOT.parent.parent / "hub" / "tools" / "strudel-render" / NAME),
]


def find_renderer() -> Path | None:
    env: str = os.environ.get("STRUDEL_RENDERER", "")
    if env:
        p = Path(env)
        # An explicit path that is wrong is a mistake worth surfacing, not
        # something to silently fall through from.
        return p if p.is_file() else None
    for _, path in CANDIDATES:
        if path.is_file():
            return path
    return None


def explain() -> str:
    env: str = os.environ.get("STRUDEL_RENDERER", "")
    lines: list[str] = ["Strudel renderer not found. Looked in:"]
    if env:
        lines.append(f"  $STRUDEL_RENDERER = {env}   <- set, but not a file")
    else:
        lines.append("  $STRUDEL_RENDERER            <- not set")
    for label, path in CANDIDATES:
        lines.append(f"  {path}   <- {label}")
    lines += [
        "",
        "The renderer is `render_superdough.mjs` - Strudel pattern code to .wav,",
        "headless and deterministic. It is NOT in this repo by default: it imports",
        "AGPL-3.0 packages (@strudel/*, superdough), so vendoring it into a public",
        "game repo is a licensing decision rather than a copy. See the README.",
        "",
        "To build audio from source: point $STRUDEL_RENDERER at a checkout, then",
        "`npm install` once in that folder. The committed .ogg files under",
        "assets/audio/ are what the game actually ships - you do not need any of",
        "this to build or play BESTAGON.",
    ]
    return "\n".join(lines)
