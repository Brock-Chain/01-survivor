extends GutTest
## The XP curve, the card gate and the level drip, pinned at exact values.
## Retuning is allowed — but it must be a conscious edit of BOTH the constant and
## these numbers, never a drift. This test earned its place: it caught the
## 2026-08-02 superlinear change the moment it landed.


func test_xp_curve_exact_values() -> void:
	# `(5 + 4n + 0.17n²) * 0.61`, n = level - 1. RATE dropped 1.45 -> 0.61 in
	# M7.2: levels are cheap and mostly silent now, and CARD_EVERY carries the
	# scarcity that 1.45 was standing in for.
	assert_eq(Progression.xp_required(1), 3, "the first level stays cheap")
	assert_eq(Progression.xp_required(2), 5)
	assert_eq(Progression.xp_required(5), 14)
	assert_eq(Progression.xp_required(10), 33)
	assert_eq(Progression.xp_required(20), 86)
	assert_eq(Progression.xp_required(30), 161)
	assert_eq(Progression.xp_required(75), 751)


func test_curve_is_monotonic() -> void:
	for level: int in range(1, 90):
		assert_gt(Progression.xp_required(level + 1), Progression.xp_required(level))


func test_late_levels_cost_meaningfully_more_than_early_ones() -> void:
	# The curve is still superlinear. Cheap levels are not FLAT levels: a level-30
	# pick has to cost far more than a level-1 pick, or the drip is the same size
	# at both ends of the run and the back half stops escalating.
	var early: int = Progression.xp_required(1)
	var late: int = Progression.xp_required(30)
	assert_gt(float(late) / float(early), 40.0,
			"a level-30 pick must cost far more than a level-1 pick")


func test_a_ten_minute_run_reaches_the_baseline_of_about_seventy_five_levels() -> void:
	# THE dial. run_076 banked ~20,500 raw gem XP in 11 minutes with no XP
	# upgrades; the spec's baseline is ~75 levels on exactly that income. The old
	# RATE gave 54, which is what made greed's 3.0x worth 25 free levels.
	assert_between(_level_for_xp(20500), 72, 78,
			"~20,500 XP is the measured 10-minute income and must land near 75")


func test_rarity_saturation_is_not_reached_on_a_typical_five_minute_run() -> void:
	# Rarity odds saturate at Rarity.PROGRESS_FULL_LEVEL. The ladder must still
	# have somewhere to go when the 5:00 boss arrives, or the climax has nothing
	# left to escalate. ~3100 XP is a measured five-minute income.
	assert_lt(float(_level_for_xp(3100)), Rarity.PROGRESS_FULL_LEVEL,
			"a five-minute run must arrive at the boss still short of saturation")


func test_the_first_level_up_always_offers_a_card() -> void:
	# A stranger's first level-up has to teach the loop. Level 1 is the starting
	# level, so the first level-up lands on 2.
	assert_true(Progression.offers_card(2), "the first level-up is never silent")
	assert_false(Progression.offers_card(3))
	assert_false(Progression.offers_card(4))
	assert_true(Progression.offers_card(5))


func test_a_baseline_run_offers_about_twenty_five_card_screens() -> void:
	# The headline of the rework: 79 level-ups meant a card screen every 7.9
	# seconds. Three levels per card over a ~75-level run is ~25 decisions, each
	# worth 3x more.
	var screens: int = 0
	for level: int in range(2, 76):
		if Progression.offers_card(level):
			screens += 1
	assert_between(screens, 24, 26, "~25 screens per run, not 78")


func test_the_drip_is_a_pure_function_of_the_level() -> void:
	# Idempotence is the whole design: a chained level-up that resolves three
	# levels in one frame must not apply the drip three times. Level 1 is the
	# start of the run and gets nothing.
	assert_eq(Progression.drip_damage_bonus(1), 0)
	assert_almost_eq(Progression.drip_cooldown_mult(1), 1.0, 0.0001)
	assert_almost_eq(Progression.drip_move_speed_mult(1), 1.0, 0.0001)
	# Anchors, not intent — they moved with the 2026-08-03 balance cut
	# (DRIP_DAMAGE_PER_LEVEL 1/3 -> 1/4). What this test guards is PURITY.
	assert_eq(Progression.drip_damage_bonus(13), 3)
	assert_eq(Progression.drip_damage_bonus(75), 18)


