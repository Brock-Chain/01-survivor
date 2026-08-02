extends GutTest
## The pool must be fair, respect stack caps, and be seed-reproducible —
## the properties every future card/relic draw in V2/V3 will also need.


func _mk(id: String, weight: float = 1.0, max_stacks: int = 5) -> UpgradeResource:
	var u := UpgradeResource.new()
	u.id = StringName(id)
	u.display_name = id
	u.weight = weight
	u.max_stacks = max_stacks
	return u


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _pool(upgrades: Array[UpgradeResource], seed_value: int = 1234) -> UpgradePool:
	return UpgradePool.new(upgrades, _seeded_rng(seed_value))


func test_draw_returns_distinct_upgrades() -> void:
	var ups: Array[UpgradeResource] = [_mk("a"), _mk("b"), _mk("c"), _mk("d"), _mk("e")]
	var offers := _pool(ups).draw(3, {})
	assert_eq(offers.size(), 3)
	var ids := offers.map(func(u: UpgradeResource) -> StringName: return u.id)
	assert_eq(ids.size(), 3)
	assert_true(ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], "all distinct")


func test_maxed_stacks_are_never_offered() -> void:
	var ups: Array[UpgradeResource] = [_mk("a", 1.0, 2), _mk("b"), _mk("c"), _mk("d")]
	var offers := _pool(ups).draw(4, {&"a": 2})
	assert_eq(offers.size(), 3, "maxed 'a' excluded")
	for u: UpgradeResource in offers:
		assert_ne(u.id, &"a")


func test_returns_fewer_when_not_enough_eligible() -> void:
	var ups: Array[UpgradeResource] = [_mk("a", 1.0, 1), _mk("b"), _mk("c")]
	var offers := _pool(ups).draw(3, {&"a": 1})
	assert_eq(offers.size(), 2)


func test_same_seed_same_draws() -> void:
	var ups_a: Array[UpgradeResource] = [_mk("a"), _mk("b"), _mk("c"), _mk("d"), _mk("e")]
	var ups_b: Array[UpgradeResource] = [_mk("a"), _mk("b"), _mk("c"), _mk("d"), _mk("e")]
	var first := _pool(ups_a, 99).draw(3, {})
	var second := _pool(ups_b, 99).draw(3, {})
	for i: int in 3:
		assert_eq(first[i].id, second[i].id, "seeded draw %d matches" % i)


func test_weights_bias_the_draw() -> void:
	var heavy_first: int = 0
	for seed_value: int in 100:
		var ups: Array[UpgradeResource] = [_mk("common", 100.0), _mk("rare", 0.01)]
		var offers := _pool(ups, seed_value).draw(1, {})
		if offers[0].id == &"common":
			heavy_first += 1
	assert_gt(heavy_first, 90, "weight-100 picked first in >90/100 seeds")
