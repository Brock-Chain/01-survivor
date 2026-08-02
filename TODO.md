# 01-survivor — TODO

**v1.1 in progress.** [BRIEF.md](BRIEF.md) is the spec — prime directive, defect definition, gates
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

- [ ] Commit the pending `player.tscn` `resource_local_to_scene` fix
- [ ] `enemy.tscn` — `resource_local_to_scene` on the RectangleShape2D (shared-hitbox bug)
- [ ] `main.gd` — push HUD state after chained level-ups
- [ ] `spawner.gd` — cap live enemies
- [ ] `xp_gem.gd` — bound gem lifetime
- [ ] `tests/unit/test_damage.gd` — the acceptance criterion v1 named but never wrote
- [ ] Audit sweep: every `.tscn` sub-resource that gets mutated at runtime is `resource_local_to_scene`

**Gate:** GUT green · headless smoke free of `SCRIPT ERROR`/`ERROR` · a 10-minute run shows bounded
entity counts · **a Windows build and a locally-served web build both produced successfully**
(proving the export path; publishing waits for M7).

### M1 — Visual identity ⭐ HARD GATE
Regenerate every sprite in the neon-geometric style; apply the colour law from BRIEF §5.

- [ ] Rewrite `tools/gen_assets.py` sprite generation: filled geometry + baked glow halo
- [ ] Player, projectile, orbital, 5 enemy silhouettes, gem, boss parts
- [ ] Arena floor / grid, background
- [ ] Retune the hit-flash shader for the neon palette

**HARD GATE:** a static screenshot with the HUD hidden already reads as *designed, not generated*.
**Do not start M2 until this is true.**

### M2 — Run Director
Waves as data, elites, boss, win condition, endless.

- [ ] `WaveResource` / director schedule as `.tres`
- [ ] Elite modifier (rim, HP, damage, XP)
- [ ] The Prism — 2 phases, every attack telegraphed
- [ ] Enemy projectiles + collision layer
- [ ] Victory state, reward banking, Restart / Continue choice
- [ ] Endless: double boss at ~10:00, +1 boss per 5:00, cap 3
- [ ] Rebalance 0:00–5:00 to be winnable and tense
- [ ] Run-intensity signal published for the audio layer

**Gate:** a full run reaches the boss and can be won · victory banks and offers Restart/Continue ·
endless reaches the double-boss · losing is legible.

### M3 — Run & Meta State
- [ ] System contract first
- [ ] Run seed; same seed reproduces the same run
- [ ] Strict run-state / meta-state separation (never share a reference)
- [ ] Save/load, unlocks
- [ ] Round-trip tests

**Gate:** quit mid-run, relaunch — unlocks persist, run state does not.

### M4 — Weapons as data
- [ ] System contract first
- [ ] `WeaponResource`; port the existing projectile weapon onto it
- [ ] Orbitals — the second weapon
- [ ] Upgrades retargeted at specific weapons

**Gate:** both weapons read as distinct in a 30-second clip.

### M5 — Enemy archetypes
- [ ] Drifter, Dart, Bulwark, Splitter, Lancer
- [ ] Splitter death payload; Lancer ranged attack
- [ ] Elite variants of each

**Gate:** each type identifiable by silhouette and colour alone at 12 px, in a crowd.

### M6 — Audio
- [ ] Compose in Strudel: title, gameplay (as intensity stems), boss, victory
- [ ] Render → tail-fold → OGG pipeline as a committed tool
- [ ] Stem crossfade driven by the Run Director's intensity signal
- [ ] Full SFX pass, replacing the generated WAVs
- [ ] Volume / mute options

**Gate:** five consecutive runs without the music grating · every action has a sound · no audible
seam at a loop point or layer change.

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
- [ ] v1.1: **M0** · M1 · M2 · M3 · M4 · M5 · M6 · M7

*Checkboxes are updated at session end. A milestone list that lies is worse than none.*
