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
**Full detail and the evidence behind every number is in the 7.1-7.9 entries below and in `DECISIONS.md`.**
The headline findings: **NOGAXEH died in ~22s against a ~120s target**, the player **never came
close to dying in 11 minutes** (lowest HP after any hit 37.5%, once), and **79 level-ups** meant a
card screen every 7.9s.

Do these **in order** — it is dependency-driven, not preference. Player DPS at 10:00 is moved by
items 2 and 3, and item 4 is tuned against it.

**7.1 — Fix the instrument first.** ✅ done 2026-08-02. Nothing below was measurable until this was.
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

**7.2 — Progression.** ✅ done 2026-08-02. Measured in a soak: **level 71 at 10:00, 74 at 11:00,
exactly 25 card screens.**
- [x] Cards gate to every 3rd level (`Progression.CARD_EVERY`), first card always on the first
      level-up so the loop teaches itself — levels 2, 5, 8, ... = 25 screens
- [x] Silent per-level drip: +1.5% dmg, +0.75% fire rate, +0.3% move speed, move speed capped at
      +20% (level 68). No max HP, no defense. **Set from the level, never accumulated** — a chained
      level-up resolves several levels in one frame and would otherwise apply it two or three times
- [x] `RATE` 1.45 → **0.61** (`CURVE_QUADRATIC` untouched). Solved against run_076's ~20,500 XP:
      level 54 before, 74 after. Supersede recorded in `DECISIONS.md`
- [x] XP effects additive into `Stats.add_xp_bonus()` under `XP_MULT_CAP = 1.6`
- [x] Not in the spec but forced by it: `Rarity.PROGRESS_FULL_LEVEL` 30 → 42 (a 75-level run would
      have saturated the ladder 40% in) and `PITY_LIMIT` 6 → 4 (it counts screens, and screens went
      from ~79 a run to ~25)

**7.3 — Weapons become drafts, not possessions.** ✅ done 2026-08-02.
- [x] Weapons are drafted mid-run as cards; a run starts blaster-only regardless of profile
- [x] A meta unlock adds the weapon's **card** to the pool (`draft_orbital` etc., RARE so it
      actually appears in a 25-screen run). Milestones, announce and `MetaState` unchanged
- [x] `WeaponResource.requires_unlock` deleted — a weapon's gate is its own id, so weapon and
      requirement cannot drift apart. `Main._offer_gates()` merges profile unlocks + this run's
      drafts into the one array the pool already took
- [x] Drafting a weapon opens its branch (`UpgradeResource.weapon_gate()`), which also fixes a
      quiet bug: orbital cards used to gate on the META unlock, so a veteran saw them every run
- [x] One Legendary per weapon: Twin Fangs (blaster echo volley), Singularity (the ring drags
      enemies in), Flechette Storm (the cone becomes a ring), Refraction (three beams)
- [x] **Orbital redesigned** — kill-fed MOMENTUM: every kill adds spin up to 2x, decaying when
      the killing stops, and spin is hit rate. Bigger, faster, three shards. The dead radius card
      folded into Split Orbit
- [x] Magnet axis merged to one card; `lodestone` and `orbit_radius` retired, and `gen_upgrades.gd`
      now **prunes orphaned .tres** so a retirement cannot leave the card in the pool
- [x] Card magnitudes rebalanced ~2-3x + `Stats.COOLDOWN_FLOOR`. Forced by measurement — see
      `DECISIONS.md`, the drip as specced left the arena pinned at the enemy cap from 3:00

**7.4 — NOGAXEH v2, the 10:00 climax.** ✅ done 2026-08-02. Event total **11,200 base HP**.
- [x] NOGAXEH **4000 HP**, projectiles roughly doubled and escalating across four phases
- [x] Phase 1 — spawns with **2 full 1200 HP Prisms**, invulnerable until both are dead. Not an HP
      threshold and cannot be: it is invulnerable for the whole phase, so its HP never moves.
      `Boss.force_phase()` exists for exactly this
- [x] Phases 2–3 — vulnerable, denser each time
- [x] Phase 4 — **4 more full Prisms**, shield back up
- [x] The finish — breaking the phase-4 shield **stuns** NOGAXEH and lights a **5s fuse**. Kill it
      and it dies; run out the clock and it detonates for **70% of max HP** in the core / **50%**
      outside, then dies anyway. Percentages, so stacking HP cannot trivialise it
