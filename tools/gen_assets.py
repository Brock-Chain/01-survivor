"""Generates every art & audio asset for 01-survivor. Deterministic, CC0-by-
construction (no third-party files). Re-run after tweaking, then reimport:
  python tools/gen_assets.py
Sprites: pixel grids as string rows (chars map to palette colors).
Audio: pure-stdlib synthesis (square/noise + envelopes) to 22050 Hz mono WAV.
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets" / "sprites"
SFX = ROOT / "assets" / "audio" / "sfx"
MUSIC = ROOT / "assets" / "audio" / "music"
SR = 22050

# ---------------------------------------------------------------- sprites ---
# Neon-geometric: filled shapes with a BAKED glow halo. Baked, not an engine
# glow post-process, because GL Compatibility glow support on a single-threaded
# web export is not something we want the art direction to depend on.
#
# Shapes are drawn supersampled and downsampled with LANCZOS, so the edges carry
# their own antialiasing. The viewport is 640x360 in a 1280x720 window — an exact
# 2x integer scale — so nearest-neighbour filtering displays these cleanly.
#
# COLOUR LAW (see BRIEF.md): hue encodes allegiance, silhouette encodes type.
#   cyan = yours · magenta->orange = can hurt you · yellow = enemy fire · green = pickup
# Enemy sprites are GREYSCALE on purpose: enemy.gd tints them via `modulate`, and
# a white core would multiply to the flat tint. White core + grey halo modulates
# into a saturated core with a dim halo, which is what reads as neon.

SS = 8  # supersample factor

NEON = {
    "player": ((120, 255, 245), (235, 255, 253)),   # cyan, white-hot core
    "bullet": ((110, 245, 255), (240, 255, 255)),
    "orbital": ((150, 235, 255), (245, 255, 255)),
    "gem": ((120, 255, 190), (240, 255, 230)),      # green-cyan pickup
    # Greyscale — tinted at runtime. Kept bright: `modulate` MULTIPLIES, so the
    # sprite's own value is a ceiling on how neon the tinted result can look.
    "enemy": ((214, 214, 214), (255, 255, 255)),
}

FLOOR_BASE = (11, 12, 22)
FLOOR_GRID = (26, 30, 56)


def _regular(n: int, cx: float, cy: float, r: float, rot: float = 0.0) -> list[tuple[float, float]]:
    return [(cx + r * math.cos(rot + i * math.tau / n),
             cy + r * math.sin(rot + i * math.tau / n)) for i in range(n)]


def _chevron(cx: float, cy: float, r: float) -> list[tuple[float, float]]:
    """A V pointing up — the Lancer. Distinct from a triangle at 12px."""
    return [(cx, cy - r), (cx + r, cy + r * 0.75), (cx, cy + r * 0.2), (cx - r, cy + r * 0.75)]


SHAPES = {
    "hexagon": lambda cx, cy, r: _regular(6, cx, cy, r, math.pi / 6),
    "triangle": lambda cx, cy, r: _regular(3, cx, cy, r, -math.pi / 2),
    "octagon": lambda cx, cy, r: _regular(8, cx, cy, r, math.pi / 8),
    "diamond": lambda cx, cy, r: _regular(4, cx, cy, r, -math.pi / 2),
    "chevron": _chevron,
    "square": lambda cx, cy, r: _regular(4, cx, cy, r * 0.92, math.pi / 4),
}


def _mask(size: int, shape: str, radius: float) -> Image.Image:
    """Antialiased coverage mask for one shape, via supersampling."""
    hi = size * SS
    img = Image.new("L", (hi, hi), 0)
    pts = SHAPES[shape](hi / 2.0, hi / 2.0, radius * SS)
    ImageDraw.Draw(img).polygon(pts, fill=255)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def _tint(mask: Image.Image, rgb: tuple[int, int, int], alpha: float = 1.0) -> Image.Image:
    layer = Image.new("RGBA", mask.size, (*rgb, 0))
    layer.putalpha(mask.point(lambda a: int(a * alpha)))
    return layer


def neon_sprite(name: str, size: int, shape: str, key: str,
                radius: float | None = None, core_ratio: float = 0.52,
                glow: float = 1.9, glow_alpha: float = 0.62) -> None:
    """Glow halo + body + white-hot core, composited bottom-up."""
    body_rgb, core_rgb = NEON[key]
    r = radius if radius is not None else size * 0.34
    body = _mask(size, shape, r)
    core = _mask(size, shape, r * core_ratio)

    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    halo = body.filter(ImageFilter.GaussianBlur(glow))
    out.alpha_composite(_tint(halo, body_rgb, glow_alpha))
    out.alpha_composite(_tint(body, body_rgb))
    out.alpha_composite(_tint(core, core_rgb, 0.92))
    out.save(SPRITES / name)
    print(f"sprite {name} {size}x{size} {shape}")


def write_floor() -> None:
    """Dark indigo with a faint grid — motion parallax without competing."""
    img = Image.new("RGBA", (32, 32), (*FLOOR_BASE, 255))
    d = ImageDraw.Draw(img)
    d.line([(0, 0), (31, 0)], fill=(*FLOOR_GRID, 255))
    d.line([(0, 0), (0, 31)], fill=(*FLOOR_GRID, 255))
    img.save(SPRITES / "floor.png")
    print("sprite floor.png 32x32")


# ------------------------------------------------------------------ audio ---

def env(i: int, n: int, attack: float = 0.01, curve: float = 3.0) -> float:
    t = i / n
    a = min(1.0, t / max(attack, 1e-6))
    return a * (1.0 - t) ** curve


def square(phase: float) -> float:
    return 1.0 if (phase % 1.0) < 0.5 else -1.0


def sweep(f0: float, f1: float, dur: float, wave_fn=square, curve: float = 3.0,
          amp: float = 0.5) -> list[float]:
    n = int(SR * dur)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        phase += (f0 + (f1 - f0) * t) / SR
        out.append(wave_fn(phase) * env(i, n, curve=curve) * amp)
    return out


def noise_burst(dur: float, amp: float = 0.5, curve: float = 4.0) -> list[float]:
    rng = random.Random(7)
    n = int(SR * dur)
    return [rng.uniform(-1, 1) * env(i, n, curve=curve) * amp for i in range(n)]


def blips(freqs: list[float], each: float = 0.09, amp: float = 0.45) -> list[float]:
    out: list[float] = []
    for f in freqs:
        n = int(SR * each)
        out += [square(i * f / SR) * env(i, n, curve=2.0) * amp for i in range(n)]
    return out


def write_wav(path: Path, samples: list[float]) -> None:
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))
    print(f"audio {path.name} {len(samples) / SR:.2f}s")


NOTE = {n: 440.0 * 2 ** ((i - 9) / 12) for i, n in enumerate(
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(name: str, octave: int) -> float:
    return NOTE[name] * 2 ** (octave - 4)


def write_music() -> None:
    """8 bars @ 120bpm, Am-F-C-G: square bass, arp, kick, hats. ~16s loop."""
    bpm, bars = 120.0, 8
    beat = 60.0 / bpm
    total = int(SR * beat * 4 * bars)
    mix = [0.0] * total
    chords = [("A", 2, ["A", "C", "E"]), ("F", 2, ["F", "A", "C"]),
              ("C", 3, ["C", "E", "G"]), ("G", 2, ["G", "B", "D"])]

    for bar in range(bars):
        root_name, root_oct, triad = chords[bar % 4]
        bar_start = int(SR * beat * 4 * bar)
        # bass: root, 8th notes
        f_bass = freq(root_name, root_oct)
        for eighth in range(8):
            start = bar_start + int(SR * beat * 0.5 * eighth)
            n = int(SR * beat * 0.45)
            for i in range(n):
                if start + i < total:
                    mix[start + i] += square(i * f_bass / SR) * env(i, n, curve=1.5) * 0.16
        # arp: triad 16th notes, one octave up
        for six in range(16):
            f_arp = freq(triad[six % 3], root_oct + 2)
            start = bar_start + int(SR * beat * 0.25 * six)
            n = int(SR * beat * 0.22)
            for i in range(n):
                if start + i < total:
                    mix[start + i] += square(i * f_arp / SR) * env(i, n, curve=2.5) * 0.08
        # kick on beats, hat on off-beats
        for b in range(4):
            start = bar_start + int(SR * beat * b)
            n = int(SR * 0.09)
            for i in range(n):
                if start + i < total:
                    f_k = 120.0 * (1 - i / n) + 40.0
                    mix[start + i] += math.sin(2 * math.pi * f_k * i / SR) * env(i, n, curve=2.0) * 0.5
            rng = random.Random(bar * 4 + b)
            start_h = bar_start + int(SR * beat * (b + 0.5))
            n_h = int(SR * 0.03)
            for i in range(n_h):
                if start_h + i < total:
                    mix[start_h + i] += rng.uniform(-1, 1) * env(i, n_h, curve=5.0) * 0.10

    write_wav(MUSIC / "loop.wav", [max(-1.0, min(1.0, s)) for s in mix])


def main() -> None:
    for d in (SPRITES, SFX, MUSIC):
        d.mkdir(parents=True, exist_ok=True)
    # Player & friendlies — authored in colour (never modulated).
    neon_sprite("player.png", 16, "diamond", "player", radius=5.6, core_ratio=0.5)
    neon_sprite("bullet.png", 8, "diamond", "bullet", radius=2.5, core_ratio=0.5,
                glow=1.1, glow_alpha=0.7)
    neon_sprite("orbital.png", 8, "square", "orbital", radius=2.5, core_ratio=0.5,
                glow=1.1, glow_alpha=0.7)
    neon_sprite("gem.png", 10, "diamond", "gem", radius=3.2, core_ratio=0.46,
                glow=1.4, glow_alpha=0.65)

    # Enemies — GREYSCALE, tinted per type at runtime. enemy.png stays the
    # Drifter so existing scenes keep working; the rest are wired up in M5.
    for name, shape in (("enemy.png", "hexagon"), ("enemy_drifter.png", "hexagon"),
                        ("enemy_dart.png", "triangle"), ("enemy_bulwark.png", "octagon"),
                        ("enemy_splitter.png", "diamond"), ("enemy_lancer.png", "chevron")):
        neon_sprite(name, 16, shape, "enemy", radius=5.5, core_ratio=0.5)

    write_floor()

    write_wav(SFX / "shoot.wav", sweep(880, 440, 0.07, amp=0.22))
    write_wav(SFX / "hit.wav", noise_burst(0.06, amp=0.4))
    write_wav(SFX / "pop.wav", sweep(300, 70, 0.12, amp=0.45))
    write_wav(SFX / "pickup.wav", blips([660, 990], 0.07, amp=0.3))
    write_wav(SFX / "levelup.wav", blips([523, 659, 784, 1047], 0.1, amp=0.4))
    write_wav(SFX / "hurt.wav", sweep(220, 90, 0.16, amp=0.5, curve=2.0))
    write_wav(SFX / "death.wav", sweep(440, 50, 0.6, amp=0.5, curve=1.5))
    write_wav(SFX / "click.wav", blips([1200], 0.03, amp=0.25))
    write_music()


if __name__ == "__main__":
    main()
