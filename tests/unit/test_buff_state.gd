extends GutTest
## Temporary buffs. Pure, so the timing rules are assertable without a scene —
## and these rules are exactly the kind that break silently in play.


func test_a_granted_buff_is_active() -> void:
	var b := BuffState.new()
	assert_false(b.has(BuffState.SHIELD))
	b.grant(BuffState.SHIELD, 6.0)
	assert_true(b.has(BuffState.SHIELD))
	assert_almost_eq(b.remaining(BuffState.SHIELD), 6.0, 0.001)


func test_it_expires_and_reports_the_expiry_once() -> void:
	var b := BuffState.new()
	b.grant(BuffState.HASTE, 1.0)
	assert_eq(b.tick(0.5).size(), 0, "still running")
	var expired := b.tick(0.6)
	assert_eq(expired.size(), 1)
	assert_eq(expired[0], BuffState.HASTE)
	assert_false(b.has(BuffState.HASTE))
	assert_eq(b.tick(1.0).size(), 0, "expiry is reported once, not every tick")


func test_refreshing_takes_the_longer_duration() -> void:
	# Picking up a second shield with 5s left must never SHORTEN it.
	var b := BuffState.new()
	b.grant(BuffState.SHIELD, 6.0)
	b.tick(1.0)
	b.grant(BuffState.SHIELD, 2.0)
	assert_almost_eq(b.remaining(BuffState.SHIELD), 5.0, 0.001, "kept the longer one")
	b.grant(BuffState.SHIELD, 9.0)
	assert_almost_eq(b.remaining(BuffState.SHIELD), 9.0, 0.001, "took the longer one")


func test_durations_never_stack_into_permanence() -> void:
	var b := BuffState.new()
	for i: int in 10:
		b.grant(BuffState.SHIELD, 6.0)
	assert_almost_eq(b.remaining(BuffState.SHIELD), 6.0, 0.001,
			"ten pickups is still six seconds, not sixty")


func test_zero_or_negative_duration_grants_nothing() -> void:
	var b := BuffState.new()
	b.grant(BuffState.POWER, 0.0)
	b.grant(BuffState.POWER, -3.0)
	assert_false(b.has(BuffState.POWER))


func test_buffs_are_independent() -> void:
	var b := BuffState.new()
	b.grant(BuffState.SHIELD, 1.0)
	b.grant(BuffState.POWER, 5.0)
	b.tick(1.5)
	assert_false(b.has(BuffState.SHIELD))
	assert_true(b.has(BuffState.POWER), "one expiring must not clear the others")


func test_active_ids_are_ordered_longest_first() -> void:
	# A HUD listing these must not reshuffle every frame as the Dictionary rehashes.
	var b := BuffState.new()
	b.grant(BuffState.SHIELD, 2.0)
	b.grant(BuffState.POWER, 9.0)
	b.grant(BuffState.HASTE, 5.0)
	var ids := b.active_ids()
	assert_eq(ids[0], BuffState.POWER)
	assert_eq(ids[1], BuffState.HASTE)
	assert_eq(ids[2], BuffState.SHIELD)


func test_shield_blocks_damage_without_touching_the_dev_flag() -> void:
	var h := Health.new(6)
	h.shielded = true
	assert_false(h.take_damage(3, 0.0), "shield blocks")
	assert_eq(h.hp, 6)
	h.shielded = false
	assert_true(h.take_damage(3, 5.0), "and releases cleanly")
	assert_eq(h.hp, 3)
	assert_false(h.invincible, "the gameplay buff never wrote to the dev flag")
