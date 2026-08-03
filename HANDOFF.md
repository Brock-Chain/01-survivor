# Session handoff — 2026-08-02 (late)

Transient. Delete once the next session has absorbed it. `TODO.md` is the durable
source of truth; `BRIEF.md` is the spec; `DECISIONS.md` is why things are the way
they are.

## Where we are

**Everything is committed** at `cc25881`, working tree clean. The previous
handoff's "NOTHING IS COMMITTED" warning is resolved — do not act on it.

Web and Windows exports were rebuilt this session and are current with `cc25881`.
Both produced clean (exit 0, no `ERROR`/`SCRIPT ERROR`).

This session did **no code changes**. It was a grilling session: the first real
human run to 10:00 was analysed from telemetry, and the result is a locked spec
for a large rework. Everything below in "The locked spec" is decided. Build it.

## What the telemetry actually said

The evidence is `run_076.jsonl` in `%APPDATA%\Godot\app_userdata\BESTAGON\telemetry`
— 3312 lines, 11 minutes, **played clean with no dev flags** (confirmed:
`save.cfg` `best_time=349.1716666666559` matches the run's victory event to the
millisecond, so it wrote to the real profile, not `save_dev.cfg`).

| Measure | Target | Actual |
|---|---|---|
| The Prism @ 5:00 | ~60s | **49s** — accepted, do not touch |
| NOGAXEH @ 10:00 | ~120s | **~22s** (spawn 599.99, `bosses:3` at 617.0, `bosses:0` at 622.0) |
| Lowest HP after any hit, whole run | — | **37.5%, once**, at 7:59 |
| HP at nearly every tick after 3:00 | — | **100%** |
| Total damage taken in 11 min | — | 168, against a pool that grew 6 → 19 |
| Level-ups | — | **79**, median one every **7.9s** |
| Damage by source | — | **96 `bolt` / 20 `contact`** — melee is decorative |

Three diagnoses that drove the whole spec:

1. **The mirror's budget was set as an HP ratio and that could never work.**
   `ESCORT_HP`'s docstring reasons "1.9x the 5:00 event ... which against a ~60s
   Prism is the ~2 minute climax." Measured: the 5:00 event took 49s and the
   1.9x-larger 10:00 event took 22s, because **the player's DPS roughly
   quadrupled over those five minutes**. Budget the fight in seconds at measured
   DPS, never in HP relative to an earlier fight.

2. **79 levels is not this game's pace — it is the greed-stacked ceiling.**
   Reaching level 79 needs ~56,200 banked XP; the player's raw gem income was
   only ~20,500. `greed` is Epic, +50% XP, max 2 stacks, and stacks
   **multiplicatively** (`upgrade.gd:114`); `scholar` went to 3. Combined
   `xp_mult` ≈ **3.0x**, held from ~2:30 onward. At 1.0x the same income reaches
   level ~54. Greed alone was worth 25 levels.

3. **Three dead cards, and one dead weapon wearing three cards.**
   `lodestone` 0/16, `magnetism` 0/12, `orbit_radius` 0/11, `tough_hide` 1/12,
   `orbit_count` 1/10, `carapace` 2/12, `swift_boots` 2/11. All three ORBITAL
   cards are bottom-five — that is a weapon problem, not a card problem. The
   defensive cards are dead because the game never asked for defense; the boss
   rework should revive those on its own, so **leave them and re-measure**.
   Legendary is already correctly rare: 4 appearances in 234 slots (1.7%), taken 4/4.

## The instrument is lying, and it must be fixed first

Nothing below can be measured until these are fixed. They are cheap. Do them
before touching gameplay.

- **`begin_run()` calls `_close()`, not `end_run()`** (`telemetry.gd:37`). A
  restart drops the previous run's ending row. Both of the only runs that ever
  reached a boss (`run_074`, `run_076`) have **no `run_end`**, so
  `analyze_telemetry.py`'s endings report systematically omits exactly the runs
  that matter.
- **`_run_t` is never reset in `begin_run()`**, so a new run's `run_start` is
  stamped with the *previous* run's clock — `run_080` opens at `t:660.2`,
  `run_074` at `t:119.27`.
- **`analyze_telemetry.py:28` still defaults to the `PRISM` / `01 Survivor`
  directory.** Run it bare and it silently analyses pre-rename data and says
  nothing about any of the above. Point it at `BESTAGON`.
