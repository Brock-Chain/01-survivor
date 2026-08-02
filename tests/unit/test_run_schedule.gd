extends GutTest
## The Run Director's contract, tested where it is pure. Wave selection and boss
## scheduling decide the shape of every run, so they must be assertable without
## playing for five minutes.


func _stats(id: String) -> EnemyStats:
	var s := EnemyStats.new()
	s.id = StringName(id)
	return s


func _wave(id: String, start: float, types: Array[EnemyStats] = [],
		weights: Array[float] = []) -> WaveResource:
	var w := WaveResource.new()
	w.id = StringName(id)
	w.start_time = start
	w.types = types
	w.weights = weights
	return w


func _schedule(waves: Array[WaveResource], interval: float = 300.0,
		cap: int = 3) -> RunSchedule:
	var s := RunSchedule.new()
	s.waves = waves
	s.boss_interval = interval
	s.max_concurrent_bosses = cap
	return s


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


# --- wave selection ---------------------------------------------------------

func test_wave_at_picks_the_last_started_wave() -> void:
	var s := _schedule([_wave("a", 0.0), _wave("b", 60.0), _wave("c", 130.0)])
	assert_eq(s.wave_at(0.0).id, &"a")
	assert_eq(s.wave_at(59.9).id, &"a")
	assert_eq(s.wave_at(60.0).id, &"b", "boundary is inclusive")
	assert_eq(s.wave_at(129.9).id, &"b")
	assert_eq(s.wave_at(9999.0).id, &"c", "last wave holds forever")


func test_wave_order_in_the_array_does_not_matter() -> void:
	var s := _schedule([_wave("c", 130.0), _wave("a", 0.0), _wave("b", 60.0)])
	assert_eq(s.wave_at(70.0).id, &"b", "selection is by start_time, not index")


func test_wave_at_returns_null_before_any_wave_starts() -> void:
	# Degrades to "nothing spawns" rather than erroring — the director's stated
	# failure mode for a schedule with a gap.
	assert_null(_schedule([_wave("a", 30.0)]).wave_at(0.0))


func test_empty_schedule_is_survivable() -> void:
	assert_null(_schedule([]).wave_at(100.0))


# --- boss scheduling --------------------------------------------------------

func test_first_boss_lands_at_the_interval_not_at_zero() -> void:
	var s := _schedule([], 300.0)
	assert_eq(s.boss_time(0), 300.0, "the 5:00 boss the prime directive needs")
	assert_eq(s.boss_time(1), 600.0)
	assert_eq(s.boss_time(2), 900.0)


func test_boss_count_grows_then_caps() -> void:
	var s := _schedule([], 300.0, 3)
	assert_eq(s.bosses_at_event(0), 1, "one Prism at 5:00")
	assert_eq(s.bosses_at_event(1), 2, "two at 10:00")
	assert_eq(s.bosses_at_event(2), 3)
	assert_eq(s.bosses_at_event(9), 3, "capped — endless stays readable")


func test_boss_cap_of_zero_still_spawns_one() -> void:
	# A misconfigured cap must not produce a boss event that spawns nothing and
	# therefore can never be cleared, softlocking the win condition.
	assert_eq(_schedule([], 300.0, 0).bosses_at_event(0), 1)


# --- weighted type selection ------------------------------------------------

func test_pick_type_returns_null_for_an_empty_wave() -> void:
	assert_null(_wave("empty", 0.0).pick_type(_rng(1)))


func test_missing_weights_default_to_uniform() -> void:
	var w := _wave("w", 0.0, [_stats("a"), _stats("b")] as Array[EnemyStats])
	assert_eq(w.weight_at(0), 1.0)
	assert_eq(w.weight_at(1), 1.0, "shorter weights array is legal")
	assert_eq(w.weight_at(5), 0.0, "out of range is zero, not an error")


func test_weights_bias_the_pick() -> void:
	var heavy: int = 0
	for seed_value: int in 60:
		var w := _wave("w", 0.0, [_stats("common"), _stats("rare")] as Array[EnemyStats],
				[100.0, 0.01] as Array[float])
		if w.pick_type(_rng(seed_value)).id == &"common":
			heavy += 1
	assert_gt(heavy, 55, "weight-100 dominates across seeds")


func test_same_seed_picks_the_same_type() -> void:
	var types: Array[EnemyStats] = [_stats("a"), _stats("b"), _stats("c")]
	var first := _wave("w", 0.0, types, [1.0, 1.0, 1.0] as Array[float]).pick_type(_rng(77))
	var second := _wave("w", 0.0, types, [1.0, 1.0, 1.0] as Array[float]).pick_type(_rng(77))
	assert_eq(first.id, second.id, "seeded runs must reproduce")
