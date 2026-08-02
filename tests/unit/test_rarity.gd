extends GutTest
## Rarity odds and the pity floor. Pure, so the distribution is assertable
## without playing thirty runs to eyeball it.


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _sample(progress: float, n: int = 4000) -> Dictionary:
	var counts: Dictionary = {}
	var rng := _rng(4242)
	for i: int in n:
		var t: Rarity.Tier = Rarity.roll(rng, progress, 0)
		counts[t] = int(counts.get(t, 0)) + 1
	return counts


func test_common_dominates_early_and_recedes_late() -> void:
	var early := _sample(0.0)
	var late := _sample(1.0)
	assert_gt(float(early.get(Rarity.Tier.COMMON, 0)) / 4000.0, 0.5,
			"early runs are mostly Commons")
	assert_lt(float(late.get(Rarity.Tier.COMMON, 0)) / 4000.0,
			float(early.get(Rarity.Tier.COMMON, 0)) / 4000.0,
			"Commons must recede as the run progresses")


func test_legendaries_are_rare_but_reachable() -> void:
	var early := _sample(0.0)
	var late := _sample(1.0)
	var early_rate: float = float(early.get(Rarity.Tier.LEGENDARY, 0)) / 4000.0
	var late_rate: float = float(late.get(Rarity.Tier.LEGENDARY, 0)) / 4000.0
	assert_lt(early_rate, 0.02, "a level-2 Legendary should be a shock, not a Tuesday")
	assert_gt(late_rate, early_rate, "late runs must improve the odds")
	assert_lt(late_rate, 0.10, "still rare at full progress, or the word means nothing")


func test_progress_saturates() -> void:
	assert_almost_eq(Rarity.progress_for_level(1), 0.0, 0.001)
	assert_almost_eq(Rarity.progress_for_level(int(Rarity.PROGRESS_FULL_LEVEL)), 1.0, 0.001)
	assert_almost_eq(Rarity.progress_for_level(999), 1.0, 0.001,
			"a long endless run must not drift into all-Legendary screens")


func test_pity_floors_the_roll() -> void:
	# The cold streak is the worst thing a random reward can do, and it is
	# invisible in aggregate stats — so it gets a hard floor, not a hope.
	var rng := _rng(7)
	for i: int in 500:
		var t: Rarity.Tier = Rarity.roll(rng, 0.0, Rarity.PITY_LIMIT)
		assert_true(int(t) >= int(Rarity.PITY_TIER),
				"at the pity limit every roll is Rare or better")


func test_pity_below_the_limit_does_not_floor() -> void:
	var rng := _rng(11)
	var saw_common: bool = false
	for i: int in 500:
		if Rarity.roll(rng, 0.0, Rarity.PITY_LIMIT - 1) == Rarity.Tier.COMMON:
			saw_common = true
			break
	assert_true(saw_common, "pity must not trigger early")


func test_weights_lerp_between_the_two_ends() -> void:
	var mid := Rarity.weights(0.5)
	for i: int in Rarity.TIER_COUNT:
		var expected: float = (Rarity.EARLY[i] + Rarity.LATE[i]) * 0.5
		assert_almost_eq(mid[i], expected, 0.001)


func test_every_tier_has_a_name_a_colour_and_a_glow() -> void:
	for i: int in Rarity.TIER_COUNT:
		assert_ne(Rarity.name_of(i as Rarity.Tier), "")
		assert_true(Rarity.glow_of(i as Rarity.Tier) >= 0.0)
	assert_gt(Rarity.glow_of(Rarity.Tier.LEGENDARY), Rarity.glow_of(Rarity.Tier.COMMON),
			"glow is a second rarity channel so the ladder survives a screenshot")