- **No run records which `--dev-` flags were active.** Establishing that
  `run_076` was a clean run took a cross-check against `save.cfg`'s
  `best_time`. Log the active flags and the commit in `run_start`.
- Related: `run_076` reached 2780 kills but `save.cfg` records `best_kills=1125`,
  because `update_records` never ran on a run that ended without `run_end`.
  Verify this when fixing the above.

## The locked spec

Every item here was decided this session. Do not relitigate; if something proves
wrong when measured, record the change in `DECISIONS.md`.

**Audience.** Tune for **a stranger's first 10 minutes**. A stranger is by
definition a zero-skill-tree account, so *every difficulty number is tuned
against an empty tree*. The tree is the veteran's power fantasy on top.

### Progression

- **Cards gate to every 3rd level.** ~25 card screens per run instead of 78.
- **Every level gives a silent stat drip, no interruption**: damage, fire rate,
  and a little move speed. **No passive max HP or defense** — the HP pool already
  grew 6→19 through cards while the player never dropped below 62% at a tick,
  and defense must stay card-only so it remains a real choice.
  Starting points, all to be verified by measurement, not argued:
  +1.5% damage, +0.75% fire rate, +0.3% move speed per level, with the drip's
  move-speed contribution **capped at +20%** so it cannot stack into un-hittable.
- **Baseline ~75 levels** in a 10-minute run *with no XP upgrades*; XP boosts
  move it ±. Today 1.0x yields ~54, so levels get **~2.4x cheaper**. This
  **supersedes** `CURVE_QUADRATIC = 0.17` and `RATE = 1.45` in `progression.gd`,
  both added 2026-08-02 to cut level spam. That is coherent, not contradictory:
  those constants were a proxy fix for **card-screen** spam, and gate-3 fixes
  that directly, so they are now over-correcting. Record as a supersede.
- **XP effects become additive into one `xp_mult`, with a cap** (~1.5–1.6).
  Kills the multiplicative runaway. Same shape as the multishot tax.

### NOGAXEH v2 — the 10:00 climax

Event total **11,200 base HP**, 3.5x today's mirror.

- NOGAXEH **4000 HP** (doubled), **double the projectiles**. **No other enemies
  for the whole fight.**
- **Phase 1** — spawns with **2 full 1200 HP Prisms**. NOGAXEH invulnerable until
  both are dead. Full HP, not the current 0.5 escorts: the thing you beat at 5:00
  returns as a minion at full strength, and that lands harder unweakened.
- **Phases 2 and 3** — NOGAXEH vulnerable, escalating bullet density.
- **Phase 4** — high bullets plus **4 more full Prisms**. Shield is back up. This
  is the final stretch.
- **The finish.** Breaking the phase-4 shield **stuns** NOGAXEH and it begins
  charging an explosion. **5 seconds.** Kill it and it simply dies. Fail and it
  detonates: **70% of max HP near the centre, 50% of max HP everywhere else** —
  damage as a *percentage of max HP*, so stacking HP cannot trivialise it.
  **NOGAXEH dies either way**; the 5 seconds decide whether you eat the blast.
  Because it is %-based, a player who arrives above 50% survives and a player who
  arrives hurt does not — the attrition phases are what make the finale lethal.
- **Each of the 6 Prisms drops a guaranteed health pickup.** This is load-bearing,
  not a nicety: healing is world-drop only at 4.5% on an enemy death
  (`main.gd:456`), so "no other enemies" would leave the entire ~2-minute fight
  with six kill events and roughly a 27% chance of a single 2 HP heal. The adds
  therefore carry three jobs — the shield gate, the threat, and the sustain — and
  they put the heals exactly where the design wants them, right before the blast.
- **A distinct TRUE ENDING screen** when NOGAXEH dies: visually different from the
  5:00 victory screen, run stats, unlock reveal, Restart or Continue into endless.
  Today `victory` is emitted at most once per run on the *first* boss event
  (`run_director.gd:22`), so killing the mirror currently produces **nothing** —
  no screen, no stinger. The director needs a second signal for "a later boss
  event cleared" alongside the once-per-run `victory`.
- The death screen is now load-bearing too. A real fraction of runs will end here,
  and the human has never noticed the screen exists.

### Weapons become drafts, not possessions

- **Weapons are drafted mid-run as cards.** You no longer start a run owning the
  orbital, scattergun or lance.
