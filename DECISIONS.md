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

- **2026-08-02 — Saves are not a `.tres`.** ~~Saves use ConfigFile.~~ The project convention is
  "game data is Resources, never dictionaries", which governs CONTENT we author. A save file is
  *user-writable*, and `load()`ing a Resource from a user-writable path instantiates whatever
  script the file names. `MetaState` is also deliberately tolerant: any missing or wrong-typed key
  falls back to its default, because a corrupt save costs progress but a crash on boot costs the
  whole game.
  > **⚠ CORRECTED 2026-08-03 — the reason recorded here was false.** This entry originally
  > justified ConfigFile with "*ConfigFile is typed, human-readable, and cannot execute anything*."
  > That last clause is **wrong**, and wrong in exactly the way the decision was trying to avoid:
  > `ConfigFile` has the same code-execution surface as the `.tres` it was chosen over. Measured on
  > Godot 4.7.1 headless — `x=Object(Node,"name":"pwned")` returns a **live Node**, and
  > `x=Resource("user://evil.tres")` builds a Resource with an attacker's script attached **and
  > runs its `_init()`**, inside `load()`, before the first `get_value()` and therefore before the
  > tolerant defaulting above can intervene. The rule: **validation cannot save a parser that
  > constructs objects, because construction happens during parsing.** Superseded by the entry
  > below. Left visible rather than rewritten, because "we recorded a false reason and shipped it
  > publicly" is the part worth remembering.

- **2026-08-03 — Saves and settings are JSON, via one `UserStore`.** `user://save.cfg` →
  `save.json`, `user://settings.cfg` → `settings.json`, and every read of `user://` now goes through
  `scripts/user_store.gd`. `JSON.parse_string()` returns only Dictionary/Array/String/float/bool/
  null: its grammar has six value types and none of them is a class name, so a hostile save is not a
  dangerous value, it is a parse failure — and a parse failure is a fresh profile. The property is
  **structural**, not defensive, which is the whole reason for the swap.

  **The extension change is the migration.** An old `.cfg` is simply never read again; nothing
  converts it, because a converter would have to parse it with the very parser being retired. The
  old files are left on disk rather than deleted, so nothing is destroyed — but an existing profile's
  records, unlocks and shards do start from zero. Acceptable here: the page is restricted, and the
  one known profile already had bot-contaminated records flagged for repair.

  **Honest severity, stated so it is not overclaimed:** the attack needs bytes in the player's
  `user://`, and locally an attacker who can write there mostly owns the machine already. The
  realistic vector is a *shared save file* — "here's my save with everything unlocked" — which is
  plausible exactly because this game has unlocks worth sharing. The stronger reason to fix it was
  that the false rationale was public and would have been copied into the next project, where a run
  save (deck, position, relics) is far more likely to be passed around. Two regression tests now
  pin it: JSON ints survive narrowing, and a ConfigFile-style payload does not parse as a save.
  Full write-up: `hub/knowledge/save-files-and-trust.md`.

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

## Playtest 2 response — 2026-08-02 (during the M6.5 review)

First human run of the post-M6 build. It ended at 4:11 without reaching the boss, so
the 5:00 fight is STILL unverified — but the run itself was evidence. Telemetry
`run_035.jsonl`: 713 kills, level 30, **3 damage events in four minutes**, HP never
below 5/6. The review's "the run is never dangerous" finding, reproduced live and worse
than the pre-M6 runs it was derived from.

- **The pause screen could strand the player — two independent causes, both fixed.**
  The build grid is in a `CenterContainer`, which centres an oversized child by
  overflowing it at BOTH ends, so at 22 upgrades the Resume/Restart/Menu row was pushed
  off the bottom of the viewport. The keyboard should have saved it and could not:
  `Main` is `PROCESS_MODE_PAUSABLE`, and **a paused tree runs no input callbacks on a
  pausable node**, so every key in `Main._unhandled_input` — ESC, P, M, R — was dead the
  instant the tree paused. The panel's own Hint label advertised all four. Fixed twice
  over: the keys moved into `PausePanel` (which is `WHEN_PAUSED`), and the grid went into
  a `ScrollContainer` whose height is measured from the grid's own minimum and capped.
  *Lesson: `_unhandled_input` is gated by `process_mode` exactly like `_process` is —
  moving input out of `_physics_process` does not, on its own, make it survive a pause.*

- **That layout fix took a harness, because two reasoned guesses at it were both wrong.**
  The first attempt gave the ScrollContainer a fixed 300 px height and made the panel
  FULL-SCREEN — `ScrollContainer` defaults to `SIZE_EXPAND_FILL` on **both** axes, so it
  ate every spare pixel in the VBox. The second capped the grid at 150 px and still
  overflowed, because the budget is against the **640x360 viewport**, not the 1280x720
  window, and the non-grid overhead is ~222 px rather than the ~199 estimated by reading
  the scene: fonts render taller than their nominal size.
  `scenes/dev/pause_layout_check.tscn` now instantiates the real panel at 0/1/3/6/12/22/38
  upgrades and fails if the footer leaves the viewport — it is what produced the working
  number (125). Kept rather than deleted: `scenes/dev/*` is already excluded from both
  export presets, and the unit suite cannot cover this by convention (pure logic, never
  scenes). VBox separation went 8 → 5 in the same pass to buy back a row of build sheet.
  *Lesson: UI that must FIT is a measurement, not an argument — and the viewport, not the
  window, is the ruler.*

- **Level-ups slowed ~15%, as a flat multiplier on the whole curve
  (`Progression.RATE = 1.45`).** The run hit level 30 at 4:11 — and 30 is exactly
  `Rarity.PROGRESS_FULL_LEVEL`, where rarity odds saturate, so the entire rarity ladder
  was climbed before the boss and the climax had nothing left to escalate. Measured the
  way this dial has always been measured here (levels on a 6000 XP run): 39 → 33.
  The multiplier is 1.45 rather than 1.15 because the curve is quadratic — a flat 15% on
  COST buys only ~7% fewer LEVELS. Applied as a multiplier, not a steeper quadratic: the
  ask was "scarcer", not "back-loaded". A new test pins the real intent — a five-minute
  run must now arrive at the boss still short of saturation.

- **The level-up cue was replaced.** It was a two-chord sawtooth cadence with a bell —
  "stately", which is the one thing this game is not, and it read as borrowed from
  another genre. Replaced with a slow warm three-note rise on triangle. It deliberately
  takes the opposite pole from the power-up cue (fast/bright/square/delay-shimmer), which
  fires about as often and was the thing it kept being confused with. Built from stacked
  FIFTHS AND OCTAVES only — no third — because the gameplay tracks rotate through A
  Aeolian, D Phrygian and A Dorian, the same key clash that already forced the victory
  stinger to duck the music.

