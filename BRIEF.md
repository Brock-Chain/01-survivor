# BRIEF — 01-survivor v1.1

Written 2026-08-02 from a grilling session. Template: `hub/pipeline/game-brief.md`.
v1.1 is a **continuation** of v1, not a new game (hub D15). Deviations go in `DECISIONS.md`.

---

## 1. Prime directive

> **Someone clicks this on itch.io, plays one five-minute run, and immediately clicks restart.**

Tiebreak rider: when gameplay and presentation compete for the same hour, **gameplay wins** — but
nothing ships rough. A rough menu is still a defect; it just loses to a gameplay fix when only one
can happen.

Test for any proposed change: *does this make the restart click more likely?* If the honest answer
is "no, but it's nice", it goes to the backlog.

## 2. Defect definition

These are defects, **not stepping stones**. "I'll polish it later" is not available for anything on
this list:

1. Floaty or unresponsive movement — input that doesn't register within a frame.
2. A hit with no visible **and** audible response.
3. An enemy that dies without weight.
4. A run that ends without the player understanding why they lost.
5. Music that grates by the third listen. The directive puts the player through this loop five times.
6. Default-theme UI, unstyled controls, or any element that reads as placeholder.
7. A frame hitch the player can feel.
8. Anything that reads as **generated rather than designed**. Assets are procedural by choice; that
   must never be visible as an excuse.

## 3. Authority to deviate

If a requirement in this brief conflicts with the prime directive, **break the requirement** and
record it in `DECISIONS.md` with a one-line rationale. Scope cuts, technique swaps and feature drops
are all in scope. A brief that survives contact unchanged wasn't being used.

## 4. Constraints

| | |
|---|---|
| Engine / language | Godot 4.7.1 stable, GDScript, static typing always |
| Renderer | GL Compatibility (required for web export) |
| Resolution | 640×360 viewport, 1280×720 window, nearest-neighbour filtering |
| Targets | Web + Windows, published to itch.io |
| Release | **One public release, at the end.** Export path exercised early as a gate (see M0) |
| Assets | 100% self-produced: sprites from `tools/gen_assets.py`, audio rendered from Strudel. No third-party art or audio, no licensing surface |
| Architecture | Data as Resources (`.tres`), never dicts/JSON. Call down, signal up. Scene-adjacent scripts |
| Out of scope | Multiplayer, mobile/touch, controller remapping, localisation, achievements, cloud saves |

## 5. Art & audio direction

**Solid neon on deep dark, synthwave.** Filled saturated geometry with a **baked glow halo** —
the halo is drawn into the texture by the generator, so it needs no engine glow post-process and
cannot break on a single-threaded web export.

- Filled shapes, never wireframe: at 12 px a 1 px outline shimmers and turns to mush in a crowd.
- Bosses are large multi-part geometric composites — the one place detail is affordable.
- Music is synthwave, which is Strudel's native vocabulary: sawtooth leads, square bass, driving
  drums. Composition is a `stack()` of layers, so intensity stems are nearly free.

### The colour law

Hue encodes **allegiance**, silhouette encodes **type**. One glance must answer "can this hurt me?"
before the player has parsed what it is — that matters far more than telling two enemy types apart,
because there will be dozens on screen.

| Role | Colour |
|---|---|
| Player, player projectiles, orbitals | **Cyan** → white-hot core |
| Anything that can damage you | **Magenta → violet → orange** band |
| Enemy projectiles | **Hot yellow** (reserved; nothing friendly is ever yellow) |
| XP gems, pickups | **Green-cyan**, pulsing |
| Boss | Full spectrum — it is allowed to break the law, that is what makes it read as a boss |
| Arena floor / grid | Near-black indigo, low contrast, never competes |

Enemy archetypes are distinguished **primarily by silhouette**, and only secondarily by their
position within the danger band.

## 6. Systems

Three new systems, each gets a contract (`hub/pipeline/system-contract.md`) written before code.

**A · Run & Meta State** — the run seed, strict separation of run state from meta state, save/load,
and persistent unlocks. Invariant that matters most: run state and meta state never share a
reference. This is v2's hardest plumbing, learned here.

**B · Run Director** — wave definitions as data, elite injection rules, a boss at ~5:00, and an
actual **win condition**. Also publishes a run-intensity signal. This is the system the prime
directive demands: the game currently has no run structure and no ending, so "one five-minute run"
is not something it can do yet.

**C · Weapons as data** — `WeaponResource`, a second weapon type, and upgrades that target a
specific weapon rather than a global stat block.

**Audio layer** — *not* a fourth system. It subscribes to the Run Director's intensity signal and
crossfades stems. Deliberately a consumer of existing state.

Content that proves the systems: **5 enemy archetypes**, an elite modifier, and one boss.

### Run structure

| Time | Event |
|---|---|
| 0:00–5:00 | Escalating waves. Elites begin appearing partway through |
| ~5:00 | **The Prism** — boss. Defeating it is a **win**, distinct from death |
| On victory | Rewards **bank immediately**. Player chooses *Restart* or *Continue (Endless)* |
| 5:00+ | Endless. Curve keeps climbing |
| ~10:00 | **Two Prisms** at reduced HP each — a positioning problem, not an HP slog |
| Every +5:00 | One more boss, capped at 3 concurrent |

Banking the reward at the moment of victory is deliberate: endless becomes pure upside, so trying it
carries no anxiety, and a player who dies at 8:00 still finished a run they won.

**This also resolves the audit's difficulty finding.** The curve currently outruns achievable DPS,
which was a defect when the game was endless-only. With a boss at 5:00 it becomes correct: the first
five minutes must be winnable and tense, and the curve outrunning the player *after* that is exactly
what should end an endless run.

