extends GutTest


func test_xp_curve_exact_values() -> void:
	assert_eq(Progression.xp_required(1), 5)
	assert_eq(Progression.xp_required(2), 9)
	assert_eq(Progression.xp_required(5), 21)
	assert_eq(Progression.xp_required(10), 41)


func test_curve_is_monotonic() -> void:
	for level: int in range(1, 30):
		assert_gt(Progression.xp_required(level + 1), Progression.xp_required(level))
