# 01-survivor — TODO

**V1.Final — shipping as "BESTAGON".** [BRIEF.md](BRIEF.md) is the spec — prime directive, defect
definition, gates and acceptance criteria. This file is the running checklist. Deviations go in
[DECISIONS.md](DECISIONS.md).

Prime directive: *someone clicks this on itch.io, plays one five-minute run, and immediately clicks
restart.*

**Tuning audience, locked 2026-08-02:** a stranger's first **10** minutes. A stranger is by
definition a zero-skill-tree account, so *every difficulty number is tuned against an empty tree*.

Scope control is by **content counts and gates**, not by dates. One public release, at the end.

## Division of labor

Claude builds all of v1.1 and narrates the architecture; the human studies and quizzes separately
via repo-tutor. There are **no HUMAN-BUILT challenge systems in this version** — see `DECISIONS.md`
for why the v1 declaration lapsed (hub D14 superseded D4).

---

## v1.1 milestones

### M0 — Fix pass
The five open findings in `DECISIONS.md`, plus the missing damage test.

- [x] Commit the pending `player.tscn` `resource_local_to_scene` fix
- [x] `enemy.tscn` — `resource_local_to_scene` on the RectangleShape2D (shared-hitbox bug)
- [x] `main.gd` — push HUD state after chained level-ups
- [x] `spawner.gd` — cap live enemies (`Difficulty.MAX_ALIVE` + pure `should_spawn`)
- [x] `xp_gem.gd` — bound gem lifetime (auto-home after `IDLE_TIMEOUT`)
- [x] `tests/unit/test_damage.gd` — the acceptance criterion v1 named but never wrote
- [x] Audit sweep: every `.tscn` sub-resource that gets mutated at runtime is `resource_local_to_scene`
- [x] Dev flags `--dev-godmode` / `--dev-stats` / `--dev-autopick`

**Gate: PASSED 2026-08-02.** 35/35 GUT green · headless smoke clean · 10-minute fixed-timestep soak
holds enemies at exactly the 110 cap, pickups 0–1, projectiles 0–2 · Web + Windows exports both
produce, and the web build boots and plays at `localhost:8060`.

Soak command (keep — needed again for M2 balancing):
```
<console.exe> --headless --path . res://scenes/main/main.tscn --fixed-fps 60 --quit-after 36000 -- --dev-godmode --dev-stats --dev-autopick
```
`--fixed-fps` matters: game time accrues from real delta, so without it a headless run burns frames
without advancing the clock. Launch `main.tscn` directly — the title screen waits for a click.

### M1 — Visual identity ⭐ HARD GATE
Regenerate every sprite in the neon-geometric style; apply the colour law from BRIEF §5.

- [x] Rewrite `tools/gen_assets.py` sprite generation: filled geometry + baked glow halo
- [x] Player, projectile, orbital, 5 enemy silhouettes, gem, bolt, boss core
- [x] Arena floor / grid, background
- [x] Project-wide neon `Theme` (`assets/theme/neon.tres`) — no default-theme controls anywhere
- [ ] Retune the hit-flash shader for the neon palette *(deferred: the existing white flash reads
      correctly against saturated neon; revisit only if it stops reading during the M7 playtest)*

**HARD GATE: PASSED 2026-08-02.** Arena, title, level-up and game-over screens all captured and
reviewed — reads as designed, not generated.

### M2 — Run Director
Waves as data, elites, boss, win condition, endless.

- [x] `WaveResource` / director schedule as `.tres` (8 waves, authored by `tools/gen_waves.gd`)
- [x] Elite modifier (pulsing rim, HP, damage, XP)
- [x] The Prism — 2 phases, every attack telegraphed
- [x] Enemy projectiles + collision layer 6
- [x] Victory state, reward banking, Restart / Continue choice
- [x] Endless: double boss at ~10:00, +1 boss per 5:00, cap 3
- [x] Run-intensity signal published for the audio layer
- [ ] Rebalance 0:00–5:00 — needs a HUMAN playtest, not a soak (see below)

