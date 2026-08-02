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

## Playtest response — 2026-08-02 (first human playtest)

- **Healing removed as a level-up reward.** "Getting a heal as a level reward option while at full
  health seems like poor game design" — correct, a reward you cannot use is a punished level-up.
  `bandage` is out of the pool. Health is now a **world drop** (`HealthPickup`, ~4.5% per kill and
  *only while hurt*), which is never wasted and makes you move to collect it — pressure the game was
  missing. `Siphon` covers players who want to build into sustain.

- **The upgrade pool could run dry — a real bug, not just a balance miss.** 10 upgrades × 5 stacks
  meant that by level 37 everything was maxed and the only legal draw left was the heal (screenshot
  evidence). `max_stacks <= 0` now means UNLIMITED, and three unlimited upgrades (Overdrive,
  Momentum, Cadence) guarantee there is always an offer. This is also most of why endless "felt
  pointless": there was no progression left to earn.

- **Difficulty: the soak was the wrong instrument.** The god-mode soak reported "enemies bounded
  8–14" and that was read as healthy; it actually meant the kill rate was crushing the spawn rate
  with 110 slots free. Spawn intervals roughly halved across every wave. Living enemies now rise
  through a run (38 → 54 → 59 → 63 by 5:00) instead of collapsing (31 → 27 → 15 → 7).

- **The Lancer was pulled forward from M5.** "I could just stay still and beat all enemies without
  getting hit" has one real cause: every enemy walked into the auto-weapon, so holding position was
  strictly optimal. A RANGED archetype that holds distance and shoots is the fix; more of the same
  chasers would not have been. `EnemyStats.Behavior` + `EnemyStats.sprite` make archetypes pure data.

- **Boss: 2 at 5:00, 4 at 10:00, cap 6.** "The 2 bosses on min 10 with the damage I had there maxed
  out... was okay for a 1st boss fight." So the first fight is two Prisms tuned for a *five*-minute
  player (300 HP each) rather than one for a maxed one, and later events scale. When distinct boss
  types exist, later events should swap in new ones rather than stacking more Prisms.

- **Boss fires far more, and never in the same place twice.** Spread 10→15 (phase 1) and 14→22
  (phase 2), intervals 3.1→1.75 and 2.1→1.15, and the ring rotates by half a step each volley so a
  single safe lane stops working. Bolts are 50% larger, hotter, and now face their travel direction.

- **Telemetry added.** Answering "what do players pick / is the start too easy" from memory is
  guessing. `Telemetry` autoload writes JSONL to `user://telemetry/`; `tools/analyze_telemetry.py`
  reports pick rate **as a fraction of times offered** (a raw count just says which upgrades are
  common), time-to-first-damage, HP and enemy-count per 30s bucket, boss fight length, and damage by
  source. Local only, nothing transmitted, off on web where `user://` is unreadable.

- **`_attack_cd` name collision.** `Enemy` gained a shoot timer with the same name as one `Boss`
  already had, which GDScript rejects as shadowing. Unit tests did NOT catch it — they only load pure
  logic. The headless smoke run did. Worth remembering: a parse error in a scene script is invisible
  to the unit suite.

## Telemetry-driven balance pass — 2026-08-02

First analysis of real playtest data (`tools/analyze_telemetry.py`), and it disagreed with the soak
on almost everything.

- **Still far too easy.** HP never dropped below 72% and sat at 89–100% for most of the run; 13
  damage taken all game. Living enemies were 6–22 where the god-mode bot saw 38–63 — a competent
  human clears much faster than the bot, which is precisely why soak numbers cannot set difficulty.
  Spawn intervals cut again, enemy speeds up, Lancer weight up sharply.

- **Lancers are the efficient threat.** Bolts were 38% of all damage taken despite Lancers being a
  minority of spawns. Ranged pressure lands where chasers do not, so their share went up rather than
  adding more chasers.

- **Boss HP 300 → 900 each.** Two Prisms at 600 total died in 11 seconds.

- **Three of the four dead-weight upgrades are a difficulty symptom, not a design fault.**
  `tough_hide` 0/18, `siphon` 1/12, `magnetism` 3/18 — defensive and sustain picks are worthless when
  nothing threatens you. Their magnitudes were deliberately NOT buffed; only their draw weights were
  lowered so they stop crowding offers. Re-measure after the difficulty change before touching them.
  `momentum` (0/9) is the real design fault — +4% move speed is strictly worse than `swift_boots`'
  +12%, so it was pure redundancy. Raised to +7%.

- **Enemy bolts were counted as living enemies.** `Enemy._act_ranged` parented bolts via
  `get_parent()`, and a Lancer's parent is the Enemies container — so every bolt in flight consumed a
  slot against `MAX_ALIVE` and inflated the enemy stat. Bolts now live in their own `EnemyBolts`
  container, injected rather than inferred. Found only by reading the numbers, not the code.

- **Resources must not reach for autoloads.** `WeaponResource.is_available()` and
  `UpgradeResource.is_eligible()` initially called the `Meta` singleton. That fails to compile
  outside a running game (the weapon-authoring tool script died on `Identifier not found: Meta`) and,
  worse, would have made upgrade-pool unit tests depend on the player's real save file. Unlocks now
  cross as a value — the same rule already established for RunState/MetaState.