- **A meta unlock adds that weapon's CARD to the draft pool** — beating the Prism
  means the orbital *can show up*, in this run and every future one. `MetaState`,
  the milestones and the mid-run announce all stay as built; only the delivery
  changes from "you own it" to "you may draft it." A stranger's first run is
  blaster-only to 5:00, then the orbital card enters the pool for the back half.
- **Drafting a weapon opens that weapon's branch of upgrades.** Today
  `requires_unlock` gates on the *meta* unlock (`weapon_resource.gd:44,70`,
  `gen_weapons.gd`); it becomes "drafted this run."
- **Each weapon gets one Legendary card that boosts it significantly.**
- **The orbital is boring and weak and needs a real redesign**, not a number buff.
  Its three cards going 0/11, 1/10 and 3/9 is the symptom.
- **Merge the three magnet-axis cards into one.** `lodestone` and `magnetism`
  are pure noise and `greed` already grants gem-magnet.
- All card changes go through `tools/gen_upgrades.gd` and the manifest, **never by
  hand** — that is the content-drift trap that already shipped a retired upgrade
  62 times.

### Meta skill tree (main menu)

Scoped in full this session over a recommendation to defer the tree and ship only
the catalogue. The concern raised and overruled: a permanent stat tree re-inflates
the power curve this rework just cut, and does so by a different amount per
player. Mitigated by tuning everything against a zero-tree account.

- **Currency is depth-weighted**: time survived plus a chunk per boss event
  cleared. Rewards reaching 10:00 and keeps a failed NOGAXEH attempt worth
  something. `total_kills` already exists for the running total; this adds an
  earned-per-run number and a save-schema change.
- **Small permanent upgrades to base stats.**
- **A handful of unique cards buyable there, all rarities** — a purchase injects
  the card into the draft pool.
- **A catalogue showing locked cards and how to unlock them.**
- UI must be **measured against the 640x360 viewport**, not the 1280x720 window.
  A skill tree at that size is genuinely hard. `scenes/dev/pause_layout_check.tscn`
  is the existing guard; extend it.

### Art

- **Baked glow vs real bloom: build it as a juice-lab variant and decide from the
  image.** The renderer is `gl_compatibility` at 640x360, and Godot 4.7's
  Compatibility backend does support real glow, so BRIEF's original worry — a
  post-process breaking a single-threaded web export — is mostly obsolete, and at
  that buffer size the cost is negligible. The real risk is visual: bloom at
  640x360 blooms in chunky pixel steps and hits everything above the threshold
  including HUD text. So it goes through `scenes/dev/juice_lab.tscn` as a variant
  next to the shipped one, produces a side-by-side contact sheet of the arena and
  the HUD, and the human picks from pixels. Baked stays the fallback.
- **The level-up card UI is now the centrepiece** and still reads as "better,
  still not there": dead space in the middle, no iconography, plain panel. It now
  carries 3x fewer, 3x more valuable decisions, plus weapon drafts and per-weapon
  Legendaries.
- Particles, poppy animations remain open.

## Build order — this is dependency-driven, not preference

1. **Telemetry fixes.** Nothing after this is measurable without them.
2. **Progression rework.** Changes the player power curve everything else is
   tuned against.
3. **Weapon drafting + card pool + orbital redesign.** Changes it again.
4. **NOGAXEH v2.** Must come after 2 and 3 — its tuning depends on player DPS at
   10:00, which both of those move.
5. **True ending screen + death screen.**
6. **Level-up card UI.**
7. **Skill tree + currency + catalogue.** Safe to come last precisely because
   everything is tuned against a zero tree.
8. **Glow juice-lab variant.** Independent, any time.
9. **Measure.** A human run to 10:00, then retune from the telemetry.

The glow variant and the card UI are the only items that can be parallelised
against the rest without a dependency risk.

## Not decided — do not decide these alone

- **Boss at 3:00 instead of 5:00.** Still explicitly parked: *"we revisit the 3
  mins later."* It is a rebalance, not a constant — `boss_interval` is one number
  but the whole wave table is authored against a five-minute ramp.
- **Melee is decorative** (96 `bolt` vs 20 `contact`). Not raised this session.
  Either the chase archetypes need a reason to exist or the roster is
  ranged-plus-texture, and that is a design call.
