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

from PIL import Image, ImageChops, ImageDraw, ImageFilter

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
    # The core is its own SPRITE now, so it needs its own palette entry. It is
    # nearly white on purpose: it reads as the hot centre of the shape, and once
    # it is a separate node it can slide, flare and dim independently of the body.
    "player_core": ((215, 255, 252), (255, 255, 255)),
    "bullet": ((110, 245, 255), (240, 255, 255)),
    "orbital": ((150, 235, 255), (245, 255, 255)),
    "gem": ((120, 255, 190), (240, 255, 230)),      # green-cyan pickup
    # Enemy fire. Yellow is RESERVED — nothing friendly is ever yellow, so
    # "this can hurt me" reads before the shape does.
    "bolt": ((255, 226, 96), (255, 250, 220)),
    # Health: warm white-cyan. Deliberately NOT the green of XP — the two must
    # never be confused when the screen is busy.
    "health": ((150, 255, 235), (255, 255, 255)),
    "powerup": ((140, 255, 244), (255, 255, 255)),
    # Nogaxeh's shield membrane. Cold white-violet, deliberately outside both the
    # cyan (yours) and magenta-orange (hostile) bands so "hardened, inert, not
    # currently a target" is its own read. BRIEF.md already exempts the boss from
    # the colour law -- "it is allowed to break the law, that is what makes it
    # read as a boss" -- and this is the one place that exemption earns itself.
    "shield": ((198, 188, 255), (255, 255, 255)),
    # Greyscale — tinted at runtime. Kept bright: `modulate` MULTIPLIES, so the
    # sprite's own value is a ceiling on how neon the tinted result can look.
    "enemy": ((214, 214, 214), (255, 255, 255)),
}

FLOOR_BASE = (11, 12, 22)
FLOOR_GRID = (21, 24, 46)
## Circuit trace palette. Every value here is deliberately far below the entity
## palette (enemy sprites are 214 greyscale before tinting, the player's cyan is
## 120,255,245) so the floor reads as texture and never as an object. If the
## floor ever competes with a bolt, these are the numbers that are wrong.
TRACE = (33, 30, 72)
TRACE_LIT = (54, 42, 116)
NODE = (74, 55, 148)
VIA = (44, 88, 122)


def _regular(n: int, cx: float, cy: float, r: float, rot: float = 0.0) -> list[tuple[float, float]]:
    return [(cx + r * math.cos(rot + i * math.tau / n),
             cy + r * math.sin(rot + i * math.tau / n)) for i in range(n)]


def _plus(cx: float, cy: float, r: float) -> list[tuple[float, float]]:
    """A thick cross — reads as 'boost' and is unmistakable at 14px."""
    a = r * 0.36
    return [(cx - a, cy - r), (cx + a, cy - r), (cx + a, cy - a), (cx + r, cy - a),
            (cx + r, cy + a), (cx + a, cy + a), (cx + a, cy + r), (cx - a, cy + r),
            (cx - a, cy + a), (cx - r, cy + a), (cx - r, cy - a), (cx - a, cy - a)]


def _bolt(cx: float, cy: float, r: float) -> list[tuple[float, float]]:
    """A lightning bolt — the universal 'faster' glyph."""
    return [(cx + r * 0.25, cy - r), (cx - r * 0.55, cy + r * 0.15),
            (cx - r * 0.05, cy + r * 0.15), (cx - r * 0.25, cy + r),
            (cx + r * 0.6, cy - r * 0.2), (cx + r * 0.05, cy - r * 0.2)]


def _chevron(cx: float, cy: float, r: float) -> list[tuple[float, float]]:
    """A V pointing up — the Lancer. Distinct from a triangle at 12px."""
    return [(cx, cy - r), (cx + r, cy + r * 0.75), (cx, cy + r * 0.2), (cx - r, cy + r * 0.75)]


