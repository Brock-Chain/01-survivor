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

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets" / "sprites"
SFX = ROOT / "assets" / "audio" / "sfx"
MUSIC = ROOT / "assets" / "audio" / "music"
SR = 22050

# ---------------------------------------------------------------- sprites ---

PALETTES = {
    ".": None,  # transparent
    "W": (238, 244, 255),
    "w": (196, 210, 235),
    "B": (90, 140, 220),
    "b": (40, 70, 130),
    "K": (20, 24, 34),
    "G": (90, 230, 240),
    "g": (30, 140, 160),
    "Y": (255, 235, 140),
    "y": (230, 180, 60),
    "R": (235, 90, 80),
    "F1": (26, 29, 39),
    "F2": (30, 34, 45),
}

PLAYER = [
    "....WWWWWWWW....",
    "...WWWWWWWWWW...",
    "..WWwwwwwwwwWW..",
    "..WwKKwwwwKKwW..",
    "..WwKKwwwwKKwW..",
    "..WwwwwwwwwwwW..",
    "..WwwKwwwwKwwW..",
    "..WwwwKKKKwwwW..",
    "..WWwwwwwwwwWW..",
    "...BBBBBBBBBB...",
    "..BBbBBBBBBbBB..",
    "..BbbBBBBBBbbB..",
    "..BbBBBBBBBBbB..",
    "...BBBB..BBBB...",
    "...bbb....bbb...",
    "................",
]

# White-ish blob — tinted at runtime by EnemyStats.tint via modulate.
ENEMY = [
    "................",
    "....WWWWWWWW....",
    "...WWWWWWWWWW...",
    "..WWWWWWWWWWWW..",
    "..WWKKWWWWKKWW..",
    "..WWKKWWWWKKWW..",
    ".WWWWWWWWWWWWWW.",
    ".WWWWWWWWWWWWWW.",
    ".WWWWKWWWWKWWWW.",
    ".WWWWKKKKKKWWWW.",
    "..WWWWWWWWWWWW..",
    "..WWWWWWWWWWWW..",
    "..WwWWwWWwWWwW..",
    "..Ww.Ww..wW.wW..",
    "................",
    "................",
]

GEM = [
    "....GG....",
    "...GGGG...",
    "..GGWWGG..",
    ".GGWWGGGG.",
    "GGGWGGGGGG",
    "GGGGGGGGgg",
    ".GGGGGGgg.",
    "..GGGGgg..",
    "...GGgg...",
    "....gg....",
]

BULLET = [
    "..YYYYWW",
    "yYYYYWWW",
    "yYYYYWWW",
    "..YYYYWW",
]


def write_sprite(name: str, rows: list[str]) -> None:
    h = len(rows)
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            color = PALETTES.get(ch)
            if color is not None:
                img.putpixel((x, y), (*color, 255))
    img.save(SPRITES / name)
    print(f"sprite {name} {w}x{h}")


def write_floor() -> None:
    rng = random.Random(41)
    img = Image.new("RGBA", (32, 32))
    base, alt = PALETTES["F1"], PALETTES["F2"]
    for y in range(32):
        for x in range(32):
            color = alt if (x < 1 or y < 1) else base
            if color is base and rng.random() < 0.02:
                color = alt
            img.putpixel((x, y), (*color, 255))
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
    write_sprite("player.png", PLAYER)
    write_sprite("enemy.png", ENEMY)
    write_sprite("gem.png", GEM)
    write_sprite("bullet.png", BULLET)
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