**Gate: PASSED 2026-08-02** (except the rebalance, which cannot be judged headless). Soak to 16:00:
boss at 5:00 → victory → endless → **2 bosses at 10:00, 3 at 15:00 (capped)**; enemies bounded
8–14 throughout; no `SCRIPT ERROR`. 46/46 GUT green.

⚠️ **Open balance question for the playtest:** with `--dev-autopick` (which takes a random offer)
the first boss took 23s in one run and 166s in another. A human picking damage deliberately should
be much faster, but the spread means boss HP (`resources/enemies/prism.tres`, 230) is unverified at
human skill. Tune it from a real run, not from a soak.

### M3 — Run & Meta State
- [x] Contract written first (docstrings on `RunState` / `MetaState`)
- [x] Run seed; one RNG drives upgrades, enemy choice and placement
- [x] Strict run-state / meta-state separation (values cross, never references)
- [x] Save/load via ConfigFile, unlocks as milestones
- [x] Round-trip + corruption-tolerance tests

**Gate: PASSED 2026-08-02.** Two real launches: fresh profile → victory at 5:18 → relaunch reads
`runs=1 wins=1 best_time=318 best_kills=369 unlocks=[orbital]`. Run state is never written, so it
cannot persist. 59/59 GUT green.

Beating the Prism unlocks the **Orbital** — which is M4's second weapon, so the win has something
to give.

### M4 — Weapons as data
- [x] Contract written first (docstring on `WeaponResource`)
- [x] `WeaponResource` + blaster ported onto it. Stats became MODIFIERS
      (`damage_bonus`, `fire_rate_mult`, …); base numbers live on the weapon, so
      one "+12% fire rate" improves two weapons with different base rates
- [x] Orbitals — the second weapon, gated behind beating the Prism
- [x] Orbital-specific upgrades, gated by `requires_unlock` so they never clutter
      the offers of a player who has not unlocked the weapon
- [ ] **Human verification:** both weapons distinct in a 30-second clip

**Gate:** both weapons read as distinct in a 30-second clip. *Code complete and
soak-verified; the feel half needs a playtest with the orbital unlocked.*

### M5 — Enemy archetypes
- [x] Drifter, Dart, Bulwark, **Lancer** (pulled forward — the ranged threat was
      the actual fix for "I could just stand still")
- [x] Per-type silhouettes via `EnemyStats.sprite` — archetypes are pure data now
- [x] `EnemyStats.Behavior` enum (CHASE / RANGED)
- [x] Elite variants (modifier, any type)
- [x] Splitter + its death payload

**Gate:** each type identifiable by silhouette and colour alone at 12 px, in a crowd.

### M6 — Audio
- [x] Compose in Strudel: 3 interchangeable tracks as intensity stems, title, victory
- [x] Render → tail-fold → OGG pipeline (`tools/build_music.py`), track-discovering
- [x] Stem crossfade driven by the Run Director's intensity signal
- [x] Track rotation (one per run) + in-menu selector for testing
- [x] Title theme: 64s slow burn that escalates in four sections, then resets
- [x] Victory merges — ducks the stems and lands on the next bar line
- [x] Score viewer (`tools/score_viewer.py`) — piano roll + live Strudel code view
- [x] Full SFX pass: 19 Strudel-authored sounds (23 files, pitch-varied sets for shoot/hit/pop/
      pickup), `tools/build_sfx.py` pipeline, `Sfx` variant support, every cue rewired — the boss
      telegraph is a dread-swell now, not the level-up jingle
- [x] Volume / mute options *(already shipped in the pause panel: sliders + mute + M key; box was stale)*

**Gate:** five consecutive runs without the music grating · every action has a sound · no audible
seam at a loop point or layer change. *(Code-complete; the "grating" half is the human's ear at the
post-M6.5 playtest.)*

### M6.25 — Upgrade rarity ✅ (added mid-cycle from playtest direction)
- [x] 5 tiers, per-card roll, odds improving with progress, saturating at level 30
- [x] Pity floor: guaranteed Rare-or-better after 6 barren level-ups
- [x] Superlinear XP curve — ~30% fewer levels (39 vs 55 on a 6000 XP run)
- [x] 36 upgrades across the tiers, incl. 6 Epic + 5 Legendary unique mechanics
- [x] Neon-LED rarity frames; arena colour law untouched (menu is a separate context)

