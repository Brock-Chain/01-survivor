"""Strudel .strudel -> game-ready .ogg. The whole music pipeline, one command.

    python tools/build_music.py            # render everything that changed
    python tools/build_music.py --force    # re-render regardless

Source of truth is `audio_src/*.strudel` — a few dozen lines of readable code,
diffable in git. The .ogg files under assets/audio/music/ are BUILD ARTIFACTS:
delete them and this regenerates byte-identical copies (the renderer is seeded).

That last claim holds ONLY if you have the renderer, which is a separate tool and
is not committed here — see `strudel_renderer.py` for the three places this looks
and why it is not vendored. You do not need it to build or play the game; the
.ogg files are committed. You need it to change the music.

Two non-obvious steps, both learned the hard way (hub/knowledge/audio-authoring.md):

1. TAIL-FOLD. The render is longer than the music: reverb and release tails ring
   past the last cycle. Cutting at the body length throws that away and leaves a
   step discontinuity at the wrap point — an audible click on every repeat. So we
   fold the tail back onto the head, which is exactly what it would have done had
   the loop already been going round.

2. BLOCK-WRITE THE OGG. soundfile.write() of a long buffer stack-overflows on
   Windows (exit 0xC00000FD) and fails *silently mid-write*, leaving a plausible
   truncated file. Streaming in blocks avoids it.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

from strudel_renderer import explain, find_renderer

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "audio_src"
OUT = ROOT / "assets" / "audio" / "music"
RENDERER = find_renderer()   # $STRUDEL_RENDERER, a vendored copy, or the hub — see strudel_renderer.py

CPS = 0.5
BLOCK = 65536

# Discovered from disk rather than hardcoded: adding a track is four .strudel
# files with the right names, not a code edit.
#   <track>_<layer>_<name>.strudel  ->  an 8-cycle gameplay stem
#   title.strudel                   ->  an 8-cycle loop
#   victory.strudel                 ->  a 4-cycle ONE-SHOT (keeps its ring-out)
ONE_SHOTS = {"victory": 4}
## Pieces whose length is not the default 8 cycles. The title is a 64-second
## slow burn that rewards leaving the menu running, so it needs 32.
CYCLES = {"title": 32}


def discover() -> dict[str, tuple[int, bool]]:
    pieces: dict[str, tuple[int, bool]] = {}
    for f in sorted(SRC.glob("*.strudel")):
        name = f.stem
        if name in ONE_SHOTS:
            pieces[name] = (ONE_SHOTS[name], False)
        else:
            pieces[name] = (CYCLES.get(name, 8), True)
    return pieces


PIECES = discover()


def stem_groups() -> dict[str, list[str]]:
    """Gameplay stem sets, keyed by track prefix, ordered by layer index."""
    groups: dict[str, list[str]] = {}
    for name in PIECES:
        parts = name.split("_")
        if len(parts) >= 3 and parts[1].isdigit():
            groups.setdefault(parts[0], []).append(name)
    for k in groups:
        groups[k].sort(key=lambda n: int(n.split("_")[1]))
    return groups


def render(name: str, cycles: int) -> dict:
    wav = SRC / f"{name}.wav"
    proc = subprocess.run(
        ["node", str(RENDERER), str(SRC / f"{name}.strudel"), str(wav),
         "--cps", str(CPS), "--cycles", str(cycles)],
        # 1800, not 600: the synthesised-noise kit made the 32-cycle title render
        # blow past ten minutes on 2026-08-03. Renders are offline; slow is fine.
        capture_output=True, text=True, timeout=1800)
    match = re.search(r"\{[\s\S]*\}\s*$", proc.stdout)
    if not match:
        raise RuntimeError(f"{name}: renderer gave no summary\n{proc.stdout[-800:]}\n{proc.stderr[-800:]}")
    summary = json.loads(match.group(0))
    if summary.get("failed"):
        raise RuntimeError(f"{name}: sounds not found: {summary['failed']}")
    if summary.get("stuck"):
        raise RuntimeError(f"{name}: stuck note — render is untrustworthy")
    if summary.get("skipped"):
        print(f"  ! {name}: {summary['skipped']} events skipped")
    return summary


def fold_tail(data: np.ndarray, sr: int, cycles: int) -> tuple[np.ndarray, float]:
    """Wrap the ring-out onto the head. Returns (loop, discontinuity)."""
    body = int(round(cycles / CPS * sr))
    if body >= len(data):
        return data, 0.0
    tail = data[body:]
    loop = data[:body].astype(np.float64).copy()
    n = min(len(tail), len(loop))
    loop[:n] += tail[:n]
    # Wrap-point discontinuity as a FRACTION OF PEAK. The obvious metric —
    # jump vs mean sample-to-sample step — is wrong for this material: a bass
    # stem at 55 Hz moves very little between adjacent samples, so a harmless
    # jump scores enormous, while broadband drums score near zero for the same
    # absolute jump. Relative to peak is what actually predicts an audible click.
    peak = float(np.max(np.abs(loop))) or 1.0
    jump = float(np.max(np.abs(loop[-1] - loop[0])))
    return loop, jump / peak


def write_ogg(path: Path, data: np.ndarray, sr: int) -> None:
    peak = float(np.max(np.abs(data))) if len(data) else 0.0
    if peak > 0.99:
        data = data * (0.97 / peak)
        print(f"  ! {path.stem}: normalised down from peak {peak:.2f}")
    path.parent.mkdir(parents=True, exist_ok=True)
    with sf.SoundFile(str(path), "w", samplerate=sr,
                      channels=data.shape[1], format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(data), BLOCK):
            f.write(data[i:i + BLOCK])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--only", default=None)
    args = ap.parse_args()

    if RENDERER is None:
        print(explain())
        return 1

    stems: dict[str, np.ndarray] = {}
    for name, (cycles, loop) in PIECES.items():
        if args.only and args.only not in name:
            continue
        strudel = SRC / f"{name}.strudel"
        ogg = OUT / f"{name}.ogg"
        # The events sidecar is a byproduct of rendering, so a stem whose .ogg is
        # current but whose sidecar was cleaned up has nothing for the score
        # viewer to draw. Missing sidecar counts as out of date.
        events = SRC / f"{name}.wav.events.json"
        fresh = ogg.exists() and ogg.stat().st_mtime > strudel.stat().st_mtime
        if not args.force and fresh and events.exists():
            print(f"  = {name} (up to date)")
            continue
        if fresh and not events.exists():
            print(f"  > {name} (re-rendering: sidecar missing)")

        print(f"  > {name}")
        summary = render(name, cycles)
        data, sr = sf.read(str(SRC / f"{name}.wav"), always_2d=True)

        if loop:
            data, disc = fold_tail(data, sr, cycles)
            print(f"    folded tail, wrap jump {disc * 100:.2f}% of peak "
                  f"({'inaudible' if disc < 0.02 else 'AUDIBLE - investigate'})")
        write_ogg(ogg, data, sr)
        peak = np.max(np.abs(data), axis=0)
        if name.split("_")[1:2] and name.split("_")[1].isdigit():
            stems[name] = data
        kb = ogg.stat().st_size / 1024
        print(f"    {len(data) / sr:.1f}s  peak {peak.max():.2f}  {kb:.0f} KB  "
              f"({summary['rendered']} events)")

    # Each TRACK is checked on its own: stems only ever play with their siblings,
    # so mixing every track together would be measuring a sound nobody hears.
    for prefix, names in stem_groups().items():
        have = [stems[n] for n in names if n in stems]
        if len(have) < 2:
            continue
        n = min(len(d) for d in have)
        mixed = sum(d[:n] for d in have)
        true_peak = float(np.max(np.abs(mixed)))
        naive = sum(float(np.max(np.abs(d))) for d in have)
        verdict = "headroom OK" if true_peak < 0.95 else "CLIPS - lower stem gains"
        print(f"\n  [{prefix}] {len(have)} stems mixed: TRUE peak {true_peak:.2f}  {verdict}")
        print(f"           (sum-of-peaks would have claimed {naive:.2f})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