### The Prism (boss)

A large hexagonal core orbited by three shards. Every attack is **telegraphed** — shards brighten
and a cue sounds before anything fires. Untelegraphed damage violates defect #4.

- **Phase 1 (>50% HP):** shards orbit; radial spreads of slow yellow bolts with weavable gaps. Core
  drifts toward the player.
- **Phase 2 (≤50%):** shards detach into aggressive Darts that respawn over time; the core dashes on
  a telegraph, and spreads fire more often with tighter gaps.

Two phases, not three — deliberately scoped so the boss ships finished rather than ambitious.

### Enemy archetypes

Each exists to change *what the player does*, not to be a different number.

| Name | Silhouette | Pressure it applies |
|---|---|---|
| **Drifter** | Hexagon | Baseline mass. The crowd you swim through |
| **Dart** | Triangle | Speed. Punishes standing still |
| **Bulwark** | Octagon, thick | HP wall. Blocks lanes, soaks DPS, rewards piercing |
| **Splitter** | Diamond | Splits into two Darts on death. Punishes careless clearing |
| **Lancer** | Chevron | **Ranged.** Punishes camping and pure kiting |

The Lancer earns its complexity — it needs an enemy projectile and a new collision layer, but
without a ranged threat the optimal strategy is always "run away" and positioning stops mattering.

**Elite** is a modifier applied by the Run Director, not an archetype: any type can spawn elite with
a brighter rim, more HP, more damage and more XP.

### The second weapon: Orbitals

Cyan shards orbiting the player, damaging on contact. Chosen over a melee arc or a chain-lightning
weapon for three reasons: it needs no facing direction (the player has none — movement is 8-way and
the existing weapon auto-aims), it stays readable at small sizes where a thin chain-lightning bolt
would not, and its upgrade axes — count, radius, rotation speed — barely overlap with the
projectile weapon's damage / fire-rate / multishot. Two weapons whose builds diverge is what
actually tests whether Weapons-as-data works.

## 7. Milestones and gates

| | Milestone | Gate |
|---|---|---|
| **M0** | Fix pass — the 5 open findings in `DECISIONS.md` + `test_damage.gd` | GUT suite green, headless smoke free of `SCRIPT ERROR`, a 10-minute run shows **bounded** entity counts — **and a Windows build plus a locally-served web build both produced successfully.** Publishing waits for M7; proving the pipeline does not |
| **M1** | Visual identity — regenerate all sprites in the neon geometric style | **HARD GATE: a static screenshot with the HUD hidden already looks designed, not generated.** Do not start M2 until this is true |
| **M2** | Run Director — waves as data, elites, boss, win/endless | A full five-minute run reaches the boss and can be **won**; victory banks and offers Restart or Continue; endless reaches the double-boss; losing is legible |
| **M3** | Run & Meta State — seed, save/load, unlocks | Quit mid-run and relaunch: unlocks persist, run state does not. Round-trip covered by tests |
| **M4** | Weapons as data + second weapon type | Both weapons read as distinct in a 30-second clip |
| **M5** | Enemy archetypes — 5–6 types, elites, boss composite | Each type identifiable by silhouette and colour alone at 12 px, in a crowd |
| **M6** | Audio — adaptive stems, 4 tracks, full SFX pass | Five consecutive runs without the music grating; every action has a sound |
| **M7** | Ship — README, exports, itch.io page | A stranger plays it in their browser at an itch.io URL |

M1 is the hard gate on purpose. It is the cheapest milestone to under-deliver on and the one the
prime directive is most sensitive to, because the screenshot is what earns the click that precedes
the five minutes.

## 8. Acceptance criteria

Verified at the end, one at a time, against **freshly produced** artifacts — not from memory.

1. Every hit produces a flash, a sound, and camera trauma within one frame of contact.
2. A five-minute run reaches a boss; the boss can be defeated; victory is distinct from death.
3. On death or victory the player can tell why, without narration.
3a. Every boss attack is telegraphed before it can deal damage.
3b. Victory banks its reward immediately, then offers Restart or Continue; dying in endless never
    revokes a banked win.
4. Unlocks survive quitting and relaunching. Run state does not leak across runs.
5. The same seed reproduces the same run.
6. Entity count is bounded over a 10-minute run — no unbounded enemies, no immortal gems.
7. Each enemy archetype is identifiable by silhouette and colour alone at 12 px.
8. Both weapon types are distinguishable by feel, not just by numbers.
9. Music layers escalate with run intensity; no audible seam at a loop point or a layer change.
10. Every player action and every significant event has a sound.
11. No visible frame hitch on first enemy draw, first kill, first level-up, first boss spawn.
12. No screen contains a default-theme control or an unstyled element.
13. A static screenshot with the HUD hidden reads as designed.
14. GUT suite green; headless smoke run free of `SCRIPT ERROR` and `ERROR`.

## 9. Verification method

| Failure class | Caught by |
|---|---|
| Damage math, upgrades, save round-trips, seeded runs, director schedules | GUT unit tests |
| Feel, timing, layout, visual identity | `tools/ai_screenshot.gd` + `--write-movie` clips |
| Runtime errors | Headless smoke run, grep stdout for `SCRIPT ERROR` / `ERROR` |
| Unbounded growth, hitching | Long run with entity counts logged |
| Audio | Render, listen, and re-render — the ear is the judge |

**Not** adopted: "build, don't test-loop." Correct for a graphics demo whose correctness is visual;
wrong here, where a new upgrade can silently break three others (hub D12).

## 10. Deviation log

`DECISIONS.md`. One line per departure, written as it happens.