### M6.4 — Remaining content
- [x] Splitter (dies into two Darts)
- [x] Ram (telegraphs, then dashes in a straight line)
- [x] Shooting variants (playtest ask): **Scattergun** (5-pellet cone, short range, gated on
      `elite_hunter` / 1000 kills) + **Prism Lance** (instant piercing beam, new `Kind.BEAM`,
      gated on `endless_proven`) — every meta milestone now unlocks a weapon
- [x] Rename everything to **PRISM** (title, window, exports, boot line; save + telemetry migrated)
- [ ] *(second boss deferred — built alongside the M6.5 findings)*

### M6.5 — Design review before ship ⭐ REQUESTED BY THE HUMAN
Before M7, stop and assess the whole game as a game, not as a checklist.

- [x] Run a multi-agent review: specialists per area (game feel, balance/economy,
      readability & UX, performance, code architecture, new-player onboarding)
- [x] Each returns concrete, prioritised changes with rationale
- [x] **Claude assesses which are worth doing** — this is a filter, not a to-do dump
- [x] Apply the accepted set, re-verify, re-playtest — 27 of 29 applied; 21 and 22 deferred as
      pure refactors
- [x] Feed telemetry from real playtests into the review as evidence
- [x] **Game-feel findings go through the juice lab** (`scenes/dev/juice_lab.tscn`), not straight
      into the game: build the change as a variant next to the shipped one, then let a human pick.
      Cases live in `_variants()` / `_play()`.

**Gate: PASSED 2026-08-02.** 31-finding review closed, apply pass done, three rounds of live
playtest feedback on top. Rejections recorded in `DECISIONS.md`.

---

### M7 — The playtest rework ⭐ SPEC LOCKED 2026-08-02

The first clean human run to 10:00 (`run_076`, no dev flags) produced a spec, not a bug list.
**Full detail and the evidence behind every number is in `HANDOFF.md` — read it before starting.**
The headline findings: **NOGAXEH died in ~22s against a ~120s target**, the player **never came
close to dying in 11 minutes** (lowest HP after any hit 37.5%, once), and **79 level-ups** meant a
card screen every 7.9s.

Do these **in order** — it is dependency-driven, not preference. Player DPS at 10:00 is moved by
items 2 and 3, and item 4 is tuned against it.

**7.1 — Fix the instrument first.** ✅ done 2026-08-03. Nothing below was measurable until this was.
- [x] `begin_run()` called `_close()` instead of `end_run()` — a restart dropped the ending row,
      so both runs that ever reached a boss had no `run_end`
- [x] `_run_t` reset in `begin_run()` — a new run's `run_start` carried the previous run's clock
- [x] `analyze_telemetry.py` defaults to `BESTAGON` (newest of three app-dir names), and now
      **excludes dev-flagged runs from every aggregate** (`--include-dev` to keep them)
- [x] `run_start` records the active `--dev-` flags and the short commit (read straight from
      `.git/HEAD`, empty in an exported build — no build step)
- [x] **`Main._finish_run()` is the one place a run ends** — death, restart, quit to title and
      window close all bank now. Only death used to, which is the actual cause of the records loss
