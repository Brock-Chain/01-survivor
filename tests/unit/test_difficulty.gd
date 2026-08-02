extends GutTest
## Difficulty curves pinned at exact time points — retuning is allowed,
## but it must be a conscious edit of BOTH the curve and these numbers.


func test_spawn_interval_ramps_down_to_floor() -> void:
	assert_almost_eq(Difficulty.spawn_interval(0.0), 1.4, 0.001)
	assert_almost_eq(Difficulty.spawn_interval(60.0), 0.92, 0.001)
	assert_almost_eq(Difficulty.spawn_interval(120.0), 0.44, 0.001)
	assert_almost_eq(Difficulty.spawn_interval(600.0), 0.4, 0.001, "clamped at floor")


func test_hp_mult_steps_every_45s() -> void:
	assert_almost_eq(Difficulty.hp_mult(0.0), 1.0, 0.001)
	assert_almost_eq(Difficulty.hp_mult(44.9), 1.0, 0.001)
	assert_almost_eq(Difficulty.hp_mult(45.0), 1.5, 0.001)
	assert_almost_eq(Difficulty.hp_mult(180.0), 3.0, 0.001)


func test_fast_enemies_absent_then_ramp() -> void:
	assert_almost_eq(Difficulty.fast_ratio(0.0), 0.0, 0.001)
	assert_almost_eq(Difficulty.fast_ratio(119.9), 0.0, 0.001)
	assert_almost_eq(Difficulty.fast_ratio(120.0), 0.1, 0.001)
	assert_almost_eq(Difficulty.fast_ratio(270.0), 0.4, 0.001, "capped at 40%")
	assert_almost_eq(Difficulty.fast_ratio(9999.0), 0.4, 0.001)
