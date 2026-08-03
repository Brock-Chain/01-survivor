"""Strudel stems -> a single self-contained HTML piano-roll you can SEE and HEAR.

    python tools/score_viewer.py             # every track, one page, with a selector
    python tools/score_viewer.py gameplay    # just the gameplay_*.ogg stems
    python tools/score_viewer.py title

Writes .ai/score.html (all tracks) or .ai/score_<prefix>.html — one file, no CDN,
no sidecar assets. The .ogg audio is embedded as a base64 data: URI and the note
data as a JS literal, so the page works offline, survives being emailed, and
needs no server.

Where the notes come from: the Strudel renderer drops a sidecar
`<name>.wav.events.json` next to every .wav it renders (audio_src/). That file is
the score — every scheduled event with its start, duration, hz, sound and the
effect params it was given. This tool never re-renders anything; if a sidecar is
missing it says so and tells you to run tools/build_music.py.

Four things worth knowing:

1. PITCH COMES FROM hz, NOT THE NOTE NAME. Names are optional in the sidecar
   (drum samples have none) and Strudel writes them lowercase with mixed
   accidental spellings. `69 + 12*log2(hz/440)` is unambiguous, sorts correctly,
   and lets synth and sample events share one layout pass.

2. dur_s IS THE SLOT, NOT THE SOUND. Strudel reports how much of the cycle an
   event was handed, not how long it is audible. For a one-shot sample that is
   meaningless — `s("bd*4")` gives every kick a 0.5s slot and a lone `cr` in
   `<cr ~ ~ ~ ~ ~ ~ ~>` gets the whole 2s cycle, while the actual samples are a
   tenth of that. So percussion is drawn as an ONSET MARKER (a diamond), never a
   bar. For a synth the slot really is the gate, so it keeps its bar — with the
   envelope's release drawn after it as a faded tail, because that part is heard
   but is not part of the gate.

3. THE ROLL IS DRAWN TWICE. Grid + idle notes go onto an offscreen canvas once;
   each animation frame just blits that and overdraws the handful of notes
   currently sounding. Redrawing every note every frame is what makes these
   viewers stutter, and the static layer never changes between resizes.

4. THE CODE VIEW HIGHLIGHTS BARS, NOT NOTES. These .strudel files are authored
   as `<[cell] [cell] ...>`, where one top-level cell is one cycle — so the
   active cell is `floor(cycle * rate) % cellCount` and nothing more than a
   bracket-depth scan is needed to find the cells. That is deliberately NOT a
   Strudel parser, and the UI says so.
"""
from __future__ import annotations

import argparse
import base64
import json
import math
import re
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "audio_src"
MUSIC = ROOT / "assets" / "audio" / "music"
OUTDIR = ROOT / ".ai"

DEFAULT_CPS = 0.5

# Reading order for the selector; anything unknown is appended alphabetically.
PREFERRED_TRACKS = ["gameplay", "track2", "track3", "track4", "title", "victory"]

# In-game names (music.gd TRACK_NAMES), so the page says LIGHTCYCLE, not TRACK4.
TRACK_LABELS = {"gameplay": "NEON", "track2": "DARKSYNTH",
                "track3": "OUTRUN", "track4": "LIGHTCYCLE"}

# Drum lanes read top-to-bottom the way a drummer sits behind the kit:
# cymbals up high, kick on the floor. Anything unrecognised lands just above bd.
PERC_ORDER = ["cr", "ho", "hc", "hh", "cb", "click", "metal", "east",
              "perc", "rs", "cp", "sn", "sd", "bd"]

# Everything else in an event is an effect parameter and goes to the tooltip.
# `release` is pulled out here because it is drawn, not just described.
CORE_KEYS = {"begin_s", "dur_s", "begin_cycle", "hz", "wave", "kind", "note", "s",
             "gain", "release"}

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

JS_KEYWORDS = {"const", "let", "var", "function", "return", "if", "else",
               "true", "false", "null", "await", "async", "new"}


def midi_from_hz(hz: float | None) -> int | None:
    if not hz or hz <= 0:
        return None
    return int(round(69 + 12 * math.log2(hz / 440.0)))


def pretty_note(raw: str | None, midi: int | None) -> str:
    """'c#5' -> 'C#5'. Falls back to the midi number when the name is absent."""
    if raw:
        return raw[0].upper() + raw[1:]
    if midi is None:
        return ""
    return f"{NOTE_NAMES[midi % 12]}{midi // 12 - 1}"


def stem_label(name: str, prefix: str) -> str:
    """gameplay_0_bass -> BASS.  title -> TITLE."""
    tail = name[len(prefix):] if name.startswith(prefix) else name
    tail = re.sub(r"^[_\-\s]*\d*[_\-\s]*", "", tail)
    return (tail or name).replace("_", " ").upper()