- **The level-up panel now fades and settles in over 160 ms** instead of snapping in on
  the frame the level landed. Not awaited by the caller, so a fast player picks through
  the motion rather than being gated behind it.

- **The documented smoke command never tested the game.** `--headless --path .` boots
  `run/main_scene`, which is `title.tscn` — so `--quit-after 300` exercised the title
  screen and exited 0 no matter what was broken in gameplay. Gameplay smoke needs
  `res://scenes/main/main.tscn` passed explicitly. Note also that `--dev-autopick` skips
  `LevelUpPanel.show_offers()` entirely, so a soak with autopick never touches the panel.

## BESTAGON — the M6.5 apply pass (2026-08-02)

Renamed, re-shaped, and the whole review acted on. `.ai/review/FINDINGS.md` is the
source list; 27 of 29 open findings landed here, 21 and 22 deferred to V1.1 as pure
refactors with no player-visible effect.

- **The game is BESTAGON.** The name comes from the PROTAGONIST now, inverting PRISM's
  logic: the player is a hexagon and nothing hostile is one. Shipped as the single word
  rather than the full sentence because a four-word title cannot be a wordmark, and the
  hexagon IS the logo — which is also how review finding 10 ("no prism in PRISM") gets
  closed. Tagline "hexagons are the bestagons" carries the joke.

