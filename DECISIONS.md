# Decisions & deviations — 01-survivor

Per-game log. One line per departure from the plan, with the reason. Distinct from the hub's
`decisions.md`, which holds foundational cross-game decisions (D1–D16).

Format: `YYYY-MM-DD — did X instead of Y, because Z.`

Created 2026-08-02, retroactively seeded with deviations that had already occurred. Everything below
this line was reconstructed from git history and the hub; from here on, entries are written as they
happen.

---

- **2026-08-01 — Generated assets instead of CC0 asset packs.** D7 planned Kenney/itch CC0 packs for
  v1. Shipped instead with a committed deterministic generator (`tools/gen_assets.py`: PIL sprites +
  stdlib-synthesized WAVs). Same goal of near-zero art time, zero licensing surface. Recorded at the
  time by amending hub D7; the third-party-pack import workflow moves to v2. *Note: `TODO.md` M6
  still describes swapping placeholders for CC0 packs — stale, superseded by this entry.*

- **2026-08-01 — M4 upgrade system was built by Claude despite being declared HUMAN-BUILT.**
  `TODO.md` declared the upgrade system (UpgradeResource + weighted pool + apply-to-stats) as the
  human's challenge system, marked PROPOSED and awaiting confirmation. It was never confirmed, and
  hub D14 ("build → assess → teach") superseded D4's challenge-system model mid-project, so Claude
  built it in commit `214506b`. Net effect: **this game contains zero human-built systems**, and
  D14's promised mock teaching project does not exist yet. The TODO.md checkbox is stale.

- **2026-08-01 — Object pooling deliberately skipped.** Four runtime spawn sites (enemies,
  projectiles, XP gems, death bursts) share an identical shape, which superficially clears a
  rule-of-two bar. Skipped anyway, pre-committed in `TODO.md`: pattern candidate only if profiling
  demands it. *Re-validated 2026-08-02 by audit — peak churn is ~39 nodes/sec created and freed,
  which is nothing; the real risk is unbounded live counts, which a pool does not fix. See
  `hub/knowledge/performance-2d-web.md`.*

- **2026-08-02 — v1.1 is a continuation, not a new game.** The postmortem gate is measured at v1.1's
  ship rather than before v1.1's work, so that the postmortem is written about a game people have
  actually played. Recorded as hub D15. D6 still binds: v1.1 is what reaches itch.io.

- **2026-08-02 — Enemy cap is a safety bound, not a difficulty lever.** `Difficulty.MAX_ALIVE = 110`,
  enforced by a pure `should_spawn()` so boundedness is unit-testable rather than only observable by
  playing for ten minutes. Pressure still comes from `spawn_interval` and `hp_mult`. At the cap the
  spawner burns its cooldown instead of queueing a backlog to dump later.

- **2026-08-02 — Uncollected XP gems home to the player instead of expiring.** Bounding gem lifetime
  was required; expiry was rejected because losing XP to a timer reads as a bug to the player. After
  `IDLE_TIMEOUT` a gem gives up and flies home, so every gem is eventually collected and the live set
  is bounded by spawn rate × (timeout + travel). The magnet upgrade still buys *immediacy*, which is
  what actually made it feel good.

- **2026-08-02 — Dev flags added (`--dev-godmode`, `--dev-stats`, `--dev-autopick`).** Not planned,
  but the M0 gate requires a 10-minute soak and that is impossible headless: the player dies in
  ~2 minutes, and the level-up panel pauses the tree forever with no input to dismiss it. Read from
  user args after a bare `--`, same convention as `ai_screenshot.gd`; inert in normal play. Expected
  to earn their keep balancing the Run Director and the boss in M2.

- **2026-08-02 — HP-scaling and XP-rounding math extracted to pure functions.** `EnemyStats.
  effective_hp()` and `Progression.xp_gain()` were inline expressions in `Enemy.setup` and
  `Main._on_gem_collected`. Moved out so they are testable without instancing a scene (hub D12).
  Both floor at 1: a 0-HP enemy is unkillable because `take_hit` early-returns on `hp <= 0`, and a
  0-XP gem reads as a bug.

- **2026-08-02 — Boss extends Enemy rather than resembling one.** The Prism was first written as a
  standalone `CharacterBody2D` with a matching signature. It shipped for one build in which the boss
  spawned on time and **could not be killed or even targeted**: both `Weapon._nearest_enemy()` and
  `Projectile._on_body_entered()` cast to `Enemy`, so a lookalike is invisible to the entire combat
  system. Making `Boss extends Enemy` (with its own `prism.tres` EnemyStats) removed every special
  case in weapon, projectile, Main, the kill counter and the death burst. *Lesson: when several
  systems gate on `is SomeType`, "same signature" is not the same as "same type".*