- **The floor is deliberately restrained.** The reference art is far brighter, but
  `BRIEF.md` says the floor "never competes." If it reads too subtle, that is a
  brief change, not a bug.

## Traps that bit previous sessions — read before editing

1. **Never round-trip a source file through PowerShell 5.1.** `Get-Content` reads
   UTF-8-without-BOM as cp1252 and `Set-Content` writes the mojibake back as real
   UTF-8. One bulk edit silently corrupted every em-dash in seven files, and the
   obvious repair reports every file *clean*. `hub/knowledge/tscn-text-editing.md`.
   Use the Edit tool or Python.
2. **`_unhandled_input` is gated by `process_mode`.** A PAUSABLE node receives no
   input at all while the tree is paused. Every key a pause-time UI advertises
   must be handled BY that UI. `hub/knowledge/pause-and-process-modes.md`.
   Directly relevant: the true ending screen and the skill tree.
3. **Anything a boss does in reaction to damage is inside a physics flush.**
   `phase_changed` fires from `take_hit` from `body_entered`. Defer every tree
   mutation reached that way. `hub/knowledge/physics-callbacks.md`. **NOGAXEH v2
   adds four more damage-triggered spawns and a damage-triggered stun — this trap
   is going to be hit again.**
4. **UI must be MEASURED against the 640x360 viewport, not the 1280x720 window.**
   Two reasoned fixes were wrong before a harness produced the number.
   `scenes/dev/pause_layout_check.tscn` guards it. `hub/knowledge/ui-must-fit.md`.
5. **Hand-maintained content lists drift.** Three orphans found in two days.
   `hub/knowledge/content-drift.md`.
6. **A music loop's tail-fold is the BRIDGE across the seam.** Shortening a
   ringing tail to fix a wrap click makes it worse. End the last bar on a rest.

## Commands

```powershell
# THE GATE. Run this, not the individual steps.
powershell -File tools/verify.ps1
powershell -File tools/verify.ps1 soak     # + 11 minutes clearing both boss events

# play it (debug build -> telemetry records automatically)
..\..\engine\Godot_v4.7.1-stable_win64.exe --path .

# read the telemetry (NOTE: --dir is REQUIRED until the default path is fixed)
python tools/analyze_telemetry.py --dir "$env:APPDATA\Godot\app_userdata\BESTAGON\telemetry"

# capture something that MOVES (--dev-autopilot drives a circle; without it the
# player stands still and every motion effect is invisible)
..\..\engine\Godot_v4.7.1-stable_win64_console.exe --path . -w --resolution 1280x720 `
  --fixed-fps 60 res://scenes/main/main.tscn --quit-after 5200 -- `
  --dev-godmode --dev-autopick --dev-unlocks --dev-autopilot `
  --screenshot=<abs>/.ai/shot.png --shot-frame=5000

# content generators (re-run after editing the tool, then --import)
python tools/gen_assets.py                 # every sprite + the circuit floor
<console.exe> --headless --path . -s res://tools/gen_waves.gd      # enemies + waves
<console.exe> --headless --path . -s res://tools/gen_upgrades.gd   # upgrades + manifest
<console.exe> --headless --path . -s res://tools/gen_weapons.gd    # weapons
<console.exe> --headless --path . -s res://tools/gen_powerups.gd   # powerups

# audio
python tools/build_music.py --only track4  # music stems
python tools/build_sfx.py --only dash      # one-shots
python tools/score_viewer.py               # visualiser -> .ai/score.html

# exports (both rebuilt clean this session)
<console.exe> --headless --path . --export-release "Web" builds/web/index.html
<console.exe> --headless --path . --export-release "Windows Desktop" builds/windows/BESTAGON.exe
```

## Dev flags

`--dev-godmode` · `--dev-autopick` · `--dev-autocontinue` · `--dev-unlocks`
· `--dev-stats` · `--dev-autopilot` · `--dev-telemetry`

**Any `--dev-` flag redirects the save to `user://save_dev.cfg`.** Note that
`--dev-unlocks` will need rethinking once weapons are drafted rather than owned.

## Suggested opening prompt for the next session

> Continuing BESTAGON in `D:\Github\Godot\games\01-survivor`. Read `HANDOFF.md`
> — it holds a fully locked spec from a telemetry grilling session, so do not
> relitigate the decisions in it. Start at step 1 of the build order (the
> telemetry fixes), then work down. `TODO.md` M7 has the same items as a
> checklist.