- [x] Verified: `run_076` peaked at **2757 kills / 660.1s** while `save.cfg` still reads
      `best_kills=1125`, `best_time=349.2` — and `endless_proven` (PRISM LANCE) was **earned and
      lost**, because the player restarted instead of dying. Fixed forward; the existing save is
      left alone (a retro-repair is the human's call)

**7.2 — Progression.** Baseline **~75 levels** with no XP upgrades; boosts move it ±.
- [ ] Cards gate to **every 3rd level** — ~25 screens per run instead of 78
- [ ] Silent per-level stat drip, no interruption: damage, fire rate, a little move speed.
      **No passive max HP or defense** — defense stays card-only so it remains a real choice.
      Starting points to verify by measurement: +1.5% dmg, +0.75% fire rate, +0.3% move speed
      per level, move-speed contribution **capped at +20%**
- [ ] Rebalance the XP curve — 1.0x currently yields ~54 levels, so levels get **~2.4x cheaper**.
      **Supersedes** `CURVE_QUADRATIC = 0.17` and `RATE = 1.45`, which were a proxy fix for
      card-screen spam that gate-3 now fixes directly. Record the supersede in `DECISIONS.md`
- [ ] XP effects become **additive** into one `xp_mult` with a cap (~1.5–1.6) — `greed` is Epic,
      +50%, 2 stacks, and stacks *multiplicatively*; with `scholar` it reached **3.0x**

**7.3 — Weapons become drafts, not possessions.**
- [ ] Weapons are drafted mid-run as cards; you no longer start a run owning any of them
- [ ] A meta unlock adds that weapon's **card to the draft pool** — `MetaState` and the milestones
      stay as built, only the delivery changes
- [ ] Drafting a weapon **opens that weapon's branch** of upgrades — `requires_unlock`
      (`weapon_resource.gd:44,70`) moves from "unlocked in meta" to "drafted this run"
- [ ] One **Legendary card per weapon** that boosts it significantly
- [ ] **Redesign the orbital** — it is boring and weak; all three of its cards are bottom-five
      (0/11, 1/10, 3/9). A weapon problem, not a card problem
- [ ] Merge the three magnet-axis cards into one (`lodestone` 0/16, `magnetism` 0/12)
- [ ] All card changes go through `tools/gen_upgrades.gd` and the manifest, **never by hand**

**7.4 — NOGAXEH v2.** Event total **11,200 base HP**, 3.5x today's mirror. No other enemies.
- [ ] NOGAXEH **4000 HP**, **double the projectiles**
- [ ] Phase 1 — spawns with **2 full 1200 HP Prisms**; invulnerable until both are dead
- [ ] Phases 2–3 — vulnerable, escalating bullet density
- [ ] Phase 4 — high bullets plus **4 more full Prisms**, shield back up
- [ ] The finish — breaking the phase-4 shield **stuns** NOGAXEH and it charges an explosion.
      **5 seconds.** Kill it and it dies clean. Fail and it detonates for **70% of max HP near the
      centre, 50% everywhere else** — a *percentage of max HP*, so HP-stacking cannot trivialise
      it. **NOGAXEH dies either way**; the 5s decides whether you eat the blast
- [ ] **Each of the 6 Prisms drops a guaranteed health pickup** — load-bearing, not a nicety:
      healing is world-drop only at 4.5% on a kill, so "no other enemies" leaves the whole fight
      with ~a 27% chance of one 2 HP heal
- [ ] Budget the fight in **seconds at measured DPS**, never as an HP ratio to the 5:00 event —
      that is exactly how the current 1.9x budget produced a 22-second fight
- [ ] **The Prism at 5:00 stays exactly as it is** (49s, accepted)

**7.5 — Endings.**
- [ ] **A distinct TRUE ENDING screen** when NOGAXEH dies — different from the 5:00 victory screen,
      run stats, unlock reveal, Restart or Continue. The director needs a second signal for "a
      later boss event cleared"; today `victory` fires at most once per run on the *first* event
      (`run_director.gd:22`), so killing the mirror currently produces nothing at all
- [ ] **The death screen** — now load-bearing, and the human has never noticed it exists

**7.6 — The level-up card UI.** Now the centrepiece: 3x fewer, 3x more valuable decisions, plus
weapon drafts and per-weapon Legendaries.
- [ ] Still reads as "better, still not there" — dead space in the middle, no iconography,
      plain panel
- [ ] Legendary should *feel* rare rather than just brighter. Note it already **is** rare — 4
      appearances in 234 slots (1.7%), taken 4/4. This is presentational only

**7.7 — Meta skill tree (main menu).** Scoped in full over a recommendation to defer; the concern
recorded is that a permanent stat tree re-inflates the curve this rework just cut, mitigated by
tuning everything against a zero-tree account.
- [ ] **Depth-weighted currency**: time survived + a chunk per boss event cleared. New
      earned-per-run number and a save-schema change
- [ ] Small permanent upgrades to base stats
- [ ] A handful of unique cards buyable there, all rarities — a purchase injects the card into the
      draft pool
- [ ] A catalogue showing locked cards and how to unlock them
- [ ] Measure the UI against the **640x360** viewport, not the 1280x720 window — extend
      `scenes/dev/pause_layout_check.tscn`

**7.8 — Art.** Parallelisable against everything above.
- [ ] **Baked glow vs real bloom → build it as a juice-lab variant and decide from the image.**
      BRIEF's worry (a post-process breaking a single-threaded web export) is mostly obsolete:
      `gl_compatibility` supports glow in 4.7 and at 640x360 the cost is negligible. The real risk
      is visual — chunky bloom steps and washed HUD text. Side-by-side contact sheet of arena and
      HUD; baked stays the fallback
- [ ] Particles, poppy animations

**Gate:** a human run to 10:00 where NOGAXEH takes ~2 minutes, the player is genuinely threatened
before the finale, and the telemetry that says so was recorded by a fixed instrument.

### M8 — Ship
- [ ] Full human playtest pass
- [ ] README with a GIF
- [ ] Web + Windows exports
- [ ] itch.io page: HTML, browser-playable, 1280×720 embed, cover image
- [ ] butler push
- [ ] **Postmortem in hub** + knowledge notes + pattern-candidate review

**Gate:** a stranger plays it in their browser at an itch.io URL. No postmortem → no game 2.

---

## Log

- [x] **v1.0 M0** Skeleton — boots headless, GUT 9.7.1 green, exports verified
- [x] **v1.0 M1** Player — movement, camera, arena
- [x] **v1.0 M2** Enemies & damage — chase, spawner, contact damage, i-frames
- [x] **v1.0 M3** Combat & XP — auto-weapon, projectiles, gems, magnet
- [x] **v1.0 M4** Progression — UpgradeResource, weighted pool, pick-1-of-3 UI
- [x] **v1.0 M5** Game loop — HUD, game over, restart, difficulty ramp, fast enemy
- [x] **v1.0 M6** Juice & assets — generated assets, audio buses, SFX/music, juice pass
- [ ] **v1.0 M7** superseded by v1.1 (hub D15 — v1.1 is a continuation; the ship gate moves to v1.1 M7)
- [x] **v1.1 M0** Fix pass (2026-08-02) — 5 findings closed, growth bounded and proven, 35 tests green, both builds produce
- [x] **v1.1 M1** Visual identity (2026-08-02) — neon generator, colour law, project-wide theme
- [x] **v1.1 M2** Run Director (2026-08-02) — waves as data, elites, The Prism, victory, endless
- [x] **v1.1 M3** Run & Meta State (2026-08-02) — seed, save/load, unlocks
- [x] **v1.1 M5** Enemy archetypes (2026-08-02) — Drifter, Dart, Bulwark, Lancer, Ram, Splitter, elites
- [x] **v1.1 M4** Weapons as data (2026-08-02) — WeaponResource, orbitals, unlock-gated upgrades
- [x] **Tooling** (2026-08-02) — juice lab (`scenes/dev/`) + contact-sheet mode on the screenshot
      autoload. Closes the gap between headless verification and whole-game screenshots: neither
      could judge a 0.3 s effect. Used by M6.5.
- [x] **v1.1 M6** Audio (2026-08-02) — 4 tracks as intensity stems, title, victory, 19-sound SFX pass
- [x] **v1.1 M6.25** Upgrade rarity (2026-08-02) — 5 tiers, pity floor, superlinear XP, 36 upgrades
- [x] **v1.1 M6.4** Remaining content (2026-08-02) — Splitter, Ram, Scattergun, Prism Lance, rename
- [x] **v1.1 M6.5** Design review (2026-08-02) — 31 findings, 27 applied, BESTAGON rename, NOGAXEH, dash
- [ ] v1.1: **M7 the playtest rework** ← next (spec locked, see `HANDOFF.md`) · M8 ship

*The ship gate moved from M7 to M8 because the first clean human run to 10:00 turned into a rework
spec rather than a punch list. Scope grew by explicit decision, not by drift.*

*Checkboxes are updated at session end. A milestone list that lies is worse than none.*