- [x] **Nothing else spawns** for the whole fight (`RunDirector.can_spawn`)
- [x] Each of the **6 Prisms drops a guaranteed health pickup** — load-bearing, since world heals
      are 4.5% on an enemy death and there are no other enemies
- [x] Budgeted in seconds at measured DPS. `ESCORT_HP` and its ratio reasoning are deleted
- [x] The Prism at 5:00 is untouched
- [x] Verified in a full soak: escorts gate phase 1, four more at phase 4, fuse lit at 804.5s,
      detonation exactly 5.0s later, `alive=0` for the entire fight

**7.5 — Endings.** ✅ done 2026-08-02.
- [x] **A distinct TRUE ENDING screen** — gold where victory is cyan, run record, weapons drafted,
      unlock reveal, Keep going / New run
- [x] `RunDirector.boss_event_cleared` added alongside the once-per-run `victory`. Killing NOGAXEH
      used to produce **nothing at all**, because `victory` had already fired at 5:00
- [x] Measured at **640x360** — the first draft came out **633px tall against a 360px viewport**
      and `scenes/dev/pause_layout_check.tscn` caught it. The harness now guards this screen too,
      and doubles as its capture rig
- [x] Death screen: NOGAXEH and the detonation both name themselves, and the blast line says what
      to do differently — it is the one death a player can specifically fix

**7.6 — The level-up card UI.** ✅ done 2026-08-02. It is the centrepiece now: ~25 screens a run
instead of ~78, so each one is worth 3x and gets looked at 3x as hard.
- [x] **Iconography** — `UpgradeIcon`, a glyph per effect FAMILY (offence, rate, breadth, movement,
      survival, fortune, orbit, weapon), drawn with `_draw` rather than imported: at 28px it is a
      few primitives, it inherits the card's rarity hue for free, and it adds nothing to the export
- [x] **The dead space is gone** — the glyph sits exactly where the hole was, and name and
      description are centred so three cards scan as a set
- [x] Cards grown 172x118 → 184x132
- [x] A weapon draft says **NEW WEAPON** instead of its tier — its rarity is a draw frequency, not
      a description, and the player's question is "stat or new toy", not "how rare"
- [x] `pause_layout_check` now measures the level-up panel too, at its worst case (the three
      longest descriptions in the pool). It has shipped broken once already, at level 57

**7.7 — Meta skill tree (main menu).** ✅ done 2026-08-02. Reached from the title as **GRID**.
- [x] **Depth-weighted currency (shards)**: 6 per minute survived + 25 per boss event cleared.
      Deliberately not kill-weighted — kills would pay best for farming the easy minutes. Save
      schema gained `shards` and `purchases`; a pre-tree save reads as an empty tree, not a crash
- [x] Continuing into endless is never a currency loss: victory banks its share, the real ending
      tops up to the run's full depth
- [x] **6 small permanent stat nodes**, each carrying an `UpgradeResource` payload rather than a
      second copy of the effect switch — a node and a card that both say "+2 max HP" cannot disagree
- [x] **3 buyable cards** (Rare / Epic / Legendary) that are absent from the pool until bought. A
      purchase buys the CHANCE to be dealt one, never the effect, so the tree cannot hand a
      returning player power a stranger cannot reach
- [x] The catalogue is the screen: owned vs locked, with costs, so what you cannot afford yet is
      the reason to play another run
- [x] Authored by `tools/gen_skills.gd` + manifest + orphan pruning, like every other content type
- [x] **Measured at 640x360.** A literal branching tree needs ~3x that height before a node is
      legible, so it is a scrolling list grouped by cost — designed around the constraint rather
      than measured against it afterwards. `pause_layout_check` guards the frame and the Back button
- [x] Shards shown on the death screen and on the title button, or the currency is invisible
- [ ] *Later idea (human, 2026-08-02): lay the GRID out as actual hexagonal cells rather than
      rows. Fits the game's whole shape language; needs a layout that still passes the 640x360
      harness, which is why it is parked rather than done*

**7.8 — Art.** Parallelisable against everything above.
- [~] **Baked glow vs real bloom** — lab case built (`--lab-case=glow`, 3 variants) and three sheets
      captured, but the comparison is **not yet conclusive** and is recorded that way: the two bloom
      variants render identically to each other despite very different strengths, and both lose the
      halo baked into the sprite, so the rig is comparing render PATHS not looks. The solid finding:
      a `WorldEnvironment` on the root viewport is a **no-op** under `gl_compatibility` — the
      backbuffer is allocated at boot from `rendering/viewport/hdr_2d`, so real glow needs a
      `project.godot` change or a `SubViewport` with `use_hdr_2d` set before it enters the tree.
      Baked ships, which was always the fallback