- **Silhouette is FAMILY, size and colour are VARIANT, and `hollow` is a new pattern
  channel.** The colour law is untouched: hue still encodes allegiance. This mattered
  because the hostile band was already exhausted at seven enemies — findings 8 (the Ram
  wore the DART'S sprite and a hue 0.08 from the Lancer's) and 18 (the Splitter sat in
  the yellow reserved for enemy fire) were both symptoms of running out of hue. Pattern
  costs no hue budget and survives being 12px tall. First variant proves it: `lancer_heavy`
  is the same chevron, bigger and hotter, firing 65% faster.
  *Roster:* player hexagon · Drifter square · Dart needle (rotates) · Ram wedge (rotates)
  · Lancer chevron · Splitter hollow diamond · Bulwark hollow octagon · Prism pentagon
  (a pentagonal prism is a real solid, so the boss's name stays accurate) · **Nogaxeh**
  hollow hexagon.
  *Also caught during the pass:* the Dart's triangle was the ENEMY BOLT'S triangle, so a
  Dart read as an oversized piece of enemy fire. Only visible on a contact sheet.

- **NOGAXEH — the 10:00 mirror.** The only hostile hexagon; the silhouette rule holds for
  ten minutes and then breaks exactly once, and the break is the reveal. Its name is
  HEXAGON backwards and the HUD banner spells the word forwards before flipping, so the
  reveal is typography rather than dialogue nobody reads mid-fight. It fights with
  TESSELLATION — six arms at 60°, each a growing spoke of bolts — because tiling is the
  actual reason hexagons are the bestagon. Escorted by two elite Prisms, not four Prisms:
  four copies of one boss is not a mirror match.

- **The 5:00 boss died in SEVEN SECONDS, and the cause was not its HP.** Telemetry
  `run_041`: 8 projectiles AND +19 flat damage, and those axes MULTIPLIED — ~150x before
  pierce, ricochet, chain and Prism Core. No single upgrade was overtuned; the product
  was. Fixed at the root in `Stats.volley_damage_mult`: total volley damage now scales as
  sqrt(N) rather than N, taxed against each weapon's OWN base count so the scattergun's
  authored 5 pellets are free and only upgrade-bought growth pays. Multishot stays a
  crowd tool and stops being a boss-deleter, which narrows the DPS gap between a
  first-timer and a maxed profile — the thing that lets one boss HP number serve both.
  *`split_shot`'s draw weight was 2.2, the highest in the pool by more than double*, so
  the game was actively steering every run onto its most multiplicative axis. Now 1.0.
  *And Scatter's advertised "-20% damage" was never applied by anything.* The card lied.

- **Boss HP scales with player power, not just event index** (finding 4). A first-timer
  with the blaster and a returning player with four stacked weapons used to fight the
  identical 1800 HP. Only the BOSS scales this way — trash stays on the time curve,
  because enemies that grow because you got stronger read as the game cheating while a
  boss doing it reads as the boss rising to meet you.

- **The dash is the reward for beating The Prism.** i-frames, 1s cooldown, absent from
  the first five minutes entirely — so the prime-directive run is unchanged and BRIEF
  defect #1 cannot regress where it matters. It arrives exactly where 5:00→10:00 turns
  into bullet hell. *This forced finding 2's fix to be load-bearing:* `Meta.unlocked` had
  zero listeners, so unlocks applied only on the NEXT run — a player who won and pressed
  Continue would have met Nogaxeh without the dodge they had just earned.

- **Fluidity is VISUAL ONLY.** Rotation to heading, stretch along travel, cyan afterimage
  trail, idle spin. `velocity` is still assigned straight from input and never smoothed:
  acceleration and inertia are how defect #1 gets manufactured, and they are parked as
  future upgrades or an alternate character. The hexagon's six-fold symmetry is what makes
  it work — rotating it is visually free, so rotation orients the stretch rather than
  indicating a facing the player does not have.

- **A retired upgrade was still in the pool for weeks.** Generating the UPGRADE_LIST
  manifest (finding 23) emitted 37 entries against the hand-written list's 38. The extra
  was `bandage` — the heal this file records as REMOVED after the first playtest ("a
  reward you cannot use is a punished level-up"). Telemetry proves it was live:
  `bandage 24% (15/62)`, offered sixty-two times. Exactly the failure the phantom
  "generator" comment warned about, running in the opposite direction.

- **`_unhandled_input` is gated by `process_mode`.** Every key the pause panel advertised
  was dead because Main is PAUSABLE. See the Playtest 2 entry above; repeated here because
  it will recur in any future pause-time UI.

- **Two dead-code findings, same shape.** `EnemyStats.max_alive` was never enforced
  (finding 11 — the Shard's cap of 4 was data nothing read) and `Difficulty`'s three
  tuning curves had no production callers while ELEVEN tests asserted their exact values
  (finding 20). Both fixed; the difficulty tests that verified nothing are deleted.

- **The documented smoke gate never ran the game** (finding 29). `run/main_scene` is
  title.tscn, so `--headless --path .` booted the title screen and exited 0 regardless.
  `tools/verify.ps1` is now the gate: import + tests + gameplay smoke (asserting the boot
  line actually printed) + the pause-layout harness, with an optional 11-minute soak.
  *Two Windows PowerShell traps are baked into it:* a .ps1 without a BOM is read as ANSI,
  so one em-dash in a comment is a parser error; and `& exe 2>&1` wraps native stderr in
  ErrorRecords whose text contains "NativeCommandError", which the script's own error grep
  then matched — the gate failed itself on three steps that had passed.

- **Renaming moves `user://`, so the migration is code now.** It was hand-done for PRISM;
  `Meta._migrate_legacy_user_data` copies save, settings and the telemetry directory from
  a previous app name once, into a profile that does not exist yet. The forty-odd runs the
  whole balance pass rests on are not something a rename gets to orphan.

- **Dev runs write a separate profile** (finding 12), keyed off the `--dev-` prefix rather
  than a list, so a dev flag added later cannot forget to opt in.

**Open, and deliberately so:** every difficulty number in this pass is an ESTIMATE. There
has been no human run since the changes. A godmode bot clears the 5:00 fight in 48–113s
across seeds; the target is ~60s for a human. The knobs, in order of leverage:
`prism.tres:max_hp` (1200) · `RunDirector.POWER_STEP` (0.75) · `Stats.volley_damage_mult`
(the sqrt) · wave `spawn_interval`/`hp_mult` in `gen_waves.gd`, which was deliberately
NOT touched so the volley tax could be measured alone.

## Playtest 3 response — 2026-08-02 (first human run of BESTAGON)

Full spec and checklist: `.ai/review/ROUND2-SPEC.md`.

- **The player never deforms again.** The stretch-along-travel added that morning was
  rejected on sight — *"I dislike that it thins out when moving"* — and the underlying
  complaint was diagnosed by grilling as "inert and boring", NOT late or slippery. So the
  input model is untouched for the third time: `velocity = dir * move_speed`, no smoothing.
  Instead the sprite SPLIT into body + core, and the core lags on an underdamped spring.
  That is the only motion channel a hexagon has left — six-fold symmetry makes rotation and
  banking invisible (60° is identical to 0°), and deformation is off the table — so breaking
  the symmetry from the inside is the whole trick. The same node carries state: dims with
  HP, flares when the dash returns, breathes at rest, clenches mid-dash.

- **Trail: ribbon plus twin vertex jets.** The ribbon is a world-space `Line2D` through
  recent positions; the jets leave the two TRAILING vertices, which is the one effect that
  uses the fact that the player is specifically a hexagon. Length and intensity both scale
  with speed and the dash is a distinct spike, because that 0.15s is the only moment the
  player is untouchable and it should look like it. *Two traps, both worth remembering:*
  trail length is `points x speed / 60`, so the first attempt's 15 points drew a 32px
  streak on an 18px character and looked like nothing; and it did not render at all until
  `Floor.z_index` went to -10, because a trail at -3 was drawing behind the arena floor.

- **Enemies +20-30%, bosses and player +10%, projectiles unchanged, balance NOT retuned.**
  Sizes are now TIERS in `resources/enemy_size.gd` rather than ten hand-picked floats, which
  is what makes "size is a VARIANT axis" a mechanism instead of a convention. Enemy sprite
  canvases went 16 -> 24px so the shapes stay crisp instead of nearest-scaling to stairs,
  and `enemy.gd` now derives its scale divisor from the TEXTURE WIDTH — the hardcoded 16
  had been silently drawing the 32px boss sprite at 2x for its entire life.

- **Chain lightning is drawn, not fired.** It was duplicate short-lived projectiles, which
  is why *"the chain lightning doesn't look like lightning at all"* — it was, literally,
  more bullets. Now damage applies directly and a jagged polyline is drawn with a
  translucent body under a white-hot core, the same construction as the Lance's beam.
  Spawning no children also makes the "children must be INERT" recursion rule structural.

- **The sound problem was DENSITY, not pitch.** The complaint arrived as "a bit high pitched
  and not super clear what's making what sound" and resolved under questioning to *"too many
  sounds and all too similar"*. Retuning 23 cues would not have helped. Fixed with a central
  `Sfx.THROTTLE` table rate-limiting the five frequent cues, plus a real loudness hierarchy:
  boss_telegraph -1 and hurt 0 against pickup -19, hit -17, shoot -16. Texture went under
  the floor so the safety-critical cues could be heard at all.

- **NOGAXEH: three phases, alone for two, then escorts behind a shield.** `boss.gd` grew
  `phase_thresholds` (a PackedFloat32Array of HP fractions) so the Prism's two-phase fight is
  unchanged while the mirror runs three. Phase 1 is one attack, slowly — that restraint IS
  the dread. Phase 2 it starts dashing with a trail, quoting the player's own verb. Phase 3
  the escorts arrive AND it becomes invulnerable until they die, so the escorts cannot be
  ignored and the pentagon beaten at 5:00 comes back as its minion. Three patterns now:
  LATTICE (six spokes), HONEYCOMB (bolts from the vertices of a hex cell), SHEAR (two
  counter-rotating rings). Music thins to bass on arrival and rebuilds one stem per phase.

- **The shield needed three indicators, not one.** A player shooting an invulnerable boss
  with no explanation is BRIEF defect #4. The membrane fills the hollow ring (the cell
  closes), blocked hits get a grey pulse and a dull thud instead of the white hit-flash, and
  the HUD bar locks with `SHIELDED — DESTROY THE PRISMS`. Any one of the three alone would
  have left the state guessable rather than stated.

- **Damage-triggered boss spawns must be DEFERRED.** `phase_changed` is emitted from inside
  `Boss.take_hit`, which is called from `Projectile._on_body_entered` — a physics flush — so
  spawning the escorts there threw "Can't change this state while flushing queries" on every
  mirror fight. Same trap DECISIONS already records for Prism Core and Chain Lightning,
  reached by a new route. *Anything a boss does in reaction to damage is inside a flush.*

- **Two more orphaned content files.** `chaser.tres` and `fast.tres` were pre-M5 roster
  leftovers referenced by nothing but a stale comment — the same class as `bandage`. Three
  in two days is not bad luck; it is what a hand-maintained content directory does.

- **NEVER round-trip a source file through PowerShell 5.1.** `Get-Content` reads a UTF-8 file
  without a BOM as cp1252, and `Set-Content` writes the mojibake back out as real UTF-8. One
  read-modify-write silently corrupted every em-dash in seven scripts. Worse, the obvious
  repair (`text.encode('cp1252').decode('utf-8')`) reports every file CLEAN, because a single
  non-cp1252 character anywhere raises and aborts the whole file — the fix has to walk
  character by character. Use the Edit tool, or Python, for source files.

**Still an ESTIMATE, unchanged from the last pass:** every difficulty number here is tuned
against a godmode bot, which the project's own history says cannot set difficulty. The mirror
event is budgeted at ~1.9x the 5:00 event by total HP, which is the ratio that should produce
a ~2 minute climax against a ~60s Prism. Knobs, in order: `nogaxeh.tres:max_hp` (2000),
`RunDirector.ESCORT_HP` (0.5), `prism.tres:max_hp` (1200), `RunDirector.POWER_STEP` (0.75).

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

## The first clean human run, and what it superseded — 2026-08-02 (grilling session)

No code changed in this session. `run_076.jsonl` — 3312 lines, 11 minutes, **played with no dev
flags** (confirmed by `save.cfg` `best_time=349.1716666666559` matching the run's `victory` event
to the millisecond, so it wrote to the real profile rather than `save_dev.cfg`) — was analysed and
turned into a locked rework spec. `TODO.md` M7 is the checklist; the evidence is in this file and in the M7 commits
while it lasts. The decisions and reversals worth keeping are here.

**Budgeting a boss as an HP ratio to an earlier boss is invalid, and this is the proof.**
The paragraph immediately above this section reasons that the mirror at ~1.9x the 5:00 event by
total HP "should produce a ~2 minute climax against a ~60s Prism." Measured on a human: the 5:00
event took **49s** and the 1.9x-larger 10:00 event took **~22s** (spawn 599.99, `bosses:3` at
617.0, `bosses:0` at 622.0). The player's DPS roughly **quadrupled** across those five minutes, so
the ratio was never going to hold. Budget boss events in **seconds at measured DPS**. The estimate
disclaimer in that paragraph was correct and is now discharged.

**`Progression.CURVE_QUADRATIC = 0.17` and `RATE = 1.45` are superseded.** Both were added earlier
the same day to cut level spam, and both are now over-corrections. The reason is that they were a
proxy fix for the wrong problem: what hurt was **78 card screens**, not 79 levels. Gating cards to
every 3rd level fixes that directly, and once a level is a silent stat drip rather than an
interruption, frequent levels are the reward. Baseline moves to ~75 levels in a 10-minute run with
no XP upgrades, which makes levels ~2.4x cheaper than today (1.0x currently reaches ~54).

**The XP runaway was multiplicative stacking, again.** `greed` is Epic, +50% XP, max 2 stacks, and
`upgrade.gd:114` stacks it multiplicatively; with `scholar` at 3 stacks the run held `xp_mult` at
**~3.0x** from about 2:30 onward. Level 79 needs ~56,200 banked XP against a raw gem income of only
~20,500 — greed alone was worth 25 levels. XP effects become **additive into one `xp_mult` with a
cap**, the same shape as the multishot tax that fixed the 7-second boss.

**Difficulty is tuned for a stranger's first 10 minutes, against a zero skill tree.** The run shows
no death pressure at all — lowest HP after any hit was 37.5%, once, at 7:59, and the player sat at
100% at nearly every tick after 3:00 while taking 168 damage against a pool that grew 6 to 19. The
tuning reference is therefore an empty account; the skill tree is a veteran's power fantasy layered
on top, never a difficulty assumption.

**The Prism at 5:00 is accepted as-is.** 49s against a ~60s target. Do not retune it.

**Weapons become drafts rather than possessions.** A meta unlock now adds that weapon's *card* to
the draft pool instead of granting the weapon; drafting it opens its branch of upgrades, and each
weapon gets one Legendary. `MetaState` and the milestones are unchanged — only the delivery moves
from "you own it" to "you may draft it." Driven by all three orbital cards landing bottom-five
(`orbit_radius` 0/11, `orbit_count` 1/10, `orbit_speed` 3/9), which is a weapon problem wearing
three cards, not three bad cards.

**A dead card is not always a bad card.** `tough_hide` 1/12 and `carapace` 2/12 read identically to
`lodestone` 0/16 and `magnetism` 0/12 in the pick-rate data, but the causes are opposite: the
defensive cards are dead because *the game never asked for defense*, and the magnet cards are dead
because they are *redundant*. Only the second kind gets cut. The defensive cards are parked and
re-measured after the boss rework, which should revive them on its own. Corollary, recorded because
it is easy to get backwards: **do not add passive max HP to the per-level drip** — free defense
would keep those cards dead permanently.

**Legendary rarity was never the problem.** 4 appearances in 234 offer slots (1.7%), taken 4/4. The
"Legendary should feel rare" note is presentational only; do not touch the odds.

**Baked glow vs real bloom: reopened, to be decided from an image.** `BRIEF.md` chose baked so a
single-threaded web export could not break on a post-process. That reasoning is mostly obsolete —
the renderer is `gl_compatibility`, Godot 4.7 supports glow there, and at a 640x360 buffer the cost
is negligible. The remaining risk is visual (chunky bloom steps, washed HUD text), so it goes
through `scenes/dev/juice_lab.tscn` as a variant per the project's own rule, and the human picks
from a contact sheet. Baked remains the fallback, so the decision cannot end up worse than today.

**Concern raised and overruled: the meta skill tree ships in the same pass as the rework.** The
recommendation was to ship only the read-only card catalogue now and defer the currency, stat nodes
and card shop to the following milestone, on the grounds that a permanent stat tree re-inflates the
power curve this rework exists to cut, and does so by a different amount per player — turning
NOGAXEH from tunable-against-a-player into tunable-against-a-distribution. The human chose the full
tree. Mitigation, which is what makes it workable: every difficulty number is tuned against a
zero-tree account, so the tree can only ever make the game easier than its tuning target.

**The telemetry instrument had been quietly discarding its most valuable rows.** `begin_run()` calls
`_close()` rather than `end_run()` (`telemetry.gd:37`), so restarting a run drops its ending row —
and both of the only runs that ever reached a boss have no `run_end` at all, meaning the endings
report omits precisely the runs worth reading. `_run_t` is also never reset, so a new run's
`run_start` carries the previous run's clock, and `analyze_telemetry.py:28` still defaults to the
pre-rename `PRISM` directory. Fixed first in M7, before any gameplay change, because nothing in the
rework is measurable until it is. Related symptom to verify: `run_076` reached 2780 kills but
`save.cfg` banked `best_kills=1125`.

## M7.1 + M7.2 built — 2026-08-02

**The run had no single end, and that was the actual bug.** The instrument fixes were the cheap
half. The expensive half was that `Main` only banked a run when the player DIED: a restart, a quit
to title or a closed window dropped both the telemetry ending row and the run's records. That is why
`run_076` peaked at **2757 kills / 660.1s** while `save.cfg` still reads `best_kills=1125` —
verified this session, and worse than the ledger suggests, because that run also cleared the
victory and survived past 600s, which is exactly the `endless_proven` condition. **The human earned
the PRISM LANCE and the game never gave it to them.** `Main._finish_run()` is now the one place a
run ends, guarded so death and teardown cannot both bank it. The existing `save.cfg` is left
untouched: it is the human's profile, and a retro-repair is their call, not a side effect of a fix.

**Telemetry's own close handler was racing Main and winning.** It fired on
`NOTIFICATION_WM_CLOSE_REQUEST`, which an autoload receives *before* the main scene does, so every
window-close wrote a bare `quit` row with no kills, level or outcome and then closed the file,
leaving Main's finish nothing to write to. It now fires only on `PREDELETE`, as a net — and its
reason is `lost`, so if that string ever shows up in a run file it is a bug report rather than a
normal ending.

**`RATE = 1.45` is superseded by `RATE = 0.61`; `CURVE_QUADRATIC = 0.17` is untouched.** 1.45 was a
proxy fix for card-screen spam, and `CARD_EVERY = 3` fixes that directly and three times harder, so
keeping both was over-correcting. Solved rather than guessed: run_076's ~20,500 raw gem XP reaches
level 54 at 1.45 and **level 74–75 at 0.61**, which is the spec's baseline. Measured in a soak on
the shipped build: **level 71 at 10:00, 74 at 11:00, exactly 25 card screens.** The shape stays
superlinear — cheap levels are not flat levels, or the drip would be the same size at both ends of
the run.

**The drip is SET from the level, never accumulated.** `Progression.drip_*_mult(level)` are pure
functions and `Main._apply_level_drip()` assigns them. This is not style: a chained level-up
resolves several levels inside one frame, and an accumulating drip would apply two or three times
and be untestable afterwards. It is also additive in the level count rather than compounding, which
over 75 levels is the difference between 2.1x damage and 3.0x. Deliberately no max HP and no
defense in the drip — see the previous session's corollary.

**Two constants moved that the spec did not name, because the spec changed the axis they measure.**
`Rarity.PROGRESS_FULL_LEVEL` 30 -> 42: it saturates rarity odds at a LEVEL, and a run that used to
reach 54 now reaches 75, so 30 would have topped out the whole ladder 40% into the run — the exact
failure that moved it last time. 42 holds the old fraction. `Rarity.PITY_LIMIT` 6 -> 4: it counts
screens without a Rare-or-better, and screens went from ~79 a run to ~25, so 6 was a quarter of
every decision in the run. 4 fires on ~21% of chances, which keeps it a floor rather than the normal
way Rares arrive.

**Consequence to measure, not to pre-empt: the 5:00 Prism will probably get slower.** It was
accepted at 49s. The player now arrives at 5:00 with ~13 card picks instead of ~40, offset by a drip
worth roughly +60% damage and +30% fire rate at level 41. Which way that nets out is a measurement,
and it is deliberately left alone until the human run in step 9 — the spec's own instruction is to
budget fights in seconds at measured DPS rather than argue them from ratios.

## M7.3 — weapons became drafts, and the drip had to be re-measured twice

**A weapon's gate is now its own id, and there is no second field.** `WeaponResource.requires_unlock`
is gone: `is_available(drafted)` asks whether the weapon is in the RUN's draft list. A weapon and its
requirement can no longer drift apart, and the whole delivery change cost one changed line in each
weapon node — they already took a `unlocks` array; they now take a `drafted` one.

**Two kinds of gate flow through one field on the CARDS, deliberately.** `UpgradeResource.
requires_unlock` holds either a MetaState unlock id (which is what puts a weapon's own draft card
into the pool) or a `weapon_gate()` id (which is what opens that weapon's branch of upgrades), and
`Main._offer_gates()` assembles both into one array. To the pool they are the same question. This
also closes a bug nobody had noticed: orbital cards used to gate on the META unlock, so a veteran
saw them in every run whether or not the orbital was in that run.

**The orbital got a mechanic, not a buff.** All three of its cards measured bottom-five, which is a
weapon problem wearing three cards. It now has kill-fed MOMENTUM: every kill the ring lands adds
spin up to double, decaying when the killing stops, and spin is also hit RATE — so the weapon is at
its best exactly when the arena is at its worst, which is the situation it exists for. The dead
radius card (0/11) folded into Split Orbit rather than being buffed: it was half of one idea sold
separately.

**`gen_upgrades.gd` now deletes orphans.** Retiring `lodestone` and `orbit_radius` by removing their
definitions would have left their .tres files on disk and in the pool, which is exactly the
content-drift failure that already shipped a retired upgrade 62 times. The generator owns the
directory, so it owns the deletions.

### The drip was wrong twice, and only measurement caught it

The spec's drip (+1.5% damage, +0.75% fire rate per level) was explicitly "to be verified by
measurement, not argued". Verified against the pre-rework build with an identical blaster-only soak
from a **fresh profile on both sides** — the first attempt at this comparison was invalid, because
the old build granted weapons from the PROFILE and the dev profile had unlocks, so the "baseline"
was secretly a three-weapon run.

| blaster-only, fresh profile | kills @3:00 | kills @3:51 | enemies alive |
|---|---|---|---|
| pre-rework (78 picks) | 381 | 626 | 5 |
| spec drip as written | 86 | 115 | **110 (the cap)** |
| + flat damage drip | 210 | 316 | 110 (the cap) |
| + 3x card magnitudes | 228 | 315 | 110 (the cap) |
| + fire rate 2x, + breadth | **369** | **604** | 18 |

Three corrections came out of that table, in the order the numbers forced them:

1. **Damage drip is FLAT, not a percentage.** Early DPS is dominated by the flat bonus on a base of
   1: a percentage drip is worth +16% of almost nothing at level 12, while the seven picks it
   replaced were worth several whole points. A percentage pays out exactly when the player has
   stopped needing it. One point per three levels.
2. **Card magnitudes went up ~2-3x.** This is the other half of `CARD_EVERY`, and the spec says so
   in its own words — "3x fewer, 3x more valuable decisions". Only the first half of that is a gate.
   A player with a third of the picks and unchanged cards is simply a third as strong. Unique Epic
   and Legendary EFFECTS are untouched; they were already what a scarce pick should feel like.
3. **The drip also had to buy BREADTH.** Damage and fire rate kill one thing faster; only projectile
   count clears a crowd, and count was card-only — the old pool handed it out five or six times a
   run, the new one hands it out once. Without it the arena sat pinned at the live-enemy cap from
   3:00 no matter how much damage was added. +1 projectile every 20 levels, taxed by
   `volley_damage_mult` like every other source, so it buys reach and never damage.

The shipped curve deliberately MATCHES the pre-rework build early and undershoots it late: the
stranger's first five minutes are the prime directive, while the late-game runaway is the thing the
rework exists to cut. That undershoot is what NOGAXEH v2 gets budgeted against.

**`Stats.COOLDOWN_FLOOR` added while rebalancing.** Fire-rate cards multiply and every one of them
got bigger; eleven picks on that axis would have reached a weapon firing every frame. Same shape as
the crit and lifesteal caps — an axis that stacks needs a ceiling authored next to it rather than
discovered.

## M7.4-7.7 built, and one number the soak refused to let stand — 2026-08-02

**The 10:00 fight scales by LEVEL now, not by weapon count, and that was forced rather than argued.**
Weapon count was a fair DPS proxy while weapons came from the PROFILE: a player either owned three
all run or owned one all run, and the number was known the instant a boss spawned. M7.3 made weapons
DRAFTED, and the proxy came apart in both directions at once. Soaked on the shipped build:

| soak | mirror event HP | fight length |
|---|---|---|
| blaster only, level 91 | 11,200 (x1.0) | **32 seconds** |
| four weapons, level 77 | 36,400 (x3.25) | **212 seconds** |

Neither number describes the player. The one-weapon run was not weak — it had spent all thirty picks
sharpening one weapon; the four-weapon run was not four times stronger — it had spent picks
*acquiring* weapons instead. LEVEL sees all of that at once, because it counts the drip, the picks
and how well the run has actually gone, and it keeps the properties that made weapon count usable:
discrete, known at spawn, unable to drift mid-fight. Below level 40 the fight is exactly the
authored 11,200; every level above adds 4.5%. Re-soaked at **142 seconds**, against a ~120s target.

**The bot is now a poor instrument, and this is the honest limit of what was verified.** Run-to-run
variance is enormous: two identical soak commands produced level 85 and level 50 at 10:00, because
`--dev-autopick` takes `offers[0]` and there are only ~25 picks in a run, each now worth three times
what it used to be. One draw of Cannonball early is a different game from one draw of Magnetism.
Everything structural is verified — phases, gates, the fuse, the detonation, the drops, the endings,
the shard economy — but the *tuning* numbers below are first estimates awaiting the human run that
step 9 of the build order exists for, exactly as the spec instructed.

**The skill tree is a scrolling list, and that is a design decision rather than a shortcut.** A
literal branching node graph with connector lines needs roughly three times the 640x360 viewport's
height before a single node is legible, so it would have shipped either unreadable or scrolling in
two directions. Rows grouped by cost give the same read — here is the ladder, here is how far up it
I am — in a shape that fits, and `pause_layout_check` now proves the frame and the Back button stay
on screen.

**Three screens are now measured by the layout harness, not two.** The true ending's first draft came
out **633 px tall against a 360 px viewport** — nearly double — and it is the screen most likely to
do that, because it is the only one whose height grows with how well the run went. It is therefore
at its tallest in exactly the run it was written for. The level-up panel is guarded too now: it has
shipped broken once (level 57, third card off the right edge), and M7.6 both widened the cards and
put longer text on them.

## Glow: the lab variant exists, the comparison does not yet — 2026-08-02

**Shipped look unchanged. Baked glow stays, and that is the fallback the brief already chose**, so
nothing is at risk — but the reason recorded here is NOT "bloom looked worse", because the sheet
does not support that claim.

**The engineering finding is solid and is the useful half.** Adding a `WorldEnvironment` with
`glow_enabled` to the root viewport is a **no-op** in this project. Under `gl_compatibility` the
root Window viewport allocates its backbuffer at boot from `rendering/viewport/hdr_2d` (default
`false`), and setting `Viewport.use_hdr_2d` at runtime does not reallocate it — verified by pushing
threshold 0 / strength 8 / intensity 5 / mix 1, which should blow the screen to white, and getting a
frame identical to baseline. Real glow therefore needs either a `project.godot` change or a fresh
`SubViewport` with `use_hdr_2d` set **before** it enters the tree. Related trap: `Environment.
glow_mix` defaults to 0.05 whatever the blend mode, silently capping the whole effect at 5%.

**Why the visual comparison is not conclusive.** The lab renders the bloom variants through that
SubViewport and the baked variant through the main viewport, so the sheet compares two RENDER PATHS
and not two looks. Two things in the images say so:

- variant 1 (threshold .55, strength 1.3) and variant 2 (threshold .75, strength 0.6) are visually
  **identical to each other**. Strengths that far apart cannot produce the same frame if bloom is
  the variable;
- both bloom frames **lose the baked halo** that the shipped sprite carries in its own texture — the
  big pentagon goes from a soft pink corona to a hard edge. Bloom adds light; it cannot subtract a
  halo that is painted into the art.

So what the sheet actually shows is that the SubViewport rig is not reproducing the shipped
pipeline. The honest state: the case, the variants and the capture commands exist and are
reproducible; the decision the brief asked for — human picks from pixels — still needs a rig where
the only difference between variants is the post-process.

Deliberately not chased further this session. Baked is shipped, baked is the fallback, and the
question is cosmetic while 7.9 (a human tuning run) is the thing actually blocking the milestone.

---

# First external playtest — 2026-08-03

The game went onto itch.io as a restricted page and a person who had not built it
played it. Six defects, and the pattern in *how* they were found is the useful
part: **three came from the player, and three came from looking at the screen
before shipping.** The automated gate was green throughout all six.

## The gate was green and the title screen was broken

Adding a third stacked button to the title pushed the last one off the bottom of
the 640×360 viewport. It also left the whole menu jammed against the bottom edge,
because a `CenterContainer` whose content is taller than itself does not overflow
symmetrically — it clamps to the top. One cause, two symptoms, and the second one
reads as "misaligned" rather than "broken", which sends you looking in the wrong
place.

Neither was visible in the 1280×720 window everything is developed in, and
`verify.ps1` passed because it measured four screens and the title was not one of
them. **A harness only guards the screens enrolled in it.** The title is enrolled
now, and the check asserts *centring* as well as fit, with a record line present —
that label is empty on a fresh profile and appears only for a returning player, so
the screen is at its tallest for the person who has seen it most.

Third occurrence of this defect class in this project. Written up in the hub.

## `◆` was a tofu box on web and perfect on desktop

The export ships **Open Sans SemiBold with zero fallbacks**. U+25C6 is not in it.
It looked right on desktop only because Godot falls back to a system font there,
which a browser build has none of — so the missing glyph was invisible in every
screenshot and every local run, and appeared on the title screen of the build a
stranger opened.

Answered with `Font.has_char` rather than reasoning about Unicode blocks, which
also paid for itself: `·` and `—` are present, so the em dashes in seven other
user-visible strings were fine and the fix narrowed to three. The diamond became
the word `SHARDS`, which a first-time player can read anyway — a symbol nobody has
been taught is not communication.

## Two reports, one cause: power with no perceptual channel

*"Aegis is practically invisible. cant tell when it's on or off"* and *"0
indication we are getting stat boosts when leveling up"* are the same bug.

Aegis tinted the player cyan — but hue is spent on allegiance by the colour law
(cyan yours, magenta-orange hostile, yellow enemy fire), so it could not also
carry a timed buff, and the cue landed on a player who was already that colour.
Fixed with **pattern**, the channel nothing else uses: a ring at 2.4× the body,
pulsing, counter-rotating against the orbitals so the two never read as one thing.

The drip was made silent deliberately — cards were cut to one level in three
because a decision every 7.9 seconds had stopped being a decision. That was right.
What went with it by accident was all feedback for the other two levels, which
carry most of the run's cumulative power. A toast now names the **delta** (`+1
DAMAGE`, `+1 PROJECTILE`), with fire rate as the fallback line only when nothing
louder happened — it moves every level, so promoting it would make every level
look identical.

## The browser owns things we assumed were ours

ESC does not pause in fullscreen because the browser consumes it to exit
fullscreen — deliberately, as the guaranteed way out of a page that took the
screen. Unfixable from inside the page and correctly so, so every run now opens by
announcing **P TO PAUSE**. A keybinding the player does not know about is not a
fix.

The reported freeze-that-recovers is almost certainly the same family: Godot's web
build runs its whole main loop from `requestAnimationFrame`, which a browser stops
for a tab it considers hidden and later resumes exactly where it left off.
Auto-pause on focus loss makes that stop deliberate. **Recorded as a hypothesis,
not a diagnosis** — it was never reproduced. What *was* established by measurement
is that there is no leak (flat node/object/memory counts through 1068 kills on
desktop and 833 in-browser, past both freeze points) and no engine error at all;
every red line in the player's console came from crypto-wallet extensions.

## Bosses 2×, and a shove instead of a latch

Prism 35 → 70, NOGAXEH 44 → 88. `stats.size` drives both sprite scale and hitbox,
so one number per boss moves everything — except two things that were **not**
derived from it and would have ended up inside the body: `shard_orbit`, authored
per boss, scaled in step rather than overridden; and the shards' own scale, an
absolute `0.42` that had *always* meant resizing a boss silently changed how big
its shards looked relative to it. Derived from the body now. Note this doubles the
boss hitboxes too, so both fights are easier to land shots on — deliberate, but
the next fight timings should not be read as pure tuning data.

Enemies "latched on weirdly" because contact damage grants i-frames, so whatever
hits you sits inside you for the whole invulnerable window doing nothing — hiding
the fact that you are briefly safe. Every enemy is now pushed ~75 px, damage-free:
a breather, not a weapon, because a shove that also hurt would make taking damage
a crowd-control button. `Enemy.shove` takes a **distance in pixels** rather than an
impulse, since travel is speed÷decay and multiplying the decay back out means the
caller asks for 75 and gets 75 even if the decay is retuned later.

## Packaging is a script now, because it was done by hand wrong twice

The first hand-built zip carried stray `.import` sidecars the editor had generated
inside `builds/`, and no launcher — so the tester double-clicked `index.html`, hit
the browser's `file://` fetch block, and got the Godot splash over "Failed to
fetch". Nothing was broken; the package was wrong. `tools/package.ps1` now does
export → clean → copy → zip and **asserts** `index.html`, `index.pck`, `index.wasm`
and `START-HERE.bat` sit at the zip root, because itch looks for `index.html`
there and nowhere else and a folder-level zip uploads fine and then serves a blank
page. Export presets also exclude `builds/*` now, or the importer starts consuming
previous exports.

## Naming and disclosure

**GRID**, chosen by the human over "The Lattice". A hexagonal-cell layout for that
screen is parked as a later idea — it fits the game's whole shape language, and it
needs a layout that still passes the 640×360 harness, which is why it is parked
rather than done.

**AI disclosure: Yes, all four sub-classifications.** Decided on asymmetry rather
than on where the line truly falls: under-tagging risks delisting, which itch
states outright, while over-tagging costs a browse filter already accepted by
answering Yes at all. Code and the 45 upgrade names and descriptions are
unarguable; the sprites and music are the genuinely arguable case (deterministic
scripts, no model at render time — squarely itch's carve-out — but the scripts are
LLM-written). Full reasoning in `tools/share/ITCH-PAGE.md`.

## Playtest 4 response — 2026-08-03 (second run by the external tester)

- **2026-08-03 — Doubled `prism.tres:max_hp` (1200 → 2400) knowing it also inflates the 10:00
  climax, instead of scaling only the standalone Prism events.** The mirror event's escorts ARE
  full-strength Prisms, so its authored budget went 11,200 → 18,400 (+64%) as a side effect; the
  last soak of that fight measured 212 s for a four-weapon run against a ~120 s target, and
  `MIRROR_LEVEL_STEP` (4.5%/level) was fitted against the old base. Chosen deliberately by the
  human after the coupling was put in front of them, over a code change that would have scaled the
  two events independently. **Consequence accepted, not overlooked** — but it is UNMEASURED, and
  every comment that quoted 11,200 (`run_director.gd`, `nogaxeh.gd`) now says so.

- **2026-08-03 — Fixed the Dart/bolt confusion by removing rotation, not by recolouring.** The
  tester read the orange Dart as a projectile. The obvious fix — move it out of the warm hue band —
  was declined in favour of keeping the colour law intact. The real cause was that a small pointed
  shape rotated along its velocity IS the grammar of a bullet, so `faces_travel` went false on the
  Dart and the rule is now written on the field itself: bolts point where they travel, bodies do
  not. Worth recording because the intermediate step FAILED: adding the neon glow first did not fix
  it, and a 1:1 crop is what proved that rather than a full-frame screenshot.

- **2026-08-03 — Baked the neon rather than migrating the renderer.** The human asked for a glow on
  enemies. Real 2D bloom is unavailable here: `gl_compatibility` fixes the root viewport's
  backbuffer format at boot, which `juice_lab.gd` had already proven with a threshold-0/strength-8
  no-op test. The only real-bloom path is rendering the whole game through a `SubViewport` — a
  renderer migration, with the camera, UI layering, the layout harness and web perf all downstream
  of it. Shipped one shared additive radial sprite per entity instead. Tuned TWICE: the first
  values looked right on a lone enemy and turned a twenty-body pack into one pink smear, because
  additive light stacks and the tuning inverts with density.

- **2026-08-03 — Cut screenshake at the ceiling (`MAX_OFFSET` 9 → 6) instead of at the nine call
  sites.** Every per-event trauma value is a deliberate relative weight with its own history (the
  kill beat is 0.22 *because* 0.12 once produced 0.086 px of shake). Scaling the ceiling moves all
  nine without re-arguing any. The per-frame kill cap tightened separately (0.30 → 0.20) because
  mass-kill is the specific case the tester hit twice. Shipped an off toggle regardless of tuning:
  motion sickness is not a tuning problem.

- **2026-08-03 — Ricochet carries only overkill, and `Enemy.take_hit` returns absorbed damage to
  make that expressible.** Bounces redirected at FULL damage, so Ricochet was a flat 5x on every
  shot and hit a boss as hard as a crowd of 1 HP Darts. The absorption rule is a static pure
  function (`Enemy.absorbed_by`) precisely so it could be unit-tested under the repo's
  logic-only-no-scenes convention — the same shape as `GameCamera.shake_pixels`. Executioner
  deliberately grants no extra carry: an execute is a free kill, never a bigger bounce.

- **2026-08-03 — Two defects found that nobody reported, both in the safety net rather than the
  game.** (1) The gameplay screenshot rig had been capturing the PAUSE MENU since focus-pause
  shipped the day before: a capture run is launched from a terminal and never holds focus, so
  `main.gd`'s `_notification` paused it instantly. Exit 0, valid PNG, correct frame, wrong subject.
  (2) `pause_layout_check` guarded five screens and not the victory screen — the one screen every
  winning player sees. Both are the same failure: a guard that reports green over a gap it does not
  cover. Fixes: `AiScreenshot.capturing` as the single predicate any pause path checks, and a
  victory case at 0–4 unlocks.

## Playtest 5 response — 2026-08-03 (developer's own run, Windows build, SPEED x3)

- **2026-08-03 — The boss bar shows NOGAXEH and nothing else; escorts are excluded from BOTH
  halves of the fraction.** The bar accumulated every boss in the event — 4000 for the mirror plus
  6 × 2400 of Prisms — so killing the two opening escorts visibly drained a bar labelled NOGAXEH
  while he stood untouched behind his shield. The report was "he was not invulnerable", and he was:
  the shield worked perfectly, the bar lied about who it was measuring. Fixed with an `is_escort`
  flag set by the director BEFORE `boss_spawned` fires, because Main accumulates the denominator in
  that handler and a flag set afterwards arrives one boss too late. Numerator and denominator must
  agree or the bar reads full for the whole fight.

- **2026-08-03 — A boss that touches you throws the PLAYER clear, because it refuses to be
  shoved itself.** The hurt-shove gives i-frames a visible meaning by throwing the crowd off you,
  and it never reached anything boss-sized: `Enemy.shove` scales by body size, so Nogaxeh at size 88
  receives 13/88 of it — 11 px against his own 146 px dash — and `Boss.take_hit` ignores knockback
  by design, since shoving a boss would undo the telegraphed positioning the fight is read from. The
  result was a death loop: contact, i-frames, i-frames lapse while still inside his body, contact
  again. "It's like he was stuck with me, couldn't get away from him anymore and he just killed me."
  Since the boss cannot move, the player does. 180 px is a FIRST ESTIMATE and deliberately less than
  a committed dash: escaping a boss should still cost the dash earned at 5:00. Note this was the
  same defect as the 2026-08-03 "enemies just latch on weirdly" fix — the fix simply had a size
  scaling that excluded the only enemies big enough to trap you.

- **2026-08-03 — Two cards that READ the same never share a hand, keyed on description text.**
  Level 29 offered Split Shot (Rare) and Scatter (Uncommon) side by side: same effect, same
  magnitude, byte-identical text, different only in a rarity ribbon. Keyed on `description` rather
  than on `effect` deliberately — effect is far too coarse, since four upgrades share DAMAGE and
  four share FIRE_RATE as a deliberate tiered ladder, and three weapon drafts share effect 26 while
  offering genuinely different weapons. Description is what a player actually tells two cards apart
  by. An EMPTY description is never a match: the first version treated it as one and cut every hand
  to a single offer, taking four green tests red — every upgrade built by `test_upgrade_pool`'s
  `_mk` helper omits description. This is a guard over a symptom; the duplicate content is still
  open in `TODO.md`.

- **2026-08-03 — The Dart faces its travel again, REVERSING the same day's decision, and is
  separated from bolts by mass instead.** Yesterday's rule was "bolts point where they travel,
  bodies do not", adopted because the Dart read as a tracer round. The next playtest reported the
  opposite — "darts no longer fly pointing towards you" — because a needle silhouette frozen at a
  fixed angle reads as BROKEN, which is worse than reading as ammunition. The original diagnosis
  named the wrong culprit: the problem was the SHAPE, and rotation was the only thing making that
  shape look deliberate. Compensating: +20% body size (18.5 → 22.2) and +20% glow via a new
  per-type `glow_scale`, on the reasoning that a bullet is small and a body is not. Note the size
  change also grows the Dart's collision rect and reduces the knockback it takes (both scale off
  `size`) — intended, but it is a balance change, not only a visual one.

- **2026-08-03 — A release build loses its entire log on a freeze, so `flush_stdout_on_print` is
  now on.** The hung process ran 37 minutes, printed the boot line and at least one `[boss]` line,
  and left a 0-byte `godot.log`, because a release build buffers the log file and only flushes on a
  clean exit. Measured against the shipped exe, hard-killed after 8 s: 0 bytes off, 73 bytes on.
  Every freeze before this one was unreadable by construction and nobody knew.
