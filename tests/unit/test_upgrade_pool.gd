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


# --- unlock gating ----------------------------------------------------------

func _locked(id: String, requires: String) -> UpgradeResource:
	var u := _mk(id)
	u.requires_unlock = StringName(requires)
	return u


func test_locked_upgrades_stay_out_until_unlocked() -> void:
	var ups: Array[UpgradeResource] = [_locked("orbit", "orbital"), _mk("a"), _mk("b")]
	var offers := _pool(ups).draw(3, {})
	assert_eq(offers.size(), 2, "the locked one is not offerable")
	for u: UpgradeResource in offers:
		assert_ne(u.id, &"orbit")


func test_locked_upgrades_appear_once_unlocked() -> void:
	var ups: Array[UpgradeResource] = [_locked("orbit", "orbital"), _mk("a"), _mk("b")]
	var unlocks: Array[StringName] = [&"orbital"]
	assert_eq(_pool(ups).draw(3, {}, unlocks).size(), 3)


# --- twin cards -------------------------------------------------------------

func _described(id: String, text: String) -> UpgradeResource:
	var u := _mk(id)
	u.description = text
	return u


func test_cards_that_read_the_same_never_share_a_hand() -> void:
	# Split Shot (Rare) and Scatter (Uncommon) are both PROJECTILE_COUNT at
	# magnitude 1.0 with byte-identical text, and a level-29 hand offered both
	# (playtest 2026-08-03: "split shot and scatter same shit"). Two cards a player
	# cannot tell apart must not appear together, whatever their rarities say.
	var ups: Array[UpgradeResource] = [
		_described("split_shot", "+1 projectile · wider volleys hit softer"),
		_described("scatter", "+1 projectile · wider volleys hit softer"),
		_described("boots", "+14% move speed"),
	]
	var offers := _pool(ups).draw(3, {})
	assert_eq(offers.size(), 2, "the twin is dropped, not the whole pool")
	var texts := offers.map(func(u: UpgradeResource) -> String: return u.description)
	assert_true(texts[0] != texts[1], "no two offers read the same")


func test_blank_descriptions_do_not_collapse_the_pool() -> void:
	# A blank description is not evidence that two cards read alike. The first
	# version of the twin guard treated it as one, which cut every hand to a single
	# offer and took four of the tests above red with it.
	var ups: Array[UpgradeResource] = [_mk("a"), _mk("b"), _mk("c")]
	assert_eq(_pool(ups).draw(3, {}).size(), 3)


func test_unlimited_stacks_are_always_eligible() -> void:
	# The level-37 bug: with every upgrade capped, the pool ran dry and offered
	# nothing but a heal. max_stacks <= 0 must never exhaust.
	var endless := _mk("endless", 1.0, 0)
	assert_true(endless.is_eligible(0))
	assert_true(endless.is_eligible(500), "unlimited means unlimited")
	var capped := _mk("capped", 1.0, 2)
	assert_false(capped.is_eligible(2))
