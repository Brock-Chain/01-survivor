extends GutTest
## The seam between the level drip and the things that read it. Progression owns
## the numbers (test_progression pins those); this pins that every weapon and the
## player actually go THROUGH the seam, because the failure mode is silent — a
## call site that still reads `damage_bonus` directly just quietly misses two
## thirds of the player's level-ups and nothing errors.


func _at_level(level: int) -> Stats:
	var s := Stats.new()
	s.drip_damage_mult = Progression.drip_damage_mult(level)
	s.drip_cooldown_mult = Progression.drip_cooldown_mult(level)
	s.drip_move_speed_mult = Progression.drip_move_speed_mult(level)
	return s


func test_damage_from_folds_cards_and_drip() -> void:
	var s: Stats = _at_level(11)  # +15% damage
	s.damage_bonus = 3
	# A base-1 weapon with +3 from cards is 4, then the drip.
	assert_almost_eq(s.damage_from(1), 4.6, 0.001)
	# Float on the way out: the multishot and ring taxes still have to multiply
	# it, and rounding here would round three times per shot instead of once.
	assert_almost_eq(s.damage_from(5), 9.2, 0.001)


func test_cooldown_scale_folds_cards_and_drip() -> void:
	var s: Stats = _at_level(75)
	s.fire_rate_mult = 0.88  # one fire-rate card
	assert_almost_eq(s.cooldown_scale(), 0.88 * Progression.drip_cooldown_mult(75), 0.0001)
	assert_lt(s.cooldown_scale(), 0.88, "the drip can only make it faster")


func test_speed_folds_cards_and_capped_drip() -> void:
	var s: Stats = _at_level(200)  # deep endless, drip pinned at its cap
	s.move_speed = 130.0 * 1.12    # one pair of boots
	assert_almost_eq(s.speed(), 130.0 * 1.12 * 1.20, 0.001)


func test_a_fresh_stats_is_unchanged_by_the_seam() -> void:
	# Level 1, no cards: every helper must be the identity, or the drip has
	# silently moved the baseline the whole game is authored against.
	var s := Stats.new()
	assert_almost_eq(s.damage_from(1), 1.0, 0.0001)
	assert_almost_eq(s.cooldown_scale(), 1.0, 0.0001)
	assert_almost_eq(s.speed(), 130.0, 0.0001)