def _sliver(cx: float, cy: float, r: float) -> list[tuple[float, float]]:
    """A long thin needle pointing up — the Dart. It rotates to face travel.

    The Dart used to be an equilateral triangle, which is ALSO the enemy bolt's
    shape: on a contact sheet the Dart read as an oversized bolt, collapsing the
    one distinction the colour law is built to protect ("can this hurt me" before
    "what is it"). A needle at 10px cannot be mistaken for a bolt at 12px, and
    the aspect ratio says 'fast' on its own.
    """
    return [(cx, cy - r), (cx + r * 0.30, cy), (cx, cy + r * 0.86), (cx - r * 0.30, cy)]


def _wedge(cx: float, cy: float, r: float) -> list[tuple[float, float]]:
    """A tall narrow spearhead pointing up — the Ram.

    The Ram ROTATES to face its target (enemy.gd), so 'up' is its forward. It
    must not read as the Dart, which is an equilateral triangle: at 12px in a
    crowd, aspect ratio and motion read long before exact angle does. Narrow
    plus turning is unmistakable; the Ram used to literally wear the Dart's
    sprite, which is review finding 8.
    """
    return [(cx, cy - r), (cx + r * 0.48, cy + r * 0.78), (cx - r * 0.48, cy + r * 0.78)]


SHAPES = {
    # THE BESTAGON. The player is the only hexagon in the game — until Nogaxeh,
    # which breaks the rule exactly once, at the climax, and the break IS the
    # reveal. Nothing else may claim six sides.
    "hexagon": lambda cx, cy, r: _regular(6, cx, cy, r, math.pi / 6),
    "triangle": lambda cx, cy, r: _regular(3, cx, cy, r, -math.pi / 2),
    "octagon": lambda cx, cy, r: _regular(8, cx, cy, r, math.pi / 8),
    "diamond": lambda cx, cy, r: _regular(4, cx, cy, r, -math.pi / 2),
    "chevron": _chevron,
    "square": lambda cx, cy, r: _regular(4, cx, cy, r * 0.92, math.pi / 4),
    # The Prism. Five sides — the shape that came closest to being a hexagon and
    # did not. A pentagonal prism is a real solid, so the name stays accurate.
    "pentagon": lambda cx, cy, r: _regular(5, cx, cy, r, -math.pi / 2),
    "wedge": _wedge,
    "sliver": _sliver,
    "plus": _plus,
    "bolt": _bolt,
    "star": lambda cx, cy, r: _regular(12, cx, cy, r, -math.pi / 2),
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
                glow: float = 1.9, glow_alpha: float = 0.62,
                hollow: float = 0.0) -> None:
    """Glow halo + body + white-hot core, composited bottom-up.

    `hollow` is the PATTERN channel: punch a same-shape void out of the middle,
    leaving a ring. It exists because the colour law reserves hue for allegiance
    (cyan yours / magenta-orange hostile / yellow enemy fire), and the hostile
    band was already full at seven enemies — findings 8 and 18 were both "ran out
    of distinguishable hues". Pattern differentiates types at ZERO hue cost and
    survives being 12px tall in a crowd, which a subtle hue shift does not.
    """
    body_rgb, core_rgb = NEON[key]
    r = radius if radius is not None else size * 0.34
    body = _mask(size, shape, r)
    core = _mask(size, shape, r * core_ratio)
    if hollow > 0.0:
        void = _mask(size, shape, r * hollow)
        body = ImageChops.subtract(body, void)
        # Keep the core OUTSIDE the void, so a hollow shape gets a hot inner rim
        # rather than losing its core entirely and going dull.
        core = ImageChops.subtract(core, void)

    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    halo = body.filter(ImageFilter.GaussianBlur(glow))
    out.alpha_composite(_tint(halo, body_rgb, glow_alpha))
    out.alpha_composite(_tint(body, body_rgb))
    # core_ratio <= 0 means NO baked core - used by the player body, whose core
    # is a separate node so it can lag behind the shell under acceleration.
    if core_ratio > 0.0:
        out.alpha_composite(_tint(core, core_rgb, 0.92))
    out.save(SPRITES / name)
    print(f"sprite {name} {size}x{size} {shape}")