- **2026-08-02 — All ring placement goes through `Spawner.ring_position()`.** The director placed
  bosses on the spawn ring with its own maths and no arena clamp. At angle −90° that put the boss at
  y = −20, outside the top wall, where it stuck against the collision shape ~380 px from the player —
  permanently outside the weapon's 260 px range, which is why the "unkillable boss" looked like a
  damage bug for two soak runs. The clamp existed in `Spawner.spawn()` all along; the fix was to stop
  duplicating placement and expose it.

- **2026-08-02 — Spawner is mechanism, Run Director is policy.** The spawner used to own its own
  cadence and pick enemy types from `Difficulty.fast_ratio`. It now only places one enemy on the
  ring; *what* spawns, *how often*, elite promotion and boss scheduling are the director's, read
  from `RunSchedule` / `WaveResource` `.tres`. Retuning the run's shape is now a data edit.

- **2026-08-02 — One RNG for the whole run.** Upgrade draws, enemy-type selection and spawn placement
  now share `Main.run_rng`. Costs nothing today and is most of what M3's seeded-runs requirement
  needs.

- **2026-08-02 — Wave `.tres` files are engine-generated (`tools/gen_waves.gd`).** Hand-writing a
  typed `Array[EnemyStats]` into `.tres` text is guesswork; letting `ResourceSaver` serialize
  guarantees a format Godot reads back. The output is ordinary editable data — a bootstrap, not a
  pipeline.

- **2026-08-02 — `--dev-autocontinue` added.** The victory screen waits on a button, which stalls a
  headless soak at exactly the moment endless begins — the part most needing soak coverage.

- **2026-08-02 — Saves use ConfigFile, not a `.tres`.** The project convention is "game data is
  Resources, never dictionaries", which governs CONTENT we author. A save file is *user-writable*,
  and `load()`ing a Resource from a user-writable path instantiates whatever script the file names.
  ConfigFile is typed, human-readable, and cannot execute anything. `MetaState.from_config` is also
  deliberately tolerant: any missing or wrong-typed key falls back to its default, because a corrupt
  save costs progress but a crash on boot costs the whole game.

- **2026-08-02 — Values cross the run/meta boundary, never objects.** `RunState.to_result()` returns
  a flat Dictionary and `MetaState.absorb()` takes one. The invariant "run state and meta state never
  share a reference" is then structural rather than a rule to remember, and it is tested directly:
  mutating a RunState after absorbing it must not move the saved record.

- **2026-08-02 — A banked victory is recorded once; endless afterwards only improves records.**
  Victory calls `Meta.absorb_run` immediately (the BRIEF promise that rewards bank before the
  Continue choice). If the player then dies in endless, `Meta.update_records` improves best time and
  best kills without incrementing the run tally. Totals stay as of the banking point — a deliberate
  simplification over delta-tracking.

- **2026-08-02 — Unlocks are milestones, not a shop.** Beating the Prism unlocks the Orbital weapon
  (M4), so a first victory hands over a new way to play rather than a currency balance. Unlock ids
  are StringNames referenced by content, so reordering or removing one cannot silently shift another.

## Known-open at time of writing (2026-08-02)

**All five resolved in M0 (commit `0b3cdf3`).** Kept for the record:

1. `scenes/player/player.tscn` — `resource_local_to_scene = true` on the Stats sub-resource. Fixed in
   the working tree, **never committed**. The session ended between capturing the lesson in
   `hub/knowledge/resources-as-data.md` and committing the fix.
2. `scenes/enemies/enemy.tscn` — the same bug class, unfixed: the `RectangleShape2D` is not
   `resource_local_to_scene`, but `enemy.gd` mutates its size per enemy type in `_ready()`. All live
   enemies share one collision rect, so whichever type spawned most recently resizes every other
   enemy's hitbox. Visible once fast enemies enter (~t=120s): chaser 12×12 vs fast 8×8. Found
   independently by two separate audits.
3. `scenes/main/main.gd` — `_on_upgrade_chosen` recurses into `_check_level_up()` for banked XP but
   never pushes to the HUD afterward, so chained level-ups leave the XP bar and level label stale
   until the next gem.
4. No live-enemy cap and no XP-gem despawn — the two unbounded-growth risks identified by the
   2026-08-02 performance audit.
5. `tests/unit/test_damage.gd` is named as an acceptance criterion in `TODO.md` M3 but was never
   created.