func test_the_damage_drip_is_flat_because_early_dps_is_flat() -> void:
	# The one number here that was measured rather than reasoned. A +1.5%/level
	# version soaked at 86 kills by 3:00 against the pre-rework build's 371 on an
	# identical blaster-only run, because a percentage of a base-1 weapon is
	# worth nothing exactly when the player has no cards yet. Pinned at both ends
	# so a future "tidy this into a multiplier" cannot quietly undo it.
	#
	# The 2026-08-03 cut (1/3 -> 1/4) moved BOTH ends, deliberately — the whole
	# change is "players get too strong too fast". The FLAT-ness is what this
	# test defends and that is untouched; the thresholds are the part that moved.
	# Recorded rather than quietly rebased: the first real point of damage now
	# lands at level 5 instead of 4, and the drip alone brings 10 to the 5:00
	# boss instead of 13.
	assert_eq(Progression.drip_damage_bonus(4), 0, "level 4 is now the last silent one")
	assert_eq(Progression.drip_damage_bonus(5), 1, "a real point of damage by level 5")
	assert_gt(Progression.drip_damage_bonus(41), 8,
			"and enough by the 5:00 boss to matter without cards")


func test_the_drip_buys_breadth_as_well_as_damage() -> void:
	# Only COUNT clears a crowd. Without this the soak pinned the arena at the
	# live-enemy cap from 3:00, because multishot was a card-only axis and the
	# player now gets a third as many cards.
	assert_eq(Progression.drip_projectiles(1), 0, "the run still opens with one bolt")
	assert_eq(Progression.drip_projectiles(21), 1)
	assert_eq(Progression.drip_projectiles(75), 3, "~3 over a baseline run, not 6")


func test_the_fire_rate_drip_is_a_rate_not_a_subtraction() -> void:
	# Stored as a COOLDOWN scale, so it can approach zero without ever reaching
	# it. At level 75 the player fires ~1.74x as often, not infinitely often —
	# was ~2.11x before the 2026-08-03 cut (DRIP_FIRE_RATE 0.015 -> 0.010).
	var scale: float = Progression.drip_cooldown_mult(75)
	assert_almost_eq(1.0 / scale, 1.74, 0.01)
	assert_gt(Progression.drip_cooldown_mult(500), 0.0,
			"an endless run can never reach a zero cooldown")


func test_move_speed_drip_is_capped() -> void:
	# The one drip with a ceiling. Damage and fire rate make the player stronger;
	# move speed makes them un-hittable, and past that every difficulty number
	# downstream is decoration. Cap lands at level 68 (0.003 x 67).
	assert_almost_eq(Progression.drip_move_speed_mult(67), 1.198, 0.0001)
	assert_almost_eq(Progression.drip_move_speed_mult(68), 1.20, 0.0001)
	assert_almost_eq(Progression.drip_move_speed_mult(200), 1.20, 0.0001,
			"deep endless must not outrun every enemy in the game")


## Levels reached by spending `total` XP from level 1, the way the run does it.
func _level_for_xp(total: int) -> int:
	var level: int = 1
	var spent: int = 0
	while spent + Progression.xp_required(level) <= total:
		spent += Progression.xp_required(level)
		level += 1
	return level


# --- level-up toast lines ----------------------------------------------------
# The shipped bug these pin: `main.gd` snapshotted the drip AFTER incrementing
# `level`, so both sides of the delta were the same level. Every toast said
# "+0.0% FIRE RATE" and no level ever reported damage or projectiles.

func test_a_level_up_always_reports_something_nonzero() -> void:
	# Every level from 2 to 60 must produce at least one line, and no line may
	# claim a zero gain. "+0.0% FIRE RATE" is the exact string that shipped.
	for to_level: int in range(2, 61):
		var gains: Array[String] = Progression.drip_gains(to_level - 1, to_level)
		assert_gt(gains.size(), 0, "level %d says nothing" % to_level)
		for line: String in gains:
			assert_false(line.contains("+0.0%"), "level %d: '%s'" % [to_level, line])
			assert_false(line.begins_with("+0 "), "level %d: '%s'" % [to_level, line])


func test_the_same_level_twice_is_the_bug_and_yields_zero() -> void:
	# Directly encodes the defect: if a caller ever passes one level as both
	# ends again, the fire-rate fallback computes exactly 0.0% -- which is what
	# the player saw. Kept so the failure is named rather than merely absent.
	var gains: Array[String] = Progression.drip_gains(7, 7)
	assert_eq(gains, ["+0.0% FIRE RATE"] as Array[String])


func test_damage_and_projectile_steps_are_reported_when_they_land() -> void:
	# Find the first level where the damage bonus actually steps, and assert the
	# toast headlines it instead of falling through to fire rate.
	var stepped: int = -1
	for lvl: int in range(2, 61):
		if Progression.drip_damage_bonus(lvl) > Progression.drip_damage_bonus(lvl - 1):
			stepped = lvl
			break
	assert_gt(stepped, 0, "damage never steps in 60 levels")
	var gains: Array[String] = Progression.drip_gains(stepped - 1, stepped)
	assert_true(gains[0].contains("DAMAGE"), "level %d headlines: %s" % [stepped, str(gains)])
