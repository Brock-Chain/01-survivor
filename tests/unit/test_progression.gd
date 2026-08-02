extends GutTest
## The XP curve, pinned at exact values. Retuning it is allowed — but it must be
## a conscious edit of BOTH the curve and these numbers, never a drift. This
## test earned its place: it caught the 2026-08-02 superlinear change the moment
## it landed.


func test_xp_curve_exact_values() -> void:
	# Superlinear since 2026-08-02: `5 + 4n + 0.17n²`, n = level - 1.
	assert_eq(Progression.xp_required(1), 5, "the first level stays cheap")
	assert_eq(Progression.xp_required(2), 9)
	assert_eq(Progression.xp_required(5), 23)
	assert_eq(Progression.xp_required(10), 54)
	assert_eq(Progression.xp_required(20), 142)
	assert_eq(Progression.xp_required(30), 263)


func test_curve_is_monotonic() -> void:
	for level: int in range(1, 60):
		assert_gt(Progression.xp_required(level + 1), Progression.xp_required(level))


func test_late_levels_cost_meaningfully_more_than_early_ones() -> void:
	# The whole point of the change. Under the old flat curve level 30 cost 8x
	# level 1; telemetry showed level 57 reached in under six minutes, so a pick
	# cost nothing and a weak upgrade was noise rather than a rejection.
	var early: int = Progression.xp_required(1)
	var late: int = Progression.xp_required(30)
	assert_gt(float(late) / float(early), 40.0,
			"a level-30 pick must cost far more than a level-1 pick")


func test_total_xp_reaches_about_forty_levels_in_a_typical_run() -> void:
	# ~6000 XP is a measured five-to-six minute run. Tuned for ~30% fewer levels
	# than the flat curve, which reached 55.
	var total: int = 6000
	var level: int = 1
	var spent: int = 0
	while spent + Progression.xp_required(level) <= total:
		spent += Progression.xp_required(level)
		level += 1
	assert_between(level, 35, 43,
			"a 6000 XP run should land near level 39, not 55")
