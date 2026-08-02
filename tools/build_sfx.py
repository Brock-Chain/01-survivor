"""Strudel .strudel -> game-ready SFX .wav. Companion to build_music.py.

    python tools/build_sfx.py            # render everything that changed
    python tools/build_sfx.py --force    # re-render regardless

Sources live in `audio_src/sfx/`, one file per sound, same renderer and seed as
the music — so the whole soundscape shares one synth palette and regenerates
byte-identical. Sounds heard hundreds of times per run get a PITCH-VARIED SET:
authored as `cat(v0, v1, v2)` — one variant per cycle — listed in VARIANTS
below, and sliced apart at cycle boundaries into `<name>_<i>.wav`. Everything
else renders one cycle to `<name>.wav`.

SFX invert most of the music pipeline's rules:

1. NO TAIL-FOLD. A one-shot keeps its ring-out; it never wraps. Only sliced
   variants lose their window's tail, so the build MEASURES the leak: energy
   still ringing at a variant's cycle boundary means the variants bleed into
   each other and the sound needs a shorter envelope, not a longer trim.

2. WAV, NOT OGG. Sub-second sounds decode dozens of times per second; PCM has
   no decode cost and the size argument flips (a 100 ms wav is ~9 KB).

3. MONO. Positional width on a 90 ms zap is inaudible; the music owns the
   stereo field. Halves the web download for 20+ files.

4. TRIMMED AND FAMILY-NORMALISED. Trailing silence is dead weight; each FAMILY
   scales by one factor (its loudest variant hits the target peak), so authored
   loudness differences between variants survive. Per-file normalisation would
   erase them. In-game relative levels stay where they belong: volume_db at the
   Sfx.play() call site.
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

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "audio_src" / "sfx"
OUT = ROOT / "assets" / "audio" / "sfx"
RENDERER = Path("REDACTED/render_superdough.mjs")

CPS = 0.5           # 2 s per cycle: room for any one-shot plus its tail
TARGET_PEAK = 0.9
TRIM_DB = -60.0     # below this the tail is dead weight, not ring-out
FADE_MS = 5.0       # tiny fade at the cut so the trim itself cannot click
ONSET_DB = -40.0    # a one-shot must speak within ONSET_MS of its trigger
ONSET_MS = 30.0
BLEED_DB = -50.0    # energy at a sliced variant's boundary = envelope too long

# Pitch-varied sets: <name>.strudel is cat(v0, v1, ...), one variant per cycle.
VARIANTS = {"shoot": 3, "hit": 3, "pop": 3, "pickup": 2}


def render(name: str, cycles: int) -> None:
    wav = SRC / f"{name}.wav"
    proc = subprocess.run(
        ["node", str(RENDERER), str(SRC / f"{name}.strudel"), str(wav),
         "--cps", str(CPS), "--cycles", str(cycles)],
        capture_output=True, text=True, timeout=600)
    match = re.search(r"\{[\s\S]*\}\s*$", proc.stdout)
    if not match:
        raise RuntimeError(f"{name}: renderer gave no summary\n{proc.stdout[-800:]}\n{proc.stderr[-800:]}")
    summary = json.loads(match.group(0))
    if summary.get("failed"):
        raise RuntimeError(f"{name}: sounds not found: {summary['failed']}")
    if summary.get("stuck"):
        raise RuntimeError(f"{name}: stuck note — render is untrustworthy")


def trim(mono: np.ndarray, sr: int) -> np.ndarray:
    """Cut trailing dead air, then fade the last few ms so the cut can't click."""
    threshold = 10.0 ** (TRIM_DB / 20.0)
    loud = np.flatnonzero(np.abs(mono) > threshold)
    if len(loud) == 0:
        return mono
    end = min(len(mono), int(loud[-1] + sr * 0.02))  # keep 20 ms of true tail
    out = mono[:end].copy()
    fade = min(len(out), int(sr * FADE_MS / 1000.0))
    if fade > 0:
        out[-fade:] *= np.linspace(1.0, 0.0, fade)
    return out


def check_onset(name: str, mono: np.ndarray, sr: int) -> None:
    """SFX are feedback: a sound that arrives late reads as a sound that lied."""
    threshold = 10.0 ** (ONSET_DB / 20.0)
    loud = np.flatnonzero(np.abs(mono) > threshold)
    onset_ms = (loud[0] / sr * 1000.0) if len(loud) else float("inf")
    if onset_ms > ONSET_MS:
        print(f"  ! {name}: onset {onset_ms:.0f}ms > {ONSET_MS:.0f}ms — "
              f"deliberate swell (telegraph) or an authoring bug?")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--only", default=None)
    args = ap.parse_args()

    if not RENDERER.exists():
        print(f"renderer not found: {RENDERER}")
        return 1

    OUT.mkdir(parents=True, exist_ok=True)
    for strudel in sorted(SRC.glob("*.strudel")):
        name = strudel.stem
        if args.only and args.only not in name:
            continue
        count = VARIANTS.get(name, 1)
        first_out = OUT / (f"{name}_0.wav" if count > 1 else f"{name}.wav")
        if not args.force and first_out.exists() \
                and first_out.stat().st_mtime > strudel.stat().st_mtime:
            print(f"  = {name} (up to date)")
            continue

        print(f"  > {name}")
        render(name, count)
        data, sr = sf.read(str(SRC / f"{name}.wav"), always_2d=True)
        mono = data.mean(axis=1)
        cycle = int(round(sr / CPS))

        # Slice variants; the LAST one keeps the render's natural tail.
        slices: list[np.ndarray] = []
        for i in range(count):
            lo = i * cycle
            hi = (i + 1) * cycle if i < count - 1 else len(mono)
            piece = mono[lo:hi]
            if i < count - 1:
                boundary = np.max(np.abs(piece[-int(sr * 0.05):]))
                if boundary > 10.0 ** (BLEED_DB / 20.0):
                    print(f"  ! {name}[{i}]: {20 * np.log10(boundary):.0f} dB still "
                          f"ringing at the slice boundary — variants are bleeding")
            slices.append(piece)

        family_peak = max(float(np.max(np.abs(p))) for p in slices) or 1.0
        gain = TARGET_PEAK / family_peak
        for i, piece in enumerate(slices):
            piece = trim(piece * gain, sr)
            out = OUT / (f"{name}_{i}.wav" if count > 1 else f"{name}.wav")
            sf.write(str(out), piece, sr, subtype="PCM_16")
            check_onset(out.stem, piece, sr)
            print(f"    {out.name}  {len(piece) / sr * 1000:5.0f}ms  "
                  f"peak {float(np.max(np.abs(piece))):.2f}  "
                  f"{out.stat().st_size / 1024:.0f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