## V1.Final scope + rarity — 2026-08-02

- **This version is V1.Final, shipping as "PRISM".** The name was already inside the game — the boss
  is The Prism, its lesser form is the Shard, and the whole visual identity is light, geometry and
  separated colour, which is literally the colour law. Named things that come from the work read as
  earned rather than applied. Cycle: M6 → M6.5 → grill → one apply pass → M7 → hub capture → V2.

- **Rarity replaced "make levels expensive" as the fix for dead upgrades.** The measured problem was
  57 levels in six minutes, so a pick cost nothing and a weak upgrade was noise rather than a
  rejection. Making levels merely costlier would have fixed the symptom; rarity fixes the cause,
  because a *Common* that is weak is correct rather than disappointing. XP is still ~30% steeper to
  support it.

- **Rarity rolls per CARD, not per level-up.** A screen reading Common/Common/Epic is what makes the
  Epic land; if every card were Legendary none of them would be. Odds improve with progress and
  SATURATE at level 30 so a long endless run cannot drift into all-Legendary screens.

- **The draw falls DOWN on exhaustion, never up.** Being handed a Legendary because the Commons ran
  out would make the rarest thing in the game a consolation prize.

- **A tier is a design slot, not a multiplier.** A Rare damage upgrade is its own entry with its own
  number rather than a Common one scaled up — which is what lets Legendary mean a different EFFECT
  instead of a bigger one.

- **Rarity colours live on the card frame only; the arena colour law is untouched.** The law governs
  entities, where hue must answer "can this hurt me" in a glance. A paused menu is a different
  context, and the grey/green/blue/purple/gold convention is cheaper to adopt than to retrain —
  rendered as neon LED so it belongs to this game. Border width and glow scale with tier so the
  ladder survives a screenshot; only Legendary animates, because if everything pulsed nothing would.

- **Two mechanic traps.** Prism Core and Chain Lightning spawn projectiles, so children are created
  INERT — otherwise one shot recurses into thousands. And bosses are immune to Executioner: an
  instant-kill threshold on a 900 HP boss would delete the fight the run is built around.

- **The second boss is deferred to the M6.5 apply pass**, so it can be designed with the review's
  findings in hand rather than before them.

## M6 audio + shooting variants — 2026-08-02 (second session)

- **SFX are Strudel, same renderer and seed as the music.** The 8 stdlib WAVs replaced and 11 cues
  added (19 sounds, 23 files) so the whole soundscape shares one synth palette. Vocabulary is the
  colour law's audio twin: friendly = square/triangle rising, hostile = saw/noise falling, and the
  boss telegraph is a low tritone dread-swell — it used to play the LEVEL-UP jingle, which taught
  that reward-sound precedes damage. Pitch direction was verified empirically before authoring:
  superdough's `penv(n)` OFFSETS THE START and decays to the written note, so a down-chirp needs
  penv POSITIVE — the intuitive reading is backwards.
- **Variant sets are cycles.** A pitch-varied set is `cat(v0, v1, v2)` — one variant per cycle —
  sliced at cycle boundaries by `tools/build_sfx.py`, which also measures boundary bleed, trims at
  −60 dB, and normalises per FAMILY so authored loudness differences between variants survive.
- **"N resources still in use at exit" is known-benign teardown noise.** The audio server holds
  every stream that played during the session past the leak check; `_exit_tree` nulling was tried
  and does nothing. Documented in CLAUDE.md so smoke greps exclude exactly that line and nothing else.
- **Prism Core / Chain Lightning spawned projectiles mid-physics-flush** (`add_child` inside
  `body_entered`) — 17 "Can't change this state while flushing queries" errors in a 15-minute soak.
  Pre-existing from the rarity milestone; surfaced by longer soaks. Fixed with `add_child.call_deferred`,
  the same rule every other spawn site already followed.
- **Both spare meta milestones now unlock weapons.** Scattergun (5-pellet cone, range 170 — proximity
  is the price of burst) on `elite_hunter`; Prism Lance (instant piercing line, new `Kind.BEAM`,
  no physics nodes — geometry against the enemies group) on `endless_proven`. Weapon fire cues are
  data (`WeaponResource.fire_sound`), and a crit replaces the cue rather than layering it.
- **`endless_proven` was unobtainable by the players it describes.** A winner's run is absorbed at
  the victory moment (~5:20); death-in-endless only updated records and never evaluated unlocks, so
  "survive to the double boss" could never be earned after banking a win. `update_records` now earns
  late milestones; only the run tally stays frozen. Caught because the new lance sat behind it.
- **`--dev-unlocks` added** — the only way to exercise or playtest a gated weapon without earning it.
- **Renamed to PRISM.** `user://` moved with the name; the old save + telemetry were copied to the
  new dir on this machine, and `analyze_telemetry.py` reads whichever dir exists. NOTE: dev soaks
  write the real save — records are bot-inflated (`best_kills=1047`, `elite_hunter` earned by bots).
  Flagged as an M6.5 finding (dev runs should use a separate profile).

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
