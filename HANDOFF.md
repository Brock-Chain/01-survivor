# Session handoff — 2026-08-02

Transient. Delete once the next session has absorbed it. `TODO.md` is the durable
source of truth; `BRIEF.md` is the spec; `DECISIONS.md` is why things are the way
they are.

## Where we are

**M7 — the whole locked rework — is built and committed.** Working tree clean at
the last commit; `verify.ps1` green with **117 tests**; Web and Windows exports
rebuilt from the final code and both produce clean.

The previous handoff's spec was followed end to end. Three of its numbers were
changed by measurement, which is what it asked for ("starting points, all to be
verified by measurement, not argued"). Every change is recorded in
`DECISIONS.md` with the soak table that forced it.

**The one thing left is the thing a bot cannot do: a human run.** See "What still
needs you" below.

## What shipped, in build order

| Step | State |
|---|---|
| 7.1 telemetry | done — and the real bug was bigger than the spec knew |
| 7.2 progression | done — drip re-derived from an A/B soak, twice |
| 7.3 weapon drafts | done — plus a card rebalance measurement forced |
| 7.4 NOGAXEH v2 | done — structure soak-verified end to end |
| 7.5 endings | done — true ending screen + death screen |
| 7.6 card UI | done — iconography, no dead space |
| 7.7 skill tree | done — THE LATTICE, on the title screen |
| 7.8 glow | see below |
| 7.9 measure | **YOURS** |

### The instrument bug was worse than "a dropped log row"

`Main` only banked a run when the player DIED. A restart, a quit to title, or a
closed window dropped both the telemetry ending row *and* the run's records.
That is why `run_076` peaked at **2757 kills / 660.1s** while `save.cfg` still
reads `best_kills=1125` — and worse, that run cleared the victory and survived
past 600s, which is exactly the `endless_proven` condition. **The human earned
the PRISM LANCE and the game never gave it to them.**

`Main._finish_run()` is the one place a run ends now. Fixed forward only: the
existing `save.cfg` was left untouched, because it is your profile and a
retro-repair is your call, not a side effect. Say the word and it is a one-line
edit to `best_kills`, `best_time` and the `unlocks` array.

### Three spec numbers that measurement changed

The method: run the *same* soak against a `git worktree` at the pre-rework
commit and against the working tree, **with the dev profile deleted on both
sides**. The first attempt at this was invalid and nearly caused a wrong fix —
the old build granted weapons from the saved profile, so the "blaster-only
baseline" was secretly a three-weapon run.

| blaster only, fresh profile | kills @3:00 | kills @3:51 | enemies alive |
|---|---|---|---|
| pre-rework (78 picks) | 381 | 626 | 5 |
| the spec's drip, as written | 86 | 115 | **110 (the cap)** |
| shipped | 369 | 604 | 18 |

1. **The damage drip is FLAT, not a percentage.** Early DPS is dominated by the
   flat bonus on a base-1 weapon; +1.5%/level is +16% of almost nothing at level
   12, while the seven picks it replaced were worth several whole points.
2. **Card magnitudes went up ~2-3x.** This is the spec's own other half — "3x
   fewer, 3x more valuable decisions" — and only the first half of that is a
   gate. Unique Epic/Legendary effects are untouched.
3. **The drip also buys BREADTH** (+1 projectile every 20 levels). Damage and
   fire rate kill one thing faster; only count clears a crowd, and count was
   card-only. Without it the arena stayed pinned at the enemy cap no matter how
   much damage was added.

### And one the spec could not have known about

**The 10:00 fight now scales by LEVEL, not weapon count.** Weapon count was a
fair DPS proxy while weapons came from the profile; drafting broke it in both
directions at once — blaster-only at level 91 killed the 11,200 HP event in
**32 seconds**, while a four-weapon level-77 run took **212**. Level sees the
drip, the picks and how the run actually went. Re-soaked at **142s** against the
~120s target. Full reasoning in `DECISIONS.md` and
`hub/knowledge/proxy-metrics-go-stale.md`.

## What still needs you

**A human run to 10:00, then retune from the telemetry.** Bot variance is now too
wide to tune against: two identical soak commands produced **level 85** and
**level 50** at the ten-minute mark, because `--dev-autopick` takes `offers[0]`
and a run has ~25 picks each worth three times what they used to be. Structure
is verified; fight lengths are one sample of a wide distribution.

Specific numbers waiting on that run:

- `RunDirector.MIRROR_LEVEL_STEP` (0.045) — the 10:00 fight's whole difficulty.
- **The 5:00 Prism under the new curve.** It was accepted at 49s. You now arrive
  with ~13 picks instead of ~40, offset by the drip. Untouched deliberately;
  measure it before changing it.
- **Do the defensive cards revive?** They were dead because the game never asked
  for defense. NOGAXEH v2 asks. Re-measure before cutting them.
- **Does the arena still saturate around 3:00 for a weak build?** One soak said
  yes at level 50. A human plays better than a circling bot, so this is a lower
  bound, not a verdict.

```powershell
# play it (debug build -> telemetry records automatically, real profile)
..\..\engine\Godot_v4.7.1-stable_win64.exe --path .
# then read it (dev-flagged runs are excluded from the aggregates automatically)
python tools/analyze_telemetry.py
```

## New things worth knowing before you edit

- **`Main._finish_run()` is the only place a run ends.** Death, restart, quit to
  title and window close all land there, guarded so nothing banks twice.
- **`Main._offer_gates()` is the only place card eligibility is decided.** Three
  kinds of gate — profile unlocks, this run's weapon drafts, skill-tree
  purchases — flow through one array, because the pool only ever asks "is this
  gate held".
- **All content is generated.** `gen_upgrades.gd`, `gen_weapons.gd`,
  `gen_skills.gd`. The first and third now **prune orphaned .tres**, so removing
  a definition actually removes the card. Never hand-edit a `.tres`.
- **`scenes/dev/pause_layout_check.tscn` now guards THREE screens**, and it
  earned it again: the true ending's first draft measured **633 px tall against
  a 360 px viewport**. It also doubles as a capture rig — run it windowed with
  `--screenshot=` to photograph the true ending.
- The old traps all still apply: never round-trip a source file through
  PowerShell 5.1; `_unhandled_input` is gated by `process_mode`; defer every
  tree mutation reached from a damage callback (NOGAXEH v2 adds five more).

## Commands

```powershell
# THE GATE. Run this, not the individual steps.
powershell -File tools/verify.ps1
powershell -File tools/verify.ps1 soak

# content generators (re-run after editing the tool, then --import)
<console.exe> --headless --path . -s res://tools/gen_upgrades.gd
<console.exe> --headless --path . -s res://tools/gen_skills.gd
<console.exe> --headless --path . -s res://tools/gen_weapons.gd

# exports (both current with the final code)
<console.exe> --headless --path . --export-release "Web" builds/web/index.html
<console.exe> --headless --path . --export-release "Windows Desktop" builds/windows/BESTAGON.exe
```

## Dev flags

`--dev-godmode` · `--dev-autopick` · `--dev-autocontinue` · `--dev-unlocks`
· `--dev-stats` · `--dev-autopilot` · `--dev-telemetry`

Any `--dev-` flag redirects the save to `user://save_dev.cfg`. **`--dev-unlocks`
now also DRAFTS every weapon** — since M7.3 an unlock only offers a card, so
unlocking alone would leave every soak firing the blaster and nothing else.

## Not decided — do not decide these alone

- **Boss at 3:00 instead of 5:00.** Still parked, unchanged.
- **Melee is decorative** (96 `bolt` vs 20 `contact` in the last human run).
  Still not raised. NOGAXEH v2 does not touch it.
- **The floor is deliberately restrained.** Still a brief question, not a bug.
