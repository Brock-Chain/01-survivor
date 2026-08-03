"""Locate the offline Strudel renderer. No absolute paths, ever.

The renderer lives in `tools/strudel/` in this repo, so a fresh clone can build
the audio with one `npm install` and nothing else. Resolution order, first hit
wins:

    1. $STRUDEL_RENDERER            an explicit override, for a checkout elsewhere
    2. tools/strudel/               THIS REPO. the normal path
    3. ../../hub/tools/strudel-render/     the workspace's shared copy

This file exists because the renderer used to be a hardcoded, machine-specific
path into a private repo -- in a PUBLIC one -- backing a docstring that promised
the .ogg files were regenerable build artifacts. For every person who cloned
this, that promise was false, and the failure was invisible to the author because
on their machine it worked. An absolute path is never a local convenience; it is
a claim that only holds on one computer.

`verify.ps1` now fails the build on any absolute path in tracked code, which is
why this paragraph describes the old one instead of quoting it.
"""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME = "render_superdough.mjs"

CANDIDATES: list[tuple[str, Path]] = [
    ("this repo (tools/strudel/)", ROOT / "tools" / "strudel" / NAME),
    # Assumes the documented workspace layout: games/NN-name/ beside hub/.
    ("the workspace hub", ROOT.parent.parent / "hub" / "tools" / "strudel-render" / NAME),
]


def find_renderer() -> Path | None:
    env: str = os.environ.get("STRUDEL_RENDERER", "")
    if env:
        p = Path(env)
        # An explicit override that is wrong is a mistake worth surfacing, not
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
        lines.append("  $STRUDEL_RENDERER            <- not set (optional override)")
    for label, path in CANDIDATES:
        lines.append(f"  {path}   <- {label}")
    lines += [
        "",
        "The renderer ships in this repo, so the usual cause is a missing",
        "`npm install`. From the repo root:",
        "",
        "    cd tools/strudel && npm install",
        "",
        "You do not need any of this to build or play BESTAGON -- the .ogg files",
        "under assets/audio/ are committed and are what the game ships. You need",
        "it to CHANGE the music. See tools/strudel/README.md.",
    ]
    return "\n".join(lines)
