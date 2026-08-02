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
