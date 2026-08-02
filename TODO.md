# 01-survivor — TODO

Micro arena survivor. Ship target: **2026-08-14** (web + Windows on itch.io, public GitHub repo). Budget ≈ 20h. Scope control: content counts are fixed — more polish beats more features.

## Challenge systems (HUMAN-BUILT)
- [ ] **M4 upgrade system** (PROPOSED, awaiting confirmation): `UpgradeResource` + weighted pool + apply-to-stats. Claude designs the interfaces and reviews; human implements.

## Milestones

### M1 — Player (~2h)
Input map (WASD+arrows) → `CharacterBody2D` + `move_and_slide()`, normalized diagonals → `Camera2D` with limits + smoothing → arena bounds (StaticBody2D walls) → placeholder sprite with flip.
**Teaches:** scene/node thinking, input actions, `_physics_process`, body types, camera.
**Done when:** sprite moves at constant speed in 8 directions, can't leave arena, camera follows. Screenshot verified.

### M2 — Enemies & damage (~3h)
Enemy scene (chase = `(player.pos - pos).normalized()`) → Timer-driven spawner placing enemies on an off-screen ring → contact damage via hurtbox `Area2D` + i-frames (0.5s) → player HP, death signal up to Main.
**Teaches:** runtime instancing, signals vs direct calls, groups, Timers, Area vs Body, collision layers/masks (set up ALL layers here: player, enemies, player_hurtbox, pickups, projectiles).
**Done when:** enemies stream in, chase, hurt on contact with i-frame flicker; player can die. `tests/unit/test_health.gd` green (clamping, i-frame window math).

### M3 — Combat & XP (~3.5h)
Auto-firing weapon targeting nearest enemy (projectile scene, lifetime-capped) → enemy HP/death → XP gem drop (`Area2D`) → magnet radius on player, tween-pulled pickup → kill/XP counters.
**Teaches:** nearest-target queries, projectile pattern, collision filtering in anger, tweens, object lifecycle (`queue_free` discipline).
**Done when:** enemies die to bullets, gems fly to player when close, XP accumulates. `test_damage.gd` green (damage application, XP values). *(Object pooling deliberately skipped — pattern candidate only if profiling ever demands it.)*

### M4 — Progression: pick-1-of-3 upgrades (~4h) ⭐ THE V3 REHEARSAL
XP curve → level-up pauses tree (`process_mode` discipline) → UI: 3 upgrade cards → picking applies effect, unpauses.
Data-driven core: `UpgradeResource` (.tres per upgrade: id, name, description, icon, effect enum, magnitude, max stacks, weight) + `UpgradePool` (weighted draw of 3 distinct eligible options) + a stats layer upgrades mutate (move speed, damage, fire rate, magnet radius, max HP…). ~8-10 upgrade .tres files.
**Teaches:** custom Resources as content (THE deckbuilder skill), pause/process modes, Control-node UI + containers, seeded RNG.
**Done when:** leveling reliably offers 3 valid choices and picks change gameplay measurably. `test_upgrade_pool.gd` green (no duplicate offers, ineligible excluded, stack caps respected, seeded draws reproducible).

### M5 — Game loop & difficulty (~2.5h)
HUD (`CanvasLayer`): HP bar, XP bar, level, survival timer, kill count → game-over screen (stats + restart via scene reload) → difficulty ramp: spawn interval and enemy HP scale with time (single tunable curve/function) → second enemy type (fast/weak) enters at minute 2.
**Teaches:** UI anchoring/containers for real, scene transitions, balancing knobs as data not constants.
**Done when:** full loop — play, die, see stats, restart — with rising pressure. `test_difficulty.gd` green (curve values at t=0/2/5min).

### M6 — Juice & assets (~3h)
Swap placeholders for CC0 packs (Kenney or itch; consistent 16px-ish set) → SFX: hit, pickup, level-up, death + music loop (audio buses: Master/SFX/Music) → hit flash (modulate), death burst (CPUParticles2D), screenshake (trauma-based), gem sparkle → **click-to-start title screen** (required for web audio anyway) → `assets/ATTRIBUTION.md`.
**Teaches:** audio buses, particles, tween-driven feel, why juice ≠ content.
**Done when:** it *feels* like a game in a 30s clip (`--write-movie` verified).

### M7 — Ship (~2.5h)
Full playtest pass (human) → README with GIF for the repo → web + Windows exports (presets exist, GUT excluded) → itch.io page: Kind=HTML, browser-playable, embed 1280×720, cover image → butler push → **postmortem in hub + knowledge notes + pattern candidates review**.
**Teaches:** the actual point of v1 — finishing.
**Done when:** a stranger plays it in their browser at an itch.io URL. No postmortem → no game 2.

## Milestone log
- [x] M0 Skeleton (2026-08-01): boots headless, GUT 9.7.1 green, exports verified end to end
- [ ] M1 · [ ] M2 · [ ] M3 · [ ] M4 · [ ] M5 · [ ] M6 · [ ] M7