def infer_cycle_seconds(events: list[dict], fallback: float) -> float:
    """The sidecar carries both begin_s and begin_cycle, so the tempo is in the
    data — no need to trust a CLI flag that may not match how it was rendered."""
    ratios = [e["begin_s"] / e["begin_cycle"]
              for e in events
              if e.get("begin_cycle") and e.get("begin_s")]
    if not ratios:
        return fallback
    ratios.sort()
    return ratios[len(ratios) // 2]


# --------------------------------------------------------------------------
# .strudel source -> tinted segments + the cycle cells to highlight
# --------------------------------------------------------------------------

def tokenize_js(src: str) -> tuple[list[tuple[str, int, int]], list[tuple[int, int]]]:
    """A deliberately crude JS lexer: enough to tint the source and — the part
    that actually matters — to know which spans are string literals.

    Patterns must only ever be searched for INSIDE strings. These files discuss
    their own patterns in prose (`// this used `<...>*4``), so a naive scan for
    '<' finds commentary and highlights it forever.

    Returns (tokens covering every character, content ranges of string literals).
    """
    toks: list[tuple[str, int, int]] = []
    strings: list[tuple[int, int]] = []
    i, n = 0, len(src)
    while i < n:
        ch = src[i]
        if ch == "/" and i + 1 < n and src[i + 1] == "/":
            j = src.find("\n", i)
            j = n if j < 0 else j
            toks.append(("cm", i, j))
            i = j
        elif ch == "/" and i + 1 < n and src[i + 1] == "*":
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            toks.append(("cm", i, j))
            i = j
        elif ch in "\"'`":
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == ch or (ch != "`" and src[j] == "\n"):
                    break
                j += 1
            close = min(j, n)
            toks.append(("st", i, min(close + 1, n)))
            strings.append((i + 1, close))
            i = min(close + 1, n)
        elif ch.isdigit():
            j = i
            while j < n and (src[j].isdigit() or src[j] == "."):
                j += 1
            toks.append(("nu", i, j))
            i = j
        elif ch.isalpha() or ch in "_$":
            j = i
            while j < n and (src[j].isalnum() or src[j] in "_$"):
                j += 1
            k = j
            while k < n and src[k] in " \t":
                k += 1
            word = src[i:j]
            cls = "kw" if word in JS_KEYWORDS else ("fn" if k < n and src[k] == "(" else "id")
            toks.append((cls, i, j))
            i = j
        else:
            j = i
            while j < n:
                c = src[j]
                if c in "\"'`_$" or c.isalnum() or (c == "/" and j + 1 < n and src[j + 1] in "/*"):
                    break
                j += 1
            toks.append(("pn", i, max(j, i + 1)))
            i = max(j, i + 1)
    return toks, strings


def split_cells(src: str, a: int, b: int) -> list[tuple[int, int]]:
    """Top-level cells of a `<...>` body, by square-bracket depth. A cell is
    either a bracket group or a bare token; a trailing modifier (`*4`, `!2`)
    rides with the cell it modifies, since `[a b]*4` is still one bar."""
    cells: list[tuple[int, int]] = []
    k = a
    while k < b:
        if src[k].isspace():
            k += 1
            continue
        start = k
        if src[k] == "[":
            depth = 0
            while k < b:
                if src[k] == "[":
                    depth += 1
                elif src[k] == "]":
                    depth -= 1
                    if depth == 0:
                        k += 1
                        break
                k += 1
        else:
            while k < b and not src[k].isspace() and src[k] != "[":
                k += 1
        while k < b and not src[k].isspace() and src[k] != "[":
            k += 1
        cells.append((start, k))
    return cells


def find_slowcats(src: str, strings: list[tuple[int, int]]) -> list[dict]:
    """Every `<...>` inside a string literal, with its top-level cells.

    `rate` is how many cells are consumed per cycle: 1 normally, n for `<...>*n`
    (a slowcat sped up is n items per cycle), 1/n for `<...>/n`. Without it,
    `note("<a2 g2 ...>*8")` — a whole progression inside one bar — would light up
    one cell per cycle and drift eight times too slowly.
    """
    pats: list[dict] = []
    for s0, s1 in strings:
        i = s0
        while i < s1:
            if src[i] != "<":
                i += 1
                continue
            j, ang, sq = i + 1, 1, 0
            while j < s1:
                c = src[j]
                if c == "[":
                    sq += 1
                elif c == "]":
                    sq -= 1
                elif sq == 0 and c == "<":
                    ang += 1
                elif sq == 0 and c == ">":
                    ang -= 1
                    if ang == 0:
                        break
                j += 1
            if ang != 0 or j >= s1:
                break                       # unbalanced — leave the rest alone
            cells = split_cells(src, i + 1, j)
            rate = 1.0
            mod = re.match(r"\s*([*/])\s*(\d+(?:\.\d+)?)", src[j + 1:s1])
            if mod:
                v = float(mod.group(2)) or 1.0
                rate = v if mod.group(1) == "*" else 1.0 / v
            if cells:
                pats.append({"cells": cells, "rate": rate})
            i = j + 1
    return pats


def code_segments(src: str, toks: list[tuple[str, int, int]], pats: list[dict]) -> list[list]:
    """Flatten source into [class, text] runs, splitting any run that straddles a
    cell boundary so the JS can toggle a highlight by swapping a class on whole
    spans — no re-tinting, no innerHTML churn, no layout shift per cycle.

    Cell-bearing runs carry [class, text, patIndex, cellIndex, isFirstOfCell].
    """
    flat: list[tuple[int, int, int]] = []
    owner = [-1] * (len(src) + 1)
    for pi, pat in enumerate(pats):
        for ci, (a, b) in enumerate(pat["cells"]):
            idx = len(flat)
            flat.append((pi, ci, a))
            for k in range(a, b):
                owner[k] = idx

    segs: list[list] = []
    for cls, a, b in toks:
        k = a
        while k < b:
            o = owner[k]
            j = k
            while j < b and owner[j] == o:
                j += 1
            if o < 0:
                segs.append([cls, src[k:j]])
            else:
                pi, ci, start = flat[o]
                segs.append([cls, src[k:j], pi, ci, 1 if k == start else 0])
            k = j
    return segs


def load_source(name: str) -> tuple[list[list] | None, list[dict], str | None]:
    """(tinted segments, patterns, warning) for audio_src/<name>.strudel."""
    path = SRC / f"{name}.strudel"
    if not path.exists():
        return None, [], f"{name}: no {path.name}"
    try:
        src = path.read_text(encoding="utf-8")
    except OSError as exc:
        return None, [], f"{name}: {path.name} unreadable ({exc.__class__.__name__})"
    toks, strings = tokenize_js(src)
    pats = find_slowcats(src, strings)
    return code_segments(src, toks, pats), pats, None


def load_stem(ogg: Path, prefix: str) -> tuple[dict, list[str]]:
    """Returns (stem dict, warnings). A stem with no sidecar still plays; it just
    draws an empty roll with an explanation, which beats refusing to open."""
    name = ogg.stem
    events_path = SRC / f"{name}.wav.events.json"
    warnings: list[str] = []
    events: list[dict] = []

    if events_path.exists():
        try:
            events = json.loads(events_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            warnings.append(f"{name}: sidecar unreadable ({exc.__class__.__name__}) - re-render it")
            events = []
    else:
        warnings.append(f"{name}: no {events_path.name}")

    notes = []
    for e in events:
        hz = e.get("hz")
        midi = midi_from_hz(hz)
        params = {k: v for k, v in e.items() if k not in CORE_KEYS and v is not None}
        notes.append({
            "t": round(float(e.get("begin_s", 0.0)), 6),
            "d": round(float(e.get("dur_s", 0.0)), 6),
            "c": round(float(e.get("begin_cycle", 0.0)), 6),
            "m": midi,
            "n": pretty_note(e.get("note"), midi),
            "hz": round(hz, 2) if hz else None,
            "s": e.get("s") or e.get("wave") or "?",
            "k": e.get("kind", "synth"),
            "g": round(float(e.get("gain", 1.0)), 4),
            "r": round(float(e.get("release") or 0.0), 4),
            "p": params,
        })
    notes.sort(key=lambda n: (n["t"], -(n["m"] or 0)))

    code, pats, src_warning = load_source(name)
    if src_warning:
        warnings.append(src_warning)

    sounds = sorted({n["s"] for n in notes})
    stem = {
        "name": name,
        "label": stem_label(name, prefix),
        "file": ogg.name,
        "count": len(notes),
        "sounds": sounds,
        "pitched": sum(1 for n in notes if n["m"] is not None),
        "perc": sum(1 for n in notes if n["m"] is None),
        "notes": notes,
        "code": code,
        "pats": [{"n": len(p["cells"]), "rate": round(p["rate"], 6)} for p in pats],
        "cells": sum(len(p["cells"]) for p in pats),
    }
    return stem, warnings


def build_track(prefix: str, cps: float) -> tuple[dict | None, list[str]]:
    """One track = every <prefix>*.ogg, layered. None when the prefix matches
    nothing on disk."""
    oggs = sorted(MUSIC.glob(f"{prefix}*.ogg"))
    if not oggs:
        return None, []

    stems, warnings = [], []
    audio = {}
    for ogg in oggs:
        stem, warns = load_stem(ogg, prefix)
        warnings.extend(warns)
        audio[stem["name"]] = "data:audio/ogg;base64," + base64.b64encode(ogg.read_bytes()).decode("ascii")
        stems.append(stem)

    all_notes = [n for s in stems for n in s["notes"]]
    cycle_seconds = infer_cycle_seconds(
        [{"begin_s": n["t"], "begin_cycle": n["c"]} for n in all_notes], 1.0 / cps)
    # Span stays slot-based on purpose: release tails are drawn but must not
    # decide the loop length, or a 2.2s pad tail would invent a ninth cycle.
    span = max((n["t"] + n["d"] for n in all_notes), default=cycle_seconds)
    cycles = max(1, math.ceil(round(span / cycle_seconds, 3) - 1e-6))
    total = cycles * cycle_seconds

    score = {
        "prefix": prefix,
        "cycleSeconds": round(cycle_seconds, 6),
        "cps": round(1.0 / cycle_seconds, 6),
        "cycles": cycles,
        "total": round(total, 6),
        "stems": stems,
    }
    return {"id": prefix, "label": TRACK_LABELS.get(prefix, prefix.upper()),
            "score": score, "audio": audio}, warnings


def discover_prefixes() -> list[str]:
    found = {p.stem.split("_")[0] for p in MUSIC.glob("*.ogg")}
    return sorted(found, key=lambda p: (PREFERRED_TRACKS.index(p)
                                        if p in PREFERRED_TRACKS else len(PREFERRED_TRACKS), p))


def build(prefixes: list[str], cps: float, out: Path, page_title: str) -> int:
    tracks, warnings = [], []
    for prefix in prefixes:
        track, warns = build_track(prefix, cps)
        if track is None:
            have = discover_prefixes()
            print(f"no .ogg matching '{prefix}*' in {MUSIC}")
            print(f"known prefixes: {', '.join(have) if have else '(none - run python tools/build_music.py)'}")
            return 1
        warnings.extend(warns)
        tracks.append(track)

    if warnings:
        print("  ! missing source data:")
        for w in warnings:
            print(f"      {w}")
        print("      sidecars (.wav.events.json) are written at render time, next to the .wav")
        print("      fix:  python tools/build_music.py --force")

    have_notes = [t for t in tracks if any(s["count"] for s in t["score"]["stems"])]
    if not have_notes:
        print(f"\nnothing to draw - not one stem in {len(tracks)} track(s) has note data.")
        print("run:  python tools/build_music.py --force")
        return 1

    generated = datetime.now().strftime("%Y-%m-%d %H:%M")
    meta = [{"id": t["id"], "label": t["label"],
             "score": dict(t["score"], generated=generated)} for t in tracks]
    audio = {t["id"]: t["audio"] for t in tracks}

    html = (TEMPLATE
            .replace("__TITLE__", page_title)
            .replace("__TRACKS__", json.dumps(meta, separators=(",", ":")))
            .replace("__AUDIO__", json.dumps(audio, separators=(",", ":"))))

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")

    size = out.stat().st_size
    human = f"{size / 1048576:.2f} MB" if size >= 1048576 else f"{size / 1024:,.0f} KB"
    print(f"\n  {out}")
    print(f"  {human}  |  {len(tracks)} track(s)")
    for t in tracks:
        sc = t["score"]
        print(f"\n  {t['label']}  -  {len(sc['stems'])} stems  |  {sc['cycles']} cycles "
              f"@ cps {sc['cps']:.3f} = {sc['total']:.2f}s")
        for s in sc["stems"]:
            detail = f"{s['pitched']} pitched" + (f" + {s['perc']} perc" if s["perc"] else "")
            src = (f"{len(s['pats'])} pat/{s['cells']} cells" if s["code"] is not None
                   else "no .strudel")
            print(f"    {s['label']:<10} {s['count']:>4} notes  ({detail})  "
                  f"[{', '.join(s['sounds']) or 'none'}]  src: {src}")
    return 0


TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>__TITLE__</title>
<style>
  :root{
    --bg:#0b0c16; --panel:#12142240; --line:#78fff51f; --line-strong:#78fff53d;
    --cyan:#78fff5; --magenta:#ff4ab8; --ink:#d9e2f5; --dim:#7d88a8;
    --mono:ui-monospace,SFMono-Regular,Menlo,Consolas,"Liberation Mono",monospace;
  }
  *{box-sizing:border-box}
  html,body{margin:0;padding:0}
  body{
    background:
      radial-gradient(1100px 620px at 12% -8%, #1a1f4a55, transparent 62%),
      radial-gradient(900px 520px at 92% 0%, #ff4ab814, transparent 60%),
      var(--bg);
    color:var(--ink);
    font:14px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
    min-height:100vh; padding:22px 22px 60px;
  }
  .wrap{max-width:1500px;margin:0 auto}

  header{display:flex;flex-wrap:wrap;align-items:baseline;gap:8px 16px;margin-bottom:4px}
  h1{
    margin:0;font:600 21px/1.1 var(--mono);letter-spacing:.16em;text-transform:uppercase;
    color:var(--cyan);text-shadow:0 0 22px #78fff53d;
  }
  h1 b{color:var(--magenta);font-weight:600;text-shadow:0 0 22px #ff4ab84d}
  .meta{font:11px/1 var(--mono);color:var(--dim);letter-spacing:.09em;display:flex;flex-wrap:wrap;gap:14px}
  .meta i{font-style:normal;color:var(--cyan)}

  .transport{
    display:flex;align-items:center;gap:14px;flex-wrap:wrap;
    margin:16px 0 12px;padding:11px 14px;border-radius:12px;
    background:linear-gradient(180deg,#161a3055,#0e1020aa);
    border:1px solid var(--line);
  }
  button{
    font:600 11px/1 var(--mono);letter-spacing:.12em;text-transform:uppercase;
    color:var(--ink);background:#1a1f3a80;border:1px solid #78fff52e;
    padding:8px 12px;border-radius:7px;cursor:pointer;transition:.14s;
  }
  button:hover{border-color:var(--cyan);color:var(--cyan);background:#78fff514}
  button:active{transform:translateY(1px)}
  #play{min-width:96px;border-color:#78fff566;color:var(--cyan);background:#78fff512}
  #play.on{background:var(--magenta);border-color:var(--magenta);color:#12021a;box-shadow:0 0 22px #ff4ab84d}
  button.tog.on{border-color:var(--magenta);color:var(--magenta);background:#ff4ab814}
  .clock{font:600 20px/1 var(--mono);color:var(--cyan);letter-spacing:.05em;min-width:118px}
  .clock small{font-size:11px;color:var(--dim);letter-spacing:.1em}
  .spacer{flex:1}
  .hint{font:10px/1.6 var(--mono);color:var(--dim);letter-spacing:.06em}

  select{
    font:600 11px/1 var(--mono);letter-spacing:.12em;text-transform:uppercase;
    color:var(--cyan);background:#1a1f3a99;border:1px solid #78fff54d;
    padding:8px 10px;border-radius:7px;cursor:pointer;
  }
  select:hover{border-color:var(--cyan)}
  .picker{display:flex;align-items:center;gap:8px}
  .picker label{font:10px/1 var(--mono);letter-spacing:.14em;color:var(--dim);text-transform:uppercase}
  .tabs{display:flex;gap:0;border:1px solid #78fff52e;border-radius:8px;overflow:hidden}
  .tabs button{border:0;border-radius:0;background:transparent}
  .tabs button + button{border-left:1px solid #78fff52e}
  .tabs button.on{background:#78fff51a;color:var(--cyan)}

  .stack{position:relative}
  body.code .stack{display:none}
  #codeview{display:none}
  body.code #codeview{display:block}

  .block{
    position:relative;margin-bottom:10px;padding:0 0 6px;border-radius:12px;
    background:linear-gradient(180deg,#141830a8,#0d0f1e9e);
    border:1px solid var(--line);overflow:hidden;transition:opacity .18s;
  }
  .block.off{opacity:.24}
  .bhead{display:flex;align-items:center;gap:10px;padding:8px 12px 7px;border-bottom:1px solid var(--line)}
  .bname{font:600 12px/1 var(--mono);letter-spacing:.2em;color:var(--cyan);min-width:74px}
  .tag{
    font:10px/1 var(--mono);letter-spacing:.08em;color:var(--dim);
    border:1px solid #78fff51f;border-radius:99px;padding:4px 8px;
  }
  .tag.n{color:var(--magenta);border-color:#ff4ab833}
  .bhead .spacer{flex:1}
  .bhead button{padding:5px 9px}
  canvas{display:block;width:100%;cursor:crosshair}
  .empty{padding:20px 16px;font:11px/1.7 var(--mono);color:var(--dim);letter-spacing:.05em}
  .empty b{color:var(--magenta);font-weight:600}

  #ruler{display:block;width:100%;height:30px}
  .rulerbox{margin-bottom:6px;padding:0 1px}

  #head{
    position:absolute;top:0;bottom:0;left:0;width:2px;pointer-events:none;
    background:linear-gradient(180deg,#ff4ab8,#ff4ab8cc);
    box-shadow:0 0 14px #ff4ab8cc,0 0 34px #ff4ab866;
    will-change:transform;z-index:5;
  }
  #head::before{
    content:"";position:absolute;top:-1px;left:-4px;width:10px;height:10px;
    border-radius:50%;background:var(--magenta);box-shadow:0 0 12px #ff4ab8;
  }

  #tip{
    position:fixed;z-index:20;pointer-events:none;opacity:0;transform:translateY(4px);
    transition:opacity .1s;min-width:170px;max-width:290px;padding:9px 11px;border-radius:9px;
    background:#0a0b16f2;border:1px solid #78fff54d;
    box-shadow:0 12px 34px #000a,0 0 22px #78fff51f;
    font:11px/1.55 var(--mono);letter-spacing:.03em;
  }
  #tip.on{opacity:1;transform:translateY(0)}
  #tip h4{margin:0 0 5px;font:600 14px/1.2 var(--mono);color:var(--magenta);letter-spacing:.06em}
  #tip .row{display:flex;justify-content:space-between;gap:14px;color:var(--dim)}
  #tip .row span{color:var(--ink)}
  #tip .fx{margin-top:6px;padding-top:5px;border-top:1px solid #78fff51f;color:var(--cyan);font-size:10px}

  /* ---- code view ---- */
  .caption{
    margin:0 0 10px;padding:9px 12px;border-radius:10px;
    border:1px solid #ff4ab829;background:#ff4ab80a;
    font:10px/1.7 var(--mono);color:var(--dim);letter-spacing:.06em;
  }
  .caption b{color:var(--magenta);font-weight:600}
  pre.code{
    margin:0;padding:13px 15px;overflow-x:auto;white-space:pre;
    font:11.5px/1.62 var(--mono);letter-spacing:.01em;color:#c3cde6;
  }
  .tcm{color:#57608a;font-style:italic}
  .tst{color:#78fff5}
  .tnu{color:#f2c17b}
  .tfn{color:#ff4ab8}
  .tkw{color:#a98cff}
  .tid{color:#c3cde6}
  .tpn{color:#7f8aab}
  .on-cell{background:#ff4ab826;border-radius:2px}
  /* box-shadow, not border: a border on a span that toggles every cycle would
     reflow the whole line of code once per bar. */
  .on-cell.cs{box-shadow:-3px 0 0 0 var(--magenta),0 0 16px #ff4ab826}

  #sysbar{margin-top:0}
  .syslab{font:600 10px/1 var(--mono);letter-spacing:.18em;color:var(--magenta);text-transform:uppercase}
  #sysstatus{color:var(--cyan)}
  #sysbar button.trk.on{background:#ff4ab822;border-color:var(--magenta);color:var(--magenta)}
  #sysbar button.tier.on{background:#78fff51a;color:var(--cyan);border-color:var(--cyan)}

  footer{margin-top:16px;font:10px/1.8 var(--mono);color:var(--dim);letter-spacing:.06em}
  footer b{color:var(--cyan);font-weight:400}
  .legend{display:flex;flex-wrap:wrap;align-items:center;gap:6px 18px;margin-bottom:6px}
  .legend span{display:flex;align-items:center;gap:7px}
  .sw{display:inline-block;flex:none}
  .sw-gate{width:16px;height:8px;border-radius:2px;background:#78fff5cc}
  .sw-tail{width:22px;height:8px;border-radius:2px;
           background:linear-gradient(90deg,#78fff5cc 0 34%,#78fff566 34%,#78fff500)}
  .sw-perc{width:9px;height:9px;background:#78fff5cc;transform:rotate(45deg)}
  .sw-now{width:16px;height:8px;border-radius:2px;background:var(--magenta);box-shadow:0 0 10px #ff4ab8aa}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>Score <b>/</b> <span id="title"></span></h1>
    <div class="meta" id="meta"></div>
  </header>

  <div class="transport">
    <div class="picker" id="picker"><label for="track">Track</label><select id="track"></select></div>
    <button id="play">&#9654; Play</button>
    <button id="stop">&#9632; Stop</button>
    <div class="clock"><span id="t">0:00.00</span> <small id="cyc">cycle 1.00</small></div>
    <button id="loop" class="tog on">Loop</button>
    <div class="tabs"><button id="tabRoll" class="on">Roll</button><button id="tabCode">Code</button></div>
    <div class="spacer"></div>
    <div class="hint">click roll to seek &nbsp;&middot;&nbsp; hover a note for detail &nbsp;&middot;&nbsp; space = play/pause</div>
  </div>

  <!-- The adaptive engine, verbatim: same constants and same behaviour as
       scripts/music.gd (tiers fade stems, switches wait for the bar line and
       crossfade phase-locked, rotation ping-pongs the circle of fifths). -->
  <div class="transport" id="sysbar">
    <span class="syslab">System</span>
    <div class="tabs" id="systracks"></div>
    <span class="syslab">Tier</span>
    <div class="tabs" id="systiers"></div>
    <button id="sysauto" class="tog">Chain</button>
    <div class="picker"><label for="sysbars">every</label><select id="sysbars">
      <option value="8">8 bars</option><option value="12">12 bars</option>
      <option value="16">16 bars</option><option value="4">4 bars</option></select></div>
    <button id="sysstop">&#9632; Off</button>
    <div class="spacer"></div>
    <div class="hint" id="sysstatus">off &mdash; pick a track to start the adaptive engine</div>
  </div>

  <div class="stack" id="stack">
    <div class="rulerbox"><canvas id="ruler"></canvas></div>
    <div id="blocks"></div>
    <div id="head"></div>
  </div>

  <div id="codeview">
    <p class="caption">
      the <b>.strudel</b> source, highlighted as it plays. the highlight is
      <b>cycle-level, not note-level</b>: for every <b>&lt;...&gt;</b> pattern it marks the
      cell that owns the current bar. it is a bracket scan, not a Strudel interpreter &mdash;
      what happens inside a cell is not tracked.
    </p>
    <div id="codeblocks"></div>
  </div>

  <footer id="foot"></footer>
</div>

<div id="tip"></div>

<script>
const TRACKS = __TRACKS__;   // [{id,label,score}] - notes + tinted source, no audio
const AUDIO  = __AUDIO__;    // {trackId:{stemName:dataURI}} - kept apart so a switch can drop it

const CYAN = "#78fff5", MAG = "#ff4ab8";
const PAD = 46;              // left key-strip inside every canvas; keeps all rolls aligned
const PERC_ORDER = ["cr","ho","hc","hh","cb","click","metal","east","perc","rs","cp","sn","sd","bd"];
const NAMES = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"];
const BLACK = {1:1,3:1,6:1,8:1,10:1};
const PERC_FLASH = 0.09;     // a one-shot has no gate to light up, so give it a blink
const dpr = () => Math.min(window.devicePixelRatio || 1, 2);
const cy = a => `rgba(120,255,245,${a})`;
const mg = a => `rgba(255,74,184,${a})`;
const isPerc = n => n.m === null || n.m === undefined;

let SCORE = null, stems = [], total = 0, trackId = null, view = "roll";

/* ---------- layout: one row per pitch, then one lane per drum sound ---------- */
function layout(stem){
  const rows = [], index = new Map();
  const pitched = stem.notes.filter(n => !isPerc(n));
  if (pitched.length){
    let lo = Infinity, hi = -Infinity;
    for (const n of pitched){ if (n.m < lo) lo = n.m; if (n.m > hi) hi = n.m; }
    lo -= 1; hi += 1;
    for (let m = hi; m >= lo; m--){ index.set("m" + m, rows.length); rows.push({kind:"pitch", m}); }
  }
  const percSounds = [...new Set(stem.notes.filter(isPerc).map(n => n.s))];
  percSounds.sort((a,b) => {
    const ia = PERC_ORDER.indexOf(a), ib = PERC_ORDER.indexOf(b);
    return (ia < 0 ? PERC_ORDER.length - 1 : ia) - (ib < 0 ? PERC_ORDER.length - 1 : ib);
  });
  if (percSounds.length && rows.length) rows.push({kind:"gap"});
  for (const s of percSounds){ index.set("s" + s, rows.length); rows.push({kind:"perc", s}); }
  if (!rows.length) rows.push({kind:"gap"});

  const rowH = Math.max(4.5, Math.min(15, 210 / rows.length));
  const gains = stem.notes.map(n => n.g);
  const gmax = Math.max(0.0001, ...gains), gmin = Math.min(...gains, gmax);
  for (const n of stem.notes){
    n._row = index.get(isPerc(n) ? "s" + n.s : "m" + n.m) ?? 0;
    n._rel = gmax > gmin ? (n.g - gmin) / (gmax - gmin) : 1;
  }
  return {rows, rowH, height: Math.round(rows.length * rowH) + 8};
}

/* ---------- DOM: rebuilt from scratch on every track switch ---------- */
const blocksEl = document.getElementById("blocks");
const codeEl = document.getElementById("codeblocks");

function buildBlocks(){
  blocksEl.innerHTML = "";
  for (const stem of stems){
    stem.L = layout(stem);
    const el = document.createElement("div");
    el.className = "block";
    const tags = stem.count
      ? `<span class="tag n">${stem.count} notes</span>` +
        stem.sounds.map(s => `<span class="tag">${s}</span>`).join("")
      : `<span class="tag">no data</span>`;
    el.innerHTML =
      `<div class="bhead"><div class="bname">${stem.label}</div>${tags}<div class="spacer"></div>` +
      `<button class="tog mute">Mute</button><button class="tog solo">Solo</button></div>` +
      (stem.count
        ? `<canvas></canvas>`
        : `<div class="empty">no note data for <b>${stem.name}</b> &mdash; the sidecar ` +
          `<b>audio_src/${stem.name}.wav.events.json</b> is written at render time.<br>` +
          `run <b>python tools/build_music.py --force</b>, then rebuild this page.</div>`);
    blocksEl.appendChild(el);
    stem.el = el;
    stem.canvas = el.querySelector("canvas");
    stem.ctx = null;
    stem.static = document.createElement("canvas");
    stem.muted = false; stem.solo = false; stem.activeKey = "";
    el.querySelector(".mute").onclick = e => { stem.muted = !stem.muted; e.target.classList.toggle("on", stem.muted); applyMix(); };
    el.querySelector(".solo").onclick = e => { stem.solo = !stem.solo; e.target.classList.toggle("on", stem.solo); applyMix(); };
    if (stem.canvas) wirePointer(stem);
  }
}

function buildCode(){
  codeEl.innerHTML = "";
  for (const stem of stems){
    const el = document.createElement("div");
    el.className = "block";
    const pats = stem.pats || [];
    el.innerHTML =
      `<div class="bhead"><div class="bname">${stem.label}</div>` +
      `<span class="tag">audio_src/${stem.name}.strudel</span><div class="spacer"></div>` +
      (stem.code ? `<span class="tag n">${pats.length} &lt;&gt; pattern${pats.length === 1 ? "" : "s"}</span>` +
                   `<span class="tag">${pats.reduce((a,p) => a + p.n, 0)} cells</span>` : "");
    stem.cellSpans = null; stem.cellNow = null;
    if (!stem.code){
      el.innerHTML += `<div class="empty">no source for <b>${stem.name}</b> &mdash; ` +
        `<b>audio_src/${stem.name}.strudel</b> was not found when this page was built.</div>`;
    } else {
      const pre = document.createElement("pre");
      pre.className = "code";
      const spans = pats.map(() => []);
      for (const seg of stem.code){
        const sp = document.createElement("span");
        sp.className = "t" + seg[0] + (seg.length > 2 && seg[4] ? " cs" : "");
        sp.textContent = seg[1];
        pre.appendChild(sp);
        if (seg.length > 2){
          const bucket = spans[seg[2]];
          (bucket[seg[3]] || (bucket[seg[3]] = [])).push(sp);
        }
      }
      el.appendChild(pre);
      stem.cellSpans = spans;
      stem.cellNow = pats.map(() => -1);
    }
    codeEl.appendChild(el);
  }
}

function fillMeta(){
  document.getElementById("title").textContent = SCORE.prefix;
  // each item needs its own element: the meta bar is a flex row, and loose text
  // between the <i> tags collapses into ONE anonymous flex item, so the gap
  // lands in the wrong places and the labels run together ("8 cyclescps 0.50")
  document.getElementById("meta").innerHTML = [
    `<i>${SCORE.cycles}</i> cycles`,
    `cps <i>${SCORE.cps.toFixed(2)}</i>`,
    `<i>${total.toFixed(2)}</i> s loop`,
    `<i>${stems.reduce((a,s) => a + s.count, 0)}</i> events`,
    `built <i>${SCORE.generated}</i>`,
  ].map(s => `<span>${s}</span>`).join("");
}

document.getElementById("foot").innerHTML =
  `<div class="legend">` +
  `<span><i class="sw sw-gate"></i> synth gate (dur)</span>` +
  `<span><i class="sw sw-tail"></i> + envelope release, faded</span>` +
  `<span><i class="sw sw-perc"></i> one-shot onset &mdash; the sample sets its own length, not the slot</span>` +
  `<span><i class="sw sw-now"></i> sounding now</span>` +
  `</div>` +
  `bar lines every <b id="footcyc"></b> (1 cycle), faint lines mark quarters &nbsp;&middot;&nbsp; ` +
  `brightness = <b>gain</b> &nbsp;&middot;&nbsp; ` +
  `source: <b>audio_src/*.strudel</b> &rarr; renderer sidecars`;

/* ---------- drawing ---------- */
const ruler = document.getElementById("ruler");
let W = 0;

function x2t(x){ return Math.max(0, Math.min(total, (x - PAD) / (W - PAD) * total)); }
function t2x(t){ return PAD + t / total * (W - PAD); }

function sizeCanvas(c, h){
  const r = dpr();
  c.width = Math.round(W * r); c.height = Math.round(h * r);
  c.style.height = h + "px";
  const ctx = c.getContext("2d");
  ctx.setTransform(r, 0, 0, r, 0, 0);
  return ctx;
}

function drawRuler(){
  const h = 30, ctx = sizeCanvas(ruler, h);
  ctx.clearRect(0, 0, W, h);
  ctx.font = "10px ui-monospace,Menlo,Consolas,monospace";
  ctx.textBaseline = "middle";
  ctx.fillStyle = "#7d88a8"; ctx.textAlign = "right";
  ctx.fillText("cycle", PAD - 8, h / 2);
  for (let c = 0; c <= SCORE.cycles; c++){
    const x = t2x(c * SCORE.cycleSeconds);
    ctx.strokeStyle = c === SCORE.cycles ? "#78fff52e" : "#78fff54d";
    ctx.beginPath(); ctx.moveTo(x + .5, h - 9); ctx.lineTo(x + .5, h); ctx.stroke();
    if (c < SCORE.cycles){
      ctx.fillStyle = CYAN; ctx.textAlign = "left";
      ctx.fillText(String(c + 1), x + 5, h / 2 - 3);
      ctx.fillStyle = "#7d88a8";
      ctx.fillText((c * SCORE.cycleSeconds).toFixed(1) + "s", x + 5, h / 2 + 9);
    }
    for (let q = 1; q < 4 && c < SCORE.cycles; q++){
      const xq = t2x((c + q / 4) * SCORE.cycleSeconds);
      ctx.strokeStyle = "#78fff51a";
      ctx.beginPath(); ctx.moveTo(xq + .5, h - 5); ctx.lineTo(xq + .5, h); ctx.stroke();
    }
  }
  ctx.strokeStyle = "#78fff52e";
  ctx.beginPath(); ctx.moveTo(0, h - .5); ctx.lineTo(W, h - .5); ctx.stroke();
}

function rrect(ctx, x, y, w, h, r){
  r = Math.min(r, h / 2, w / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y); ctx.lineTo(x + w - r, y); ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r); ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h); ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r); ctx.quadraticCurveTo(x, y, x + r, y); ctx.closePath();
}

/* Geometry lives in one place because the roll, the hit test and the "sounding
   now" overdraw must agree about what a note occupies. */
function geom(stem, n){
  const rowH = stem.L.rowH;
  const y = 4 + n._row * rowH, h = Math.max(3, rowH - 1.6), cyy = y + rowH / 2;
  if (isPerc(n)){
    return {perc:true, cx: t2x(n.t), cy: cyy, r: Math.max(2.4, Math.min(5.5, rowH * 0.58)), y, h};
  }
  const x = t2x(n.t);
  const gw = Math.max(2, t2x(n.t + n.d) - x);
  const tw = n.r ? Math.max(0, t2x(n.t + n.d + n.r) - t2x(n.t + n.d)) : 0;
  return {perc:false, x, y, h, gw, tw, cy: cyy};
}

function diamond(ctx, cx, cyy, r){
  ctx.beginPath();
  ctx.moveTo(cx, cyy - r); ctx.lineTo(cx + r, cyy);
  ctx.lineTo(cx, cyy + r); ctx.lineTo(cx - r, cyy);
  ctx.closePath();
}

/* `col` is a function alpha -> css colour, so idle (cyan) and sounding (magenta)
   share one drawing routine and can never drift apart. */
function drawNote(ctx, g, col, a){
  if (g.perc){
    ctx.fillStyle = col(a * 0.35);
    ctx.fillRect(g.cx - 0.5, g.y, 1, g.h);          // onset line: readable when lanes get thin
    ctx.fillStyle = col(a);
    diamond(ctx, g.cx, g.cy, g.r); ctx.fill();
    return;
  }
  if (g.tw > 0.7){
    const th = Math.max(2, g.h * 0.42), x0 = g.x + g.gw;
    const grad = ctx.createLinearGradient(x0, 0, x0 + g.tw, 0);
    grad.addColorStop(0, col(a * 0.5));
    grad.addColorStop(1, col(0));
    ctx.fillStyle = grad;
    ctx.fillRect(x0, g.cy - th / 2, g.tw, th);
  }
  ctx.fillStyle = col(a);
  rrect(ctx, g.x, g.y, g.gw, g.h, 2); ctx.fill();
}

function drawStatic(stem){
  const {rows, rowH, height} = stem.L;
  const r = dpr();
  stem.static.width = Math.round(W * r); stem.static.height = Math.round(height * r);
  const ctx = stem.static.getContext("2d");
  ctx.setTransform(r, 0, 0, r, 0, 0);
  ctx.clearRect(0, 0, W, height);
  ctx.font = "9px ui-monospace,Menlo,Consolas,monospace";
  ctx.textBaseline = "middle";

  // key strip + row bands
  rows.forEach((row, i) => {
    const y = 4 + i * rowH;
    if (row.kind === "pitch"){
      if (BLACK[((row.m % 12) + 12) % 12]) { ctx.fillStyle = "#ffffff08"; ctx.fillRect(PAD, y, W - PAD, rowH); }
      if (row.m % 12 === 0){
        ctx.strokeStyle = "#78fff526";
        ctx.beginPath(); ctx.moveTo(PAD, y + .5); ctx.lineTo(W, y + .5); ctx.stroke();
        ctx.fillStyle = "#78fff5aa"; ctx.textAlign = "right";
        ctx.fillText("C" + (Math.floor(row.m / 12) - 1), PAD - 8, y + rowH / 2);
      }
      ctx.fillStyle = BLACK[((row.m % 12) + 12) % 12] ? "#161b2e" : "#2a3252";
      ctx.fillRect(PAD - 6, y + .5, 4, Math.max(1, rowH - 1));
    } else if (row.kind === "perc"){
      ctx.fillStyle = "#ff4ab80a"; ctx.fillRect(PAD, y, W - PAD, rowH);
      ctx.fillStyle = "#ff4ab8cc"; ctx.textAlign = "right";
      ctx.fillText(row.s, PAD - 8, y + rowH / 2);
    }
  });

  // bar + quarter lines
  for (let c = 0; c <= SCORE.cycles; c++){
    for (let q = 0; q < 4; q++){
      if (c === SCORE.cycles && q) break;
      const x = t2x((c + q / 4) * SCORE.cycleSeconds);
      ctx.strokeStyle = q === 0 ? "#78fff533" : "#78fff512";
      ctx.beginPath(); ctx.moveTo(x + .5, 0); ctx.lineTo(x + .5, height); ctx.stroke();
    }
  }
  ctx.strokeStyle = "#78fff51f";
  ctx.beginPath(); ctx.moveTo(PAD + .5, 0); ctx.lineTo(PAD + .5, height); ctx.stroke();

  // idle notes — alpha carries gain so the mix is visible, not just the rhythm
  for (const n of stem.notes){
    const g = geom(stem, n);
    drawNote(ctx, g, cy, +(0.3 + 0.55 * n._rel).toFixed(3));
    if (!g.perc && g.h >= 5){ ctx.fillStyle = "rgba(190,255,252,.5)"; ctx.fillRect(g.x, g.y, Math.min(2, g.gw), g.h); }
  }
}

function noteEnd(n){
  return isPerc(n) ? n.t + PERC_FLASH : n.t + Math.max(n.d, 0.03) + n.r;
}

function activeNotes(stem, t){
  const out = [];
  for (const n of stem.notes) if (t >= n.t && t < noteEnd(n)) out.push(n);
  return out;
}

function paint(stem, t, force){
  // the rAF loop starts before the first successful relayout(), and a stem with
  // no note data has no canvas at all — both reach here with no 2d context
  if (!W || !stem.canvas || !stem.ctx) return;
  const act = activeNotes(stem, t);
  const key = act.length + ":" + act.map(n => n.t + "_" + n._row).join(",");
  if (!force && key === stem.activeKey) return;
  stem.activeKey = key;
  const ctx = stem.ctx;
  ctx.clearRect(0, 0, W, stem.L.height);
  ctx.drawImage(stem.static, 0, 0, W, stem.L.height);
  ctx.save();
  ctx.shadowColor = MAG; ctx.shadowBlur = 9;
  for (const n of act) drawNote(ctx, geom(stem, n), mg, 1);
  ctx.restore();
}

function measure(){
  const probe = stems.find(s => s.canvas);
  return (probe ? probe.canvas : blocksEl).getBoundingClientRect().width;
}

function relayout(){
  if (!SCORE) return;
  W = measure();
  if (!W) return;   // laid out while hidden; the ResizeObserver below re-runs us
  drawRuler();
  for (const stem of stems){
    if (!stem.canvas) continue;
    stem.ctx = sizeCanvas(stem.canvas, stem.L.height);
    drawStatic(stem);
    paint(stem, now(), true);
  }
  const anchor = stems.find(s => s.canvas);
  const rect = (anchor ? anchor.canvas : ruler).getBoundingClientRect();
  const sr = document.getElementById("stack").getBoundingClientRect();
  headOffset = rect.left - sr.left;
  moveHead(now());
}

/* ---------- audio: one WebAudio graph so the stems stay sample-locked ---------- */
let ctxA = null, gains = {}, sources = [], buffers = {}, startAt = 0, pausedAt = 0, playing = false;
let looping = true, headOffset = 0, ready = false;

function b64buf(uri){
  const bin = atob(uri.slice(uri.indexOf(",") + 1));
  const u8 = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
  return u8.buffer;
}

async function prepare(){
  if (ready) return;
  const id = trackId;
  ctxA = new (window.AudioContext || window.webkitAudioContext)();
  const master = ctxA.createGain(); master.gain.value = 0.9; master.connect(ctxA.destination);
  let longest = 0;
  for (const stem of stems){
    const g = ctxA.createGain(); g.connect(master); gains[stem.name] = g;
    buffers[stem.name] = await ctxA.decodeAudioData(b64buf(AUDIO[id][stem.name]));
    longest = Math.max(longest, buffers[stem.name].duration);
  }
  if (trackId !== id) return;                                   // switched mid-decode
  if (longest > total + 0.02){ total = longest; relayout(); }    // one-shots ring past the last cycle
  ready = true; applyMix();
}

function applyMix(){
  const anySolo = stems.some(s => s.solo);
  for (const stem of stems){
    const on = anySolo ? stem.solo : !stem.muted;
    if (stem.el) stem.el.classList.toggle("off", !on);
    if (gains[stem.name]) gains[stem.name].gain.setTargetAtTime(on ? 1 : 0, ctxA.currentTime, 0.012);
  }
}

function now(){
  // While the SYSTEM engine below is running and the roll is showing its
  // active track, the playhead follows the engine's clock: the roll becomes a
  // live view of the adaptive mix instead of a second, silent transport.
  if (sys.playing && trackId === sys.activeId) return sysPos() % total;
  if (!ready || !playing) return pausedAt;
  const t = ctxA.currentTime - startAt;
  return looping ? t % total : Math.min(t, total);
}

function spawn(offset){
  sources.forEach(s => { try { s.stop(); } catch (e) {} });
  sources = [];
  for (const stem of stems){
    const src = ctxA.createBufferSource();
    src.buffer = buffers[stem.name];
    src.loop = looping; src.loopStart = 0; src.loopEnd = total;
    src.connect(gains[stem.name]);
    src.start(0, Math.min(offset, src.buffer.duration - 0.001));
    sources.push(src);
  }
  startAt = ctxA.currentTime - offset;
}

async function play(){
  sysStop();                                 // one player at a time
  const id = trackId;
  await prepare();
  if (trackId !== id || !ready) return;      // a switch landed while we were decoding
  if (ctxA.state === "suspended") await ctxA.resume();
  spawn(pausedAt >= total - 0.01 ? 0 : pausedAt);
  playing = true;
  document.getElementById("play").classList.add("on");
  document.getElementById("play").innerHTML = "&#10073;&#10073; Pause";
}

function pause(){
  if (playing) pausedAt = now();
  playing = false;
  sources.forEach(s => { try { s.stop(); } catch (e) {} });
  sources = [];
  document.getElementById("play").classList.remove("on");
  document.getElementById("play").innerHTML = "&#9654; Play";
}

function seek(t){
  pausedAt = Math.max(0, Math.min(total - 0.001, t));
  if (playing) spawn(pausedAt); else { moveHead(pausedAt); frame(true); }
}

/* ---------- track switching ---------- */
/* The whole audio graph is torn down rather than reused. Keeping one context and
   swapping buffers is tempting, but every switch would leave the previous
   track's decoded PCM (tens of MB) reachable from `buffers`, and any source that
   failed to stop keeps playing under the new track. Closing the context makes
   both impossible. */
function teardown(){
  pause();
  if (ctxA){ try { ctxA.close(); } catch (e) {} }
  ctxA = null; gains = {}; buffers = {}; ready = false; pausedAt = 0;
  for (const s of stems){ s.el = null; s.canvas = null; s.ctx = null; s.static = null; s.cellSpans = null; }
  blocksEl.innerHTML = ""; codeEl.innerHTML = "";
}

function loadTrack(id){
  teardown();
  const t = TRACKS.find(x => x.id === id) || TRACKS[0];
  trackId = t.id;
  SCORE = t.score; stems = SCORE.stems; total = SCORE.total;
  document.title = "score - " + t.label.toLowerCase();
  buildBlocks(); buildCode(); fillMeta();
  const fc = document.getElementById("footcyc");
  if (fc) fc.textContent = SCORE.cycleSeconds.toFixed(2) + "s";
  lastW = -1; W = 0;
  relayout();
  frame(true);
}

const sel = document.getElementById("track");
sel.innerHTML = TRACKS.map(t => `<option value="${t.id}">${t.label}</option>`).join("");
if (TRACKS.length < 2) document.getElementById("picker").style.display = "none";
sel.onchange = () => loadTrack(sel.value);

/* ---------- views ---------- */
function showView(v){
  view = v;
  document.body.classList.toggle("code", v === "code");
  document.getElementById("tabRoll").classList.toggle("on", v === "roll");
  document.getElementById("tabCode").classList.toggle("on", v === "code");
  if (v === "roll") relayout();     // the roll measures 0 while hidden, so it must re-measure here
}
document.getElementById("tabRoll").onclick = () => showView("roll");
document.getElementById("tabCode").onclick = () => showView("code");

document.getElementById("play").onclick = () => playing ? pause() : play();
document.getElementById("stop").onclick = () => { pause(); seek(0); };
document.getElementById("loop").onclick = e => {
  looping = !looping; e.target.classList.toggle("on", looping);
  if (playing){ const t = now(); spawn(t); }
};
addEventListener("keydown", e => {
  if (e.target && e.target.tagName === "SELECT") return;   // space belongs to the dropdown there
  if (e.code === "Space"){ e.preventDefault(); playing ? pause() : play(); }
  else if (e.code === "Home"){ seek(0); }
  else if (e.code === "ArrowRight"){ seek(now() + SCORE.cycleSeconds); }
  else if (e.code === "ArrowLeft"){ seek(now() - SCORE.cycleSeconds); }
});

/* ---------- SYSTEM: the in-game adaptive engine, mirrored ----------
   Constants copied from scripts/music.gd, not re-derived. Behaviour mirrored:
   tiers change stem VOLUME only (nothing restarts), and a track switch is an
   8-BAR STEM MIGRATION: it waits for the bar line, starts the incoming track
   at the outgoing track's exact phase, then swaps the organs one at a time —
   old lead exits (bars 0-2) while drums crossfade (0-3), bass+arp pivot as a
   block (3-5), new lead rises (5-8). Melodies never overlap across keys.
   Auto-chain ping-pongs the circle of fifths: Bb - F - C - G, one accidental
   per move. Own AudioContext, so the roll player above stays untouched. */
const SYS = {
  STEM_DB: -3, FADE_IN: 1.1, FADE_OUT: 2.2,
  BAR: 2.0, LOOP: 16.0, MIGRATE: 16.0,
  XF_IN:  [[6, 4], [0, 6], [6, 4], [10, 6]],   // per layer [delay, duration]
  XF_OUT: [[6, 4], [0, 6], [6, 4], [0, 4]],
  FIFTHS: ["track2", "track4", "gameplay", "track3"],   // Darksynth Lightcycle Neon Outrun
};
const sys = {
  ctx: null, master: null, buffers: {}, gains: [], sources: [],
  activeId: null, tier: 3, playing: false, switching: false,
  phaseStart: 0, rotPos: 0, rotDir: 1, auto: false, nextAutoAt: Infinity,
};
const sysIds = SYS.FIFTHS.filter(id => AUDIO[id]);
const sysLabel = id => (TRACKS.find(t => t.id === id) || {label: id}).label;
const sysLin = db => Math.pow(10, db / 20);

async function sysInit(){
  sys.ctx = new (window.AudioContext || window.webkitAudioContext)();
  sys.master = sys.ctx.createGain(); sys.master.gain.value = 0.9;
  sys.master.connect(sys.ctx.destination);
  for (const id of sysIds){
    sysStatus(`decoding ${sysLabel(id)}…`);
    const names = Object.keys(AUDIO[id]).sort();   // <t>_0_bass < _1_drums < _2_arp < _3_lead
    sys.buffers[id] = [];
    for (const n of names) sys.buffers[id].push(await sys.ctx.decodeAudioData(b64buf(AUDIO[id][n])));
  }
}

function sysPos(){
  const p = (sys.ctx.currentTime - sys.phaseStart) % SYS.LOOP;
  return p < 0 ? p + SYS.LOOP : p;
}

function spawnBank(id, at, offset){
  sys.gains = []; sys.sources = [];
  for (let i = 0; i < 4; i++){
    const g = sys.ctx.createGain(); g.gain.value = 0; g.connect(sys.master);
    const src = sys.ctx.createBufferSource();
    src.buffer = sys.buffers[id][i];
    src.loop = true; src.loopStart = 0; src.loopEnd = SYS.LOOP;
    src.connect(g);
    src.start(at, offset % src.buffer.duration);
    sys.gains.push(g); sys.sources.push(src);
  }
}

/* setTargetAtTime, not a linear ramp: overlap-safe when a fade lands on a
   fade (music.gd kills the old tween; here the new target simply wins), and
   its exponential approach is close to the dB-linear tween the game runs. */
function sysFade(g, targetDb, at, seconds){
  g.gain.cancelScheduledValues(at);
  g.gain.setTargetAtTime(targetDb === null ? 0 : sysLin(targetDb), at, seconds / 4);
}

function applyTier(level, at){
  sys.tier = level;
  for (let i = 0; i < sys.gains.length; i++){
    const on = i <= level;
    sysFade(sys.gains[i], on ? SYS.STEM_DB : null, at, on ? SYS.FADE_IN : SYS.FADE_OUT);
  }
  document.querySelectorAll("#systiers button").forEach((b, i) =>
    b.classList.toggle("on", i === level));
}

async function sysStart(id){
  pause();                                   // one player at a time
  if (!sys.ctx) await sysInit();
  if (sys.ctx.state === "suspended") await sys.ctx.resume();
  const at = sys.ctx.currentTime + 0.05;
  sys.phaseStart = at;
  spawnBank(id, at, 0);
  sys.activeId = id; sys.playing = true;
  sys.rotPos = Math.max(0, sysIds.indexOf(id));
  sys.rotDir = sys.rotPos >= sysIds.length - 1 ? -1 : 1;
  applyTier(sys.tier, at);
  sys.nextAutoAt = at + sysBarsPer() * SYS.BAR;
  syncRollTo(id);
  sysButtons();
}

function sysSwitch(id){
  if (!sys.playing){ sysStart(id); return; }
  if (sys.switching || id === sys.activeId) return;
  sys.switching = true;
  const t = sys.ctx.currentTime;
  // Next bar line, in context time. phaseStart never moves, so every bank ever
  // spawned shares one phase - the invariant the whole trick rests on.
  const at = sys.phaseStart + Math.ceil((t - sys.phaseStart + 0.02) / SYS.BAR) * SYS.BAR;
  const offset = (at - sys.phaseStart) % SYS.LOOP;
  const old = { gains: sys.gains, sources: sys.sources };
  spawnBank(id, at, offset);
  // The 8-bar migration, per layer. τ = dur/3 so a fade is ~95% done inside
  // its window; complementary exponential rise+fall sums to constant power.
  for (let i = 0; i < 4; i++){
    if (i <= sys.tier)
      sysFade(sys.gains[i], SYS.STEM_DB, at + SYS.XF_IN[i][0], SYS.XF_IN[i][1] * 4 / 3);
    sysFade(old.gains[i], null, at + SYS.XF_OUT[i][0], SYS.XF_OUT[i][1] * 4 / 3);
  }
  for (const s of old.sources){ try { s.stop(at + SYS.MIGRATE + 2.0); } catch (e) {} }
  sys.migrateFrom = sysLabel(sys.activeId);
  sys.migrateAt = at;
  sys.activeId = id;
  sys.nextAutoAt = at + SYS.MIGRATE + sysBarsPer() * SYS.BAR;
  document.querySelectorAll("#systiers button").forEach((b, i) =>
    b.classList.toggle("on", i === sys.tier));
  setTimeout(() => { syncRollTo(id); sysButtons(); }, (at - t) * 1000 + 60);
  setTimeout(() => { sys.switching = false; }, (at - t + SYS.MIGRATE) * 1000);
}

function sysNextInRotation(){
  if (sysIds.length < 2) return sys.activeId;
  sys.rotPos += sys.rotDir;
  if (sys.rotPos >= sysIds.length){ sys.rotPos = sysIds.length - 2; sys.rotDir = -1; }
  else if (sys.rotPos < 0){ sys.rotPos = 1; sys.rotDir = 1; }
  return sysIds[sys.rotPos];
}

function sysStop(){
  if (!sys.ctx) return;
  const t = sys.ctx.currentTime;
  for (const g of sys.gains) sysFade(g, null, t, 0.3);
  for (const s of sys.sources){ try { s.stop(t + 1.0); } catch (e) {} }
  sys.gains = []; sys.sources = [];
  sys.playing = false; sys.switching = false;
  sysStatus("off");
  sysButtons();
}

function sysBarsPer(){ return Number(document.getElementById("sysbars").value); }
function sysStatus(msg){ document.getElementById("sysstatus").innerHTML = msg; }
function syncRollTo(id){ if (sel.value !== id){ sel.value = id; loadTrack(id); } }

function sysButtons(){
  document.querySelectorAll("#systracks button").forEach(b =>
    b.classList.toggle("on", sys.playing && b.dataset.id === sys.activeId));
}

/* Called every animation frame from the roll's own loop. Drives auto-chain and
   the status line; scheduling stays inside WebAudio, this only decides WHEN. */
function sysTick(){
  if (!sys.playing) return;
  if (sys.auto && !sys.switching && sys.ctx.currentTime >= sys.nextAutoAt)
    sysSwitch(sysNextInRotation());
  if (sys.switching && sys.migrateAt !== undefined){
    const mb = Math.floor((sys.ctx.currentTime - sys.migrateAt) / SYS.BAR) + 1;
    sysStatus(mb < 1
      ? `${sys.migrateFrom} → ${sysLabel(sys.activeId)} @ next bar line…`
      : `merging ${sys.migrateFrom} → <b>${sysLabel(sys.activeId)}</b> · bar ${Math.min(mb, 8)}/8`);
  }
  if (!sys.switching){
    const bar = Math.floor(sysPos() / SYS.BAR) + 1;
    let peek = sys.rotPos + sys.rotDir;                    // same bounce as sysNextInRotation
    if (peek >= sysIds.length) peek = sysIds.length - 2;
    else if (peek < 0) peek = 1;
    const chain = sys.auto ? ` &nbsp;·&nbsp; next: ${sysLabel(sysIds[peek])}` : "";
    sysStatus(`<b>${sysLabel(sys.activeId)}</b> &nbsp;·&nbsp; tier ${sys.tier} ` +
              `&nbsp;·&nbsp; bar ${bar}/8${chain}`);
  }
}

const trkBox = document.getElementById("systracks");
trkBox.innerHTML = sysIds.map(id =>
  `<button class="trk" data-id="${id}">${sysLabel(id)}</button>`).join("");
trkBox.querySelectorAll("button").forEach(b => b.onclick = () => sysSwitch(b.dataset.id));
const tierBox = document.getElementById("systiers");
tierBox.innerHTML = ["bass", "+drums", "+arp", "+lead"].map((n, i) =>
  `<button class="tier${i === 3 ? " on" : ""}">${i} ${n}</button>`).join("");
tierBox.querySelectorAll("button").forEach((b, i) => b.onclick = () => {
  if (sys.playing) applyTier(i, sys.ctx.currentTime);
  else { sys.tier = i; tierBox.querySelectorAll("button").forEach((x, j) => x.classList.toggle("on", j === i)); }
});
document.getElementById("sysauto").onclick = e => {
  sys.auto = !sys.auto;
  e.target.classList.toggle("on", sys.auto);
  if (sys.auto && sys.playing) sys.nextAutoAt = sys.ctx.currentTime + sysBarsPer() * SYS.BAR;
  if (sys.auto && !sys.playing) sysStart(sysIds[0]);
};
document.getElementById("sysstop").onclick = sysStop;
if (sysIds.length < 2) document.getElementById("sysbar").style.display = "none";

/* ---------- playhead + per-frame repaint ---------- */
const headEl = document.getElementById("head");
function moveHead(t){ headEl.style.transform = `translateX(${(headOffset + t2x(t)).toFixed(2)}px)`; }

function fmt(t){
  const m = Math.floor(t / 60), s = t - m * 60;
  return `${m}:${s.toFixed(2).padStart(5, "0")}`;
}

function paintCode(cycle){
  for (const stem of stems){
    if (!stem.cellSpans) continue;
    for (let pi = 0; pi < stem.pats.length; pi++){
      const p = stem.pats[pi], cells = stem.cellSpans[pi];
      if (!p.n) continue;
      const idx = ((Math.floor(cycle * p.rate) % p.n) + p.n) % p.n;
      if (stem.cellNow[pi] === idx) continue;
      const prev = cells[stem.cellNow[pi]];
      if (prev) for (const sp of prev) sp.classList.remove("on-cell");
      const next = cells[idx];
      if (next) for (const sp of next) sp.classList.add("on-cell");
      stem.cellNow[pi] = idx;
    }
  }
}

function frame(force){
  if (!SCORE) return;
  const t = now();
  document.getElementById("t").textContent = fmt(t);
  document.getElementById("cyc").textContent = "cycle " + (t / SCORE.cycleSeconds + 1).toFixed(2);
  paintCode(t / SCORE.cycleSeconds);
  if (view === "roll" && W){
    moveHead(t);
    for (const stem of stems) paint(stem, t, force);
  }
  if (!looping && playing && t >= total - 0.01) pause();
}
(function loopFrame(){ frame(false); sysTick(); requestAnimationFrame(loopFrame); })();

/* ---------- pointer: click seeks, hover explains ---------- */
const tip = document.getElementById("tip");
function hit(stem, x, y){
  let best = null;
  for (const n of stem.notes){
    const g = geom(stem, n);
    if (g.perc){
      if (Math.abs(x - g.cx) <= g.r + 2.5 && y >= g.cy - g.r - 2 && y <= g.cy + g.r + 2) best = n;
    } else if (x >= g.x - 2 && x <= g.x + g.gw + 2 && y >= g.y - 1 && y <= g.y + g.h + 1) best = n;
  }
  return best;
}

function num(v){
  return typeof v === "number"
    ? (Math.abs(v) >= 100 ? v.toFixed(0) : v.toFixed(3).replace(/0+$/, "").replace(/\.$/, ""))
    : v;
}

function wirePointer(stem){
  stem.canvas.addEventListener("mousemove", e => {
    const r = stem.canvas.getBoundingClientRect();
    const n = hit(stem, e.clientX - r.left, e.clientY - r.top);
    if (!n){ tip.classList.remove("on"); return; }
    const fx = Object.entries(n.p).map(([k, v]) => `${k} ${num(v)}`).join("  ");
    const perc = isPerc(n);
    tip.innerHTML =
      `<h4>${n.n || n.s.toUpperCase()}</h4>` +
      `<div class="row">start <span>${n.t.toFixed(3)}s</span></div>` +
      `<div class="row">cycle <span>${(n.c + 1).toFixed(3)}</span></div>` +
      (perc
        ? `<div class="row">slot <span>${n.d.toFixed(3)}s</span></div>` +
          `<div class="row">length <span>the sample's own</span></div>`
        : `<div class="row">gate <span>${n.d.toFixed(3)}s</span></div>` +
          (n.r ? `<div class="row">release <span>${n.r.toFixed(3)}s</span></div>` : "")) +
      (n.hz ? `<div class="row">pitch <span>${n.n} &middot; ${n.hz} Hz &middot; midi ${n.m}</span></div>` : "") +
      `<div class="row">sound <span>${n.s} (${n.k})</span></div>` +
      `<div class="row">gain <span>${n.g}</span></div>` +
      (fx ? `<div class="fx">${fx}</div>` : "");
    tip.classList.add("on");
    const tw = tip.offsetWidth, th = tip.offsetHeight;
    tip.style.left = Math.min(innerWidth - tw - 10, e.clientX + 16) + "px";
    tip.style.top = Math.max(8, Math.min(innerHeight - th - 10, e.clientY - th - 12)) + "px";
  });
  stem.canvas.addEventListener("mouseleave", () => tip.classList.remove("on"));
  stem.canvas.addEventListener("click", e => {
    const r = stem.canvas.getBoundingClientRect();
    seek(x2t(e.clientX - r.left));
  });
}

ruler.addEventListener("click", e => {
  const r = ruler.getBoundingClientRect();
  seek(x2t(e.clientX - r.left));
});

// A background tab, a collapsed pane or a slow first paint can all report width 0,
// and a one-shot relayout() there leaves every roll permanently blank. Watch the
// container instead of trusting load order.
let lastW = -1;
new ResizeObserver(() => {
  const w = measure();
  if (w && Math.abs(w - lastW) > 0.5){ lastW = w; relayout(); }
}).observe(document.getElementById("stack"));

// width-independent changes (moving the window to a display with another dpr)
addEventListener("resize", () => { clearTimeout(window._rt); window._rt = setTimeout(relayout, 120); });

loadTrack(TRACKS[0].id);
</script>
</body>
</html>
"""


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Render Strudel stems + their renderer sidecars into one self-contained HTML piano roll.")
    ap.add_argument("prefix", nargs="?", default=None,
                    help="track prefix, e.g. 'gameplay' (matches gameplay*.ogg), 'title', 'victory'. "
                         "Omit to build every track into one page with a selector.")
    ap.add_argument("--cps", type=float, default=DEFAULT_CPS,
                    help="fallback cycles-per-second when the sidecar cannot reveal it (default 0.5)")
    ap.add_argument("--out", default=None,
                    help="output .html path (default .ai/score_<prefix>.html, or .ai/score.html for all)")
    args = ap.parse_args()

    if not MUSIC.is_dir():
        print(f"no music directory: {MUSIC}")
        print("run:  python tools/build_music.py")
        return 1

    if args.prefix:
        prefixes = [args.prefix]
        default_out = OUTDIR / f"score_{args.prefix}.html"
        title = f"score - {args.prefix}"
    else:
        prefixes = discover_prefixes()
        if not prefixes:
            print(f"no .ogg files in {MUSIC}")
            print("run:  python tools/build_music.py")
            return 1
        default_out = OUTDIR / "score.html"
        title = "score - all tracks"
        print(f"building all tracks: {', '.join(prefixes)}")

    out = Path(args.out) if args.out else default_out
    return build(prefixes, args.cps, out, title)


if __name__ == "__main__":
    sys.exit(main())
