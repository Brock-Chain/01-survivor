"""Reads playtest telemetry and answers balance questions with numbers.

    python tools/analyze_telemetry.py                 # all runs in user://telemetry
    python tools/analyze_telemetry.py --dir <path>    # explicit directory

Answers, in order of how often they come up:
  * Which upgrades do players actually take?  (pick / offered, not raw counts —
    a raw count just tells you which upgrades are common.)
  * Is the start too easy?  (time to first damage, HP over time)
  * Where does pressure actually exist?  (living enemies + HP per 30s bucket)
  * How long is the boss fight, and does it hurt?
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict
from pathlib import Path


def default_dir() -> Path:
    appdata = os.environ.get("APPDATA", "")
    return Path(appdata) / "Godot" / "app_userdata" / "01 Survivor" / "telemetry"


def load_runs(d: Path) -> list[list[dict]]:
    runs = []
    for f in sorted(d.glob("run_*.jsonl")):
        rows = []
        for line in f.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                pass  # a run killed mid-write leaves one partial final line
        if rows:
            runs.append(rows)
    return runs


def bar(frac: float, width: int = 24) -> str:
    n = max(0, min(width, round(frac * width)))
    return "#" * n + "." * (width - n)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", type=Path, default=None)
    args = ap.parse_args()
    d = args.dir or default_dir()

    if not d.exists():
        print(f"no telemetry directory: {d}")
        print("play a debug build (or pass -- --dev-telemetry) to generate some.")
        return 1

    runs = load_runs(d)
    if not runs:
        print(f"no runs in {d}")
        return 1

    print(f"\n{len(runs)} run(s) from {d}\n")

    offered: dict[str, int] = defaultdict(int)
    picked: dict[str, int] = defaultdict(int)
    first_damage: list[float] = []
    end_rows: list[tuple[float, dict]] = []
    dmg_by_source: dict[str, int] = defaultdict(int)
    boss_fights: list[float] = []
    pu_drop: dict[str, int] = defaultdict(int)
    pu_take: dict[str, int] = defaultdict(int)
    buckets: dict[int, list[tuple[int, int, int]]] = defaultdict(list)

    for rows in runs:
        saw_damage = False
        boss_at: float | None = None
        for r in rows:
            e, t = r.get("e"), float(r.get("t", 0.0))
            if e == "offer":
                for i in r.get("ids", []):
                    offered[i] += 1
            elif e == "pick":
                picked[r.get("id", "?")] += 1
            elif e == "damage":
                dmg_by_source[r.get("src", "?")] += int(r.get("amt", 0))
                if not saw_damage:
                    first_damage.append(t)
                    saw_damage = True
            elif e == "tick":
                buckets[int(t // 30) * 30].append(
                    (int(r.get("hp", 0)), int(r.get("max_hp", 1)), int(r.get("alive", 0))))
            elif e == "powerup_drop":
                pu_drop[r.get("id", "?")] += 1
            elif e == "powerup_take":
                pu_take[r.get("id", "?")] += 1
            elif e == "boss_spawn" and boss_at is None:
                boss_at = t
            elif e == "victory" and boss_at is not None:
                boss_fights.append(t - boss_at)
                boss_at = None
            elif e in ("death", "run_end"):
                end_rows.append((t, r))
        if not saw_damage:
            first_damage.append(float("inf"))

    # --- upgrades -----------------------------------------------------------
    print("UPGRADE PICK RATE  (taken / times offered)")
    if not offered:
        print("  no level-ups recorded\n")
    else:
        rows = sorted(offered.items(), key=lambda kv: -(picked[kv[0]] / kv[1]))
        for uid, off in rows:
            got = picked[uid]
            rate = got / off if off else 0.0
            flag = ""
            if off >= 4 and rate <= 0.15:
                flag = "  <- dead weight, nobody wants it"
            elif off >= 4 and rate >= 0.75:
                flag = "  <- auto-pick, may be too strong"
            print(f"  {uid:<14} {bar(rate)} {rate:5.0%}  ({got}/{off}){flag}")
        print()

    # --- early difficulty ---------------------------------------------------
    finite = [t for t in first_damage if t != float("inf")]
    never = len(first_damage) - len(finite)
    print("TIME TO FIRST DAMAGE  (is the opening too safe?)")
    if finite:
        finite.sort()
        med = finite[len(finite) // 2]
        print(f"  median {med:6.1f}s   earliest {finite[0]:.1f}s   latest {finite[-1]:.1f}s")
        if med > 60:
            print("  -> the first minute is free. Nothing threatens the player.")
    if never:
        print(f"  {never} run(s) took NO damage at all")
    print()

    print("PRESSURE BY 30s BUCKET  (mean HP% / mean living enemies)")
    for start in sorted(buckets):
        vals = buckets[start]
        hp_frac = sum(h / m for h, m, _ in vals if m) / len(vals)
        alive = sum(a for _, _, a in vals) / len(vals)
        print(f"  {start:4d}-{start + 29:3d}s  hp {bar(hp_frac, 16)} {hp_frac:4.0%}   alive {alive:5.1f}")
    print()

    # --- boss ---------------------------------------------------------------
    if boss_fights:
        boss_fights.sort()
        print("BOSS FIGHT LENGTH")
        print(f"  median {boss_fights[len(boss_fights) // 2]:.1f}s   "
              f"range {boss_fights[0]:.1f}-{boss_fights[-1]:.1f}s\n")

    if pu_drop:
        print("POWER-UPS  (taken / dropped — a low ratio means they are unreachable)")
        for pid, dropped in sorted(pu_drop.items()):
            took = pu_take[pid]
            print(f"  {pid:<10} {bar(took / dropped if dropped else 0)} "
                  f"{(took / dropped if dropped else 0):5.0%}  ({took}/{dropped})")
        print()

    if dmg_by_source:
        total = sum(dmg_by_source.values())
        print("DAMAGE TAKEN BY SOURCE")
        for src, amt in sorted(dmg_by_source.items(), key=lambda kv: -kv[1]):
            print(f"  {src:<10} {bar(amt / total)} {amt / total:4.0%}  ({amt} hp)")
        print()

    print("RUN ENDINGS")
    for t, r in end_rows:
        if r.get("e") == "run_end":
            print(f"  {t:6.1f}s  {r.get('reason', '?'):<8} kills={r.get('kills', '?')} "
                  f"lvl={r.get('lvl', '?')} won={r.get('won', False)}")
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