- [ ] Particles, poppy animations

**7.9 — Measure.** ⚠️ **THE REMAINING WORK.** Everything above is built and soak-verified;
what a bot cannot verify is tuning.
- [x] Instrument fixed and proven (7.1) — every exit path banks, flags and commit recorded
- [x] Structure verified by soak: phases, gates, the fuse, the detonation, guaranteed drops, both
      endings, shard banking, the whole loop from a fresh profile
- [ ] **A human run to 10:00, then retune from the telemetry.** Bot variance is now too wide to
      tune against — two identical soaks produced level 85 and level 50 at 10:00, because autopick
      takes `offers[0]` and a run has ~25 picks each worth 3x what they used to be
- [ ] Specific numbers awaiting that run: `RunDirector.MIRROR_LEVEL_STEP` (0.045, produced a 142s
      fight in a soak against a ~120s target), the 5:00 Prism's length under the new curve, whether
      the defensive cards revive now that the boss rework asks for defense, and whether the arena
      still saturates for a weak build around 3:00

**Gate:** a human run to 10:00 where NOGAXEH takes ~2 minutes, the player is genuinely threatened
before the finale, and the telemetry that says so was recorded by a fixed instrument.

### M8 — Ship
- [ ] Full human playtest pass — **Windows build under test 2026-08-03.** Second pass applied:
      boss bar, boss weld, twin cards, Dart facing (see `DECISIONS.md`, playtest 5). Not yet
      re-played
- [x] **The rAF hypothesis is DEAD (2026-08-03).** Windows froze too, so the freeze is not a
      browser throttling artefact. A full dump of the hung process (37 min, PID 53468) says the main
      thread is blocked on a kernel wait *inside a Win32 window procedure* — never returning to
      Godot's frame loop — while burning ~0.42 core, twice what healthy gameplay costs (measured
      baseline: ~0.20). Not GDScript: every `while` in game code provably terminates, and no thread
      was executing game code. Stack is `ntdll wait ← uxtheme ← KERNELBASE ← [engine] ← user32
      dispatch`, on `gl_compatibility` + NVIDIA 591.86 with `nvspcap64.dll` (ShadowPlay) injected
