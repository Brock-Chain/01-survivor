# 01-survivor — TODO

**V1.Final — shipping as "PRISM".** [BRIEF.md](BRIEF.md) is the spec — prime directive, defect definition, gates
and acceptance criteria. This file is the running checklist. Deviations go in
[DECISIONS.md](DECISIONS.md).

Prime directive: *someone clicks this on itch.io, plays one five-minute run, and immediately clicks
restart.*

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
- [ ] Splitter + its death payload

**Gate:** each type identifiable by silhouette and colour alone at 12 px, in a crowd.

### M6 — Audio
- [x] Compose in Strudel: 3 interchangeable tracks as intensity stems, title, victory
- [x] Render → tail-fold → OGG pipeline (`tools/build_music.py`), track-discovering
- [x] Stem crossfade driven by the Run Director's intensity signal
- [x] Track rotation (one per run) + in-menu selector for testing
- [x] Title theme: 64s slow burn that escalates in four sections, then resets
- [x] Victory merges — ducks the stems and lands on the next bar line
- [x] Score viewer (`tools/score_viewer.py`) — piano roll + live Strudel code view
- [ ] Full SFX pass: replace the 8 stdlib WAVs, add ~8 missing cues, pitch-varied sets
- [ ] Volume / mute options

**Gate:** five consecutive runs without the music grating · every action has a sound · no audible
seam at a loop point or layer change.

### M6.25 — Upgrade rarity ✅ (added mid-cycle from playtest direction)
- [x] 5 tiers, per-card roll, odds improving with progress, saturating at level 30
- [x] Pity floor: guaranteed Rare-or-better after 6 barren level-ups
- [x] Superlinear XP curve — ~30% fewer levels (39 vs 55 on a 6000 XP run)
- [x] 36 upgrades across the tiers, incl. 6 Epic + 5 Legendary unique mechanics
- [x] Neon-LED rarity frames; arena colour law untouched (menu is a separate context)

### M6.4 — Remaining content
- [ ] Splitter (dies into two Darts)
- [ ] Ram (telegraphs, then dashes in a straight line)
- [ ] Rename everything to **PRISM**
- [ ] *(second boss deferred — built alongside the M6.5 findings)*

### M6.5 — Design review before ship ⭐ REQUESTED BY THE HUMAN
Before M7, stop and assess the whole game as a game, not as a checklist.

- [ ] Run a multi-agent review: specialists per area (game feel, balance/economy,
      readability & UX, performance, code architecture, new-player onboarding)
- [ ] Each returns concrete, prioritised changes with rationale
- [ ] **Claude assesses which are worth doing** — this is a filter, not a to-do dump
- [ ] Apply the accepted set, re-verify, re-playtest
- [ ] Feed telemetry from real playtests into the review as evidence

**Gate:** the accepted changes are applied and verified, and anything rejected is
recorded in `DECISIONS.md` with why. Only then does M7 start.

### M7 — Ship
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
- [~] **v1.1 M5** mostly done early (playtest response) — Splitter outstanding
- [x] **v1.1 M4** Weapons as data (2026-08-02) — WeaponResource, orbitals, unlock-gated upgrades
- [ ] v1.1: **M6** audio ← next · **M6.5 design review** · M7 ship  *(M5 all but the Splitter is done)*

*Checkboxes are updated at session end. A milestone list that lies is worse than none.*