def write_floor() -> None:
    """The arena floor: a circuit board, seamlessly tiled.

    Art direction 2026-08-02 asked for "neon techno with circuitry". The floor is
    the single largest surface in the game, so it carries that read almost by
    itself — but BRIEF.md is equally clear that the floor is "near-black indigo,
    low contrast, NEVER COMPETES". Those pull against each other and the brief
    wins: every value here stays far below the entity palette (enemies are 214
    greyscale before tinting), so the traces are legible as texture and invisible
    as objects. Reference images for this look are gorgeous precisely because
    nothing gameplay-critical sits on top of them.

    SEAMLESS TILING is the whole constraint on the layout. The tile is 64px on a
    16px lattice, and every trace that reaches an edge does so at a lattice point
    that has a matching stub on the opposite edge — a bus at y=32 crossing left
    and right, a bus at x=32 crossing top and bottom. Everything else is routed
    strictly inside. Deterministic: no RNG, so the tile regenerates byte-identical.
    """
    # 128, not 64. At 64 the motif repeats ten times across a 640px viewport and
    # the eye locks onto the pattern instead of reading it as a surface. 128 shows
    # five across, which is the difference between "circuit board" and "wallpaper".
    size, lattice = 128, 16
    img = Image.new("RGBA", (size, size), (*FLOOR_BASE, 255))
    d = ImageDraw.Draw(img)

    # Substrate grid, dimmer than before — the traces now carry the structure, so
    # the grid only has to hint at scale for motion parallax.
    for i in range(0, size, lattice):
        d.line([(i, 0), (i, size - 1)], fill=(*FLOOR_GRID, 255))
        d.line([(0, i), (size - 1, i)], fill=(*FLOOR_GRID, 255))

    # The two buses. These are the only traces allowed to touch an edge, and they
    # cross at the tile's midpoints so neighbours line up in every direction.
    d.line([(0, 64), (size, 64)], fill=(*TRACE, 255))
    d.line([(64, 0), (64, size)], fill=(*TRACE, 255))

    # Branches, all interior. Right angles with a few 45-degree runs, which is
    # what makes it read as a PCB rather than as graph paper. Routed
    # asymmetrically across the four quadrants on purpose: a tile with rotational
    # symmetry announces its own repeat.
    for a, b in (
            # upper left: a dense cluster feeding the vertical bus
            ((16, 16), (16, 48)), ((16, 48), (48, 48)), ((48, 48), (48, 32)),
            ((48, 32), (64, 32)), ((16, 16), (40, 16)), ((32, 16), (32, 40)),
            # upper right: long runs, sparse
            ((64, 16), (112, 16)), ((112, 16), (112, 48)), ((96, 16), (96, 44)),
            ((112, 48), (96, 64)),
            # lower left: diagonal chase into the bus
            ((16, 80), (48, 112)), ((16, 96), (16, 120)), ((16, 120), (56, 120)),
            ((48, 80), (48, 96)), ((48, 96), (64, 96)),
            # lower right: a small block of parallel traces
            ((80, 80), (120, 80)), ((80, 96), (120, 96)), ((80, 80), (80, 112)),
            ((120, 96), (120, 124)), ((96, 96), (96, 112)),
    ):
        d.line([a, b], fill=(*TRACE, 255))

    # LIT segments. Sparse on purpose: if everything glows the eye has nowhere to
    # rest and the floor starts competing after all.
    for a, b in (((64, 64), (112, 64)), ((32, 16), (32, 40)),
                 ((16, 120), (56, 120)), ((80, 96), (120, 96))):
        d.line([a, b], fill=(*TRACE_LIT, 255))

    # Junction pads where traces meet, vias where they would pass through to
    # another layer. These details are what sell "circuit" at a glance.
    for x, y in ((64, 64), (16, 48), (48, 48), (112, 16), (16, 120),
                 (80, 96), (120, 96), (48, 96), (32, 16)):
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=(*NODE, 255))
    for x, y in ((96, 44), (112, 48), (56, 120), (120, 124), (96, 112), (32, 40)):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], outline=(*VIA, 255))

    # Bloom on the lit elements only, composited under everything so the traces
    # stay crisp. Baked, like every other glow in this project — GL Compatibility
    # on a single-threaded web export is not somewhere to depend on post-process.
    glow = img.filter(ImageFilter.GaussianBlur(2.2))
    out = Image.new("RGBA", (size, size), (*FLOOR_BASE, 255))
    out.alpha_composite(Image.blend(out, glow, 0.45))
    out.alpha_composite(img)
    out.save(SPRITES / "floor.png")
    print(f"sprite floor.png {size}x{size} circuit")


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
    # THE BESTAGON: the player is a hexagon, and nothing hostile is, until the
    # 10:00 mirror. Six sides is the whole premise, so it is the one silhouette
    # the player must never mistake for anything else on screen.
    #
    # Split into BODY and CORE as two sprites. Playtest 2026-08-02: "main character
    # lacks personality", and a hexagon cannot express motion by rotating — six-fold
    # symmetry means 60 degrees looks identical to 0. Breaking the symmetry from the
    # INSIDE is the only option left once deforming the shell is ruled out (it was,
    # emphatically: "I dislike that it thins out when moving"). A core that slides
    # toward the trailing edge sells weight while the body stays frame-exact, so it
    # costs nothing in input latency. The same node then carries every state the
    # player needs to read: hit, low HP, dash ready, firing.
    #
    # Both grew 10% with the rest of the roster.
    neon_sprite("player_body.png", 18, "hexagon", "player", radius=6.5, core_ratio=0.0)
    neon_sprite("player_core.png", 10, "hexagon", "player_core", radius=3.3,
                core_ratio=0.8, glow=1.5, glow_alpha=0.85)
    # The AEGIS bubble. A RING at ~2.4x the player body, because the shield used
    # to be nothing but a cyan tint on an already-cyan player -- a playtester's
    # words were "practically invisible, cant tell when its on or off". Tint is
    # the wrong channel entirely here: the colour law already spends hue on
    # allegiance, so the player's own colour cannot also encode a timed buff.
    # Pattern is the free channel (see neon_sprite's `hollow` docstring), and a
    # ring around the body is legible at a glance without hiding the body.
    neon_sprite("player_shield.png", 44, "hexagon", "player_core", radius=15.5,
                core_ratio=0.0, glow=2.6, glow_alpha=0.5, hollow=0.88)
    neon_sprite("bullet.png", 8, "diamond", "bullet", radius=2.5, core_ratio=0.5,
                glow=1.1, glow_alpha=0.7)
    neon_sprite("orbital.png", 8, "square", "orbital", radius=2.5, core_ratio=0.5,
                glow=1.1, glow_alpha=0.7)
    # Smaller (radius 3.2 -> 2.5) alongside the shorter idle timeout in
    # xp_gem.gd. Two halves of the same fix: fewer gems on the floor at once, and
    # each one reading as TEXTURE rather than as an object competing with the
    # enemies. Enemies grew 20-30% in the same pass, so holding the gem size
    # would have widened the gap anyway.
    neon_sprite("gem.png", 10, "diamond", "gem", radius=2.5, core_ratio=0.46,
                glow=1.3, glow_alpha=0.6)

    # The title wordmark's hexagon, on its OWN canvas at 96px rather than the
    # 16px player sprite scaled up 4.5x. M1's gate is "a static screenshot with
    # the HUD hidden already looks designed", and a magnified 16px sprite reads
    # as a blurry blob at any filter setting - the shape the whole game is named
    # after has to be crisp in the one image that earns the click.
    neon_sprite("title_mark.png", 96, "hexagon", "player", radius=34.0,
                core_ratio=0.44, glow=6.0, glow_alpha=0.5)

    # Enemies — GREYSCALE, tinted per type at runtime. enemy.png stays the
    # Drifter default so existing scenes keep working.
    #
    # NO ENEMY IS A HEXAGON. Shape is the FAMILY, size and colour are the
    # VARIANT, and `hollow` is the pattern channel. Hue alone can no longer carry
    # type: seven enemies already exhausted the hostile band, which is exactly
    # what findings 8 (Ram wore the Dart's triangle) and 18 (Splitter sat in
    # reserved bolt-yellow) were symptoms of.
    # Canvas is 24px, up from 16. Playtest 2026-08-02 raised every enemy roughly
    # 20-30% (see resources/enemy_size.gd), and enemy.gd renders a sprite at
    # `size / texture_width` — so at 16px the whole roster would have been drawn
    # at 1.2-1.5x with nearest filtering, turning clean polygon edges into stairs.
    # Authoring at the size things are actually drawn keeps them crisp. Radii and
    # glow scale by the same 1.5.
    for name, shape in (("enemy.png", "square"), ("enemy_drifter.png", "square"),
                        ("enemy_lancer.png", "chevron")):
        neon_sprite(name, 24, shape, "enemy", radius=8.25, core_ratio=0.5, glow=2.9)

    # Dart: a needle, not a triangle. The triangle belongs to the enemy BOLT and
    # sharing it made the Dart read as an oversized piece of enemy fire.
    neon_sprite("enemy_dart.png", 24, "sliver", "enemy", radius=9.6,
                core_ratio=0.45, glow=2.9)

    # Bulwark: a thick armoured ring. Hollow says "shell" without a second hue,
    # and the HP wall should look like one rather than like a big Drifter.
    neon_sprite("enemy_bulwark.png", 24, "octagon", "enemy", radius=8.7,
                core_ratio=0.94, hollow=0.58, glow=2.9)
    # Splitter: hollow because there is literally something inside it. The
    # pattern IS the mechanic — a shape with a void reads as "this will open".
    neon_sprite("enemy_splitter.png", 24, "diamond", "enemy", radius=8.4,
                core_ratio=0.95, hollow=0.5, glow=2.9)
    # Ram: its own silhouette at last, and the only enemy that rotates.
    neon_sprite("enemy_ram.png", 24, "wedge", "enemy", radius=9.6,
                core_ratio=0.5, glow=2.9)

    # Enemy fire is bigger and hotter than the player's: it has to read as a
    # threat across a busy screen, and the playtest asked for more menace.
    neon_sprite("bolt.png", 12, "triangle", "bolt", radius=4.4, core_ratio=0.46,
                glow=2.0, glow_alpha=0.85)
    neon_sprite("health.png", 12, "chevron", "health", radius=4.0, core_ratio=0.5,
                glow=1.8, glow_alpha=0.7)
    # The boss is the one place detail is affordable, so it gets its own canvas
    # rather than a scaled-up enemy. Greyscale — boss.gd tints core and shards.
    neon_sprite("boss_core.png", 32, "pentagon", "enemy", radius=11.5,
                core_ratio=0.54, glow=3.2, glow_alpha=0.6)

    # NOGAXEH — the 10:00 mirror, and the ONLY hostile hexagon in the game. The
    # silhouette rule holds for ten minutes and then breaks exactly once, here,
    # and the break is the reveal.
    #
    # Hollow and much larger than the player, because "a hexagon that is not you"
    # has to be legible in the half-second before colour registers: a honeycomb
    # CELL rather than a filled shape. Hue finishes the job — it sits in the
    # hostile band, the player is cyan.
    neon_sprite("boss_mirror.png", 40, "hexagon", "enemy", radius=14.6,
                core_ratio=0.92, hollow=0.54, glow=3.6, glow_alpha=0.62)

    # The shield membrane. FILLED where boss_mirror is a ring, so raising it
    # visibly SEALS the cell -- the silhouette itself announces invulnerability
    # and no text is required. Sized to sit just inside the ring.
    neon_sprite("boss_shield.png", 40, "hexagon", "shield", radius=13.4,
                core_ratio=0.55, glow=2.6, glow_alpha=0.45)

    # Power-ups: one hue, four silhouettes (colour law - hue is allegiance).
    for name, shape in (("pu_shield.png", "octagon"), ("pu_power.png", "plus"),
                        ("pu_haste.png", "bolt"), ("pu_collect.png", "star")):
        neon_sprite(name, 14, shape, "powerup", radius=5.0, core_ratio=0.5,
                    glow=1.9, glow_alpha=0.8)

    write_floor()

    # Audio is no longer synthesized here — music is composed in Strudel under
    # audio_src/ (tools/build_music.py) and SFX under audio_src/sfx/
    # (tools/build_sfx.py). The stdlib helpers above (sweep/blips/noise_burst)
    # are kept only as the reference implementation of that first approach.


if __name__ == "__main__":
    main()
