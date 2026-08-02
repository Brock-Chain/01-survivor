extends GutTest
## Health is pure logic with injected time — these tests never touch the tree.


func test_damage_reduces_hp() -> void:
	var h := Health.new(6, 0.6)
	var applied := h.take_damage(2, 0.0)
	assert_true(applied, "damage should apply")
	assert_eq(h.hp, 4)


func test_iframes_block_then_expire() -> void:
	var h := Health.new(6, 0.6)
	h.take_damage(1, 0.0)
	assert_false(h.take_damage(1, 0.3), "inside i-frame window — blocked")
	assert_eq(h.hp, 5)
	assert_true(h.take_damage(1, 0.7), "after i-frame window — applies")
	assert_eq(h.hp, 4)


func test_hp_clamps_at_zero_and_died_fires_once() -> void:
	var h := Health.new(3, 0.0)
	watch_signals(h)
	h.take_damage(99, 0.0)
	assert_eq(h.hp, 0)
	assert_signal_emit_count(h, "died", 1)
	assert_false(h.take_damage(1, 10.0), "dead — no further damage")
	assert_signal_emit_count(h, "died", 1)


func test_heal_clamps_at_max_and_not_when_dead() -> void:
	var h := Health.new(6, 0.0)
	h.take_damage(3, 0.0)
	h.heal(99)
	assert_eq(h.hp, 6)
	h.take_damage(99, 1.0)
	h.heal(5)
	assert_eq(h.hp, 0, "healing the dead does nothing")


func test_raise_max_also_heals_by_amount() -> void:
	var h := Health.new(6, 0.0)
	h.take_damage(2, 0.0)
	h.raise_max(2)
	assert_eq(h.max_hp, 8)
	assert_eq(h.hp, 6)