- [ ] **Freeze: FOUR occurrences, two machines; the recorder caught #3 AND #4 (2026-08-03).**
      #1 local at 5:53 in a dense PRISM fight; #2 on a friend's RTX 4070 SUPER (driver 595.97,
      NEWER than local 591.86, same Windows 26200, log said only "boot OK" — that forced the
      breadcrumbs); #3 local with the recorder live: last line `[stats] t=90s enemies=5 bolts=0
      bosses=0`, no `[exit]` → froze in the 90–120 s window, LV~17, arena NEAR-EMPTY. That kills
      any boss/density correlation. No `[pause]` line all run → the game-code focus-pause path was
      not involved in #3 (the engine's own WndProc below it stays suspect). Player reports an
      audio cue at the freeze; LV pace puts a CARD screen (level 17) inside the window — the card
      open plays the loud cue, pauses the tree and builds UI, so `[card] open/pick` markers now
      bracket it and `[stats]` carries `speed=xN`. **#4 minutes after #3, SAME window:** last line
      `[stats] t=90s enemies=6 bolts=0 bosses=0` at LV16 — the level-17 card due again, arena
      near-empty again, no `[exit]`. Two consecutive freezes in one window = repro is HOT.
      Wall-clock note: IF #1 ran at SPEED x3 (that session's screenshots show x3 in use), its 5:53
      game time is ~118 s of wall clock — all three local freezes would then sit in the same
      ~90–120 s WALL band, pointing at a timer outside the game (overlay attach, driver
      housekeeping) rather than game state; `speed=xN` settles this next time. Overlay inventory on the freezing machine:
      **NVIDIA Overlay** (its capture DLL `nvspcap64.dll` is the one injected in the dump),
      `nvsphelper64`, `Discord`, `steamwebhelper`. **Next actions:** (a) decisive cheap test —
      disable the NVIDIA in-game overlay ONLY, keep playing, one variable; (b) play under the
      watchdog for dump #2 with markers; (c) friend re-collects with the new zip so we get their
      overlay list. Suspects, ranked: (1) NVIDIA overlay/GL hook, (2) engine WndProc work
      (card-screen pause path included), (3) accessibility `WM_GETOBJECT`, (4) move-size loop
- [ ] **Review Split Shot vs Scatter as CONTENT.** They are the same card: both `PROJECTILE_COUNT`
      at magnitude 1.0 with byte-identical description text, differing only in rarity (Rare vs
      Uncommon), `max_stacks` (3 vs 2) and weight. `UpgradePool` now refuses to put two
      same-reading cards in one hand, but that is a guard over the symptom — one of these two should
      be re-specced or cut
- [x] README with a GIF (2026-08-03) — `tools/share/bestagon.gif`, sliced out of a contact sheet
      captured from a real run at 4:16 / level 43
- [x] Web + Windows exports (2026-08-03) — 13.6 MB / 40.1 MB, both verified to contain no
      `node_modules`, `strudel`, `tests` or `scenes/dev`, and no stale files (`package.ps1` now
      cleans `builds/` first, after the release zip shipped a deleted playtest note)
- [x] Cover image (2026-08-03) — `tools/share/cover.png`, 630×500. Recropped once: the first
      version had the developer's own save records in it
- [ ] itch.io page: HTML, browser-playable, 1280×720 embed, cover image uploaded, **flip Restricted → Public**
- [ ] butler push
- [ ] **Postmortem in hub** + knowledge notes + pattern-candidate review

**Pre-upload review, 2026-08-03.** Gate + soak green (126 tests, both boss events, victory 5:39).
No secrets, no credentials, no leaked page password. Three defects found and fixed in the pass:
the gate was banking bot runs into the real save profile (`--dev-noprofile`), every silent level-up
toast reported **`+0.0% FIRE RATE`** because the drip was snapshotted after the level increment, and
`builds/` was never cleaned so deleted files shipped. **Accepted, not fixed:** existing players lose
their records to the `.cfg` → `.json` save change — a deliberate call, the page is restricted and the
one known profile was bot-contaminated anyway.

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
- [x] **v1.1 M7** The playtest rework (2026-08-02) — instrument fixed, cards gate to every 3rd
      level with a measured drip, weapons drafted, NOGAXEH v2 + true ending, card iconography,
      THE LATTICE. **Tuning awaits a human run (7.9).**
- [x] **v1.1 M7.9** First external playtest (2026-08-03) — game published to itch.io as a restricted
      page and played by someone who did not build it. Six defects found and fixed: title menu
      overflow + off-centre, `◆` tofu on web, invisible Aegis, silent level-ups, ESC dead in
      fullscreen, bosses too small / enemies latching on. Packaging turned into a script
      (`tools/package.ps1`) after being done by hand wrong twice. **Tuning numbers still owed** —
      recorded in M8 below.
- [x] **v1.1 M7.95** Second playtest response (2026-08-03) — seven items from the same tester, all
      shipped: enemies and projectiles made readable (baked neon halos; bolts glow AND streak,
      bodies do neither; the Dart stopped rotating along travel), screenshake cut a third at the
      ceiling with a tighter per-frame kill cap and a **SHAKE toggle** in the pause menu, Siphon
      14%→6% with the lifesteal cap 0.6→0.25, Ricochet bounces now carry only the damage the last
      target could not absorb, Prism HP 1200→2400, and the victory screen rebuilt as a scoreboard
      with unlock chips. Two things fell out of it that nobody asked for: the gameplay screenshot
      rig had been photographing the **pause menu** since focus-pause shipped, and
      `pause_layout_check` guarded five screens while never guarding this one.
- [x] **Licence chosen (2026-08-03) — MIT.** `LICENSE` at the root, `assets/ATTRIBUTION.md`
      rewritten to match: both generators named, and why the audio renderer is *resolved* rather
      than vendored (it imports AGPL-3.0 packages; Godot only plays the `.ogg` files and never
      links any of it, so the stems stay original works under MIT).
- [ ] v1.1: **M8 ship** ← next. Remaining: tune the 5:00→10:00 ramp and the 10:00 fight length
      against a real run, settle the freeze question, flip the itch page Public.
      **Two numbers are owed a soak rather than an opinion:** the 10:00 mirror event inherited the
      Prism doubling and is now 18,400 base (was 11,200, last measured at 212 s for a four-weapon
      run), and `MIRROR_LEVEL_STEP` was fitted against the old base and never re-fitted.

*The ship gate moved from M7 to M8 because the first clean human run to 10:00 turned into a rework
spec rather than a punch list. Scope grew by explicit decision, not by drift.*

*Checkboxes are updated at session end. A milestone list that lies is worse than none.*
