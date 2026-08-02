extends GutTest
## Damage application and XP values — the acceptance criterion M3 declared and
## never delivered. Everything here is pure: enemy HP scaling and XP rounding
## were extracted out of Enemy/Main precisely so they could be tested without
## instancing a scene (hub D12: logic only, never scenes).


func _stats(max_hp: int, xp_value: int = 3) -> EnemyStats:
	var s := EnemyStats.new()
	s.id = &"test"
	s.max_hp = max_hp
	s.xp_value = xp_value
	return s


## Hits needed to kill, mirroring Enemy.take_hit: damage subtracts, death at <= 0.
func _shots_to_kill(hp: int, damage: int) -> int:
	return ceili(float(hp) / float(damage))


# --- enemy HP scaling -------------------------------------------------------

func test_effective_hp_is_base_hp_at_run_start() -> void:
	assert_eq(_stats(3).effective_hp(Difficulty.hp_mult(0.0)), 3)


func test_effective_hp_scales_with_the_difficulty_curve() -> void:
	# hp_mult steps +0.5 every 45s, so at t=45 a 4 HP enemy has 6.
	assert_eq(Difficulty.hp_mult(45.0), 1.5)
	assert_eq(_stats(4).effective_hp(1.5), 6)


func test_effective_hp_rounds_rather_than_truncates() -> void:
	# 3 * 1.5 = 4.5 must not silently become 4.
	assert_eq(_stats(3).effective_hp(1.5), 5)
	assert_eq(_stats(1).effective_hp(1.5), 2)


func test_effective_hp_never_drops_below_one() -> void:
	# A sub-1 result would round to 0 and make the enemy unkillable — take_hit
	# early-returns on hp <= 0, so it would never emit died and never free.
	assert_eq(_stats(1).effective_hp(0.4), 1)
	assert_eq(_stats(2).effective_hp(0.0), 1)


# --- damage application -----------------------------------------------------

func test_one_damage_kills_a_one_hp_enemy() -> void:
	assert_eq(_shots_to_kill(_stats(1).effective_hp(1.0), 1), 1)


func test_overkill_damage_still_takes_one_hit() -> void:
	assert_eq(_shots_to_kill(_stats(3).effective_hp(1.0), 99), 1)


func test_shots_to_kill_scales_with_enemy_hp_not_damage_alone() -> void:
	var hp: int = _stats(3).effective_hp(Difficulty.hp_mult(90.0))  # mult 2.0 -> 6 HP
	assert_eq(hp, 6)
	assert_eq(_shots_to_kill(hp, 1), 6)
	assert_eq(_shots_to_kill(hp, 2), 3)
	assert_eq(_shots_to_kill(hp, 4), 2, "partial damage still requires a second hit")


func test_damage_curve_keeps_the_base_enemy_killable_late() -> void:
	# At 5 minutes a chaser must not be a sponge for a player who took no damage
	# upgrades — this is the balance assumption the 5:00 boss depends on.
	var hp: int = _stats(3).effective_hp(Difficulty.hp_mult(300.0))
	assert_lt(_shots_to_kill(hp, 1), 25, "base weapon still kills a chaser in under 25 shots at 5min")


# --- XP values --------------------------------------------------------------

func test_xp_gain_is_base_value_without_multiplier() -> void:
	assert_eq(Progression.xp_gain(3, 1.0), 3)


func test_xp_gain_applies_and_rounds_the_multiplier() -> void:
	assert_eq(Progression.xp_gain(3, 1.25), 4)   # 3.75 rounds up
	assert_eq(Progression.xp_gain(4, 1.25), 5)
	assert_eq(Progression.xp_gain(10, 1.5), 15)


func test_xp_gain_never_returns_zero() -> void:
	# A gem worth nothing is a gem that reads as a bug to the player.
	assert_eq(Progression.xp_gain(1, 0.1), 1)
	assert_eq(Progression.xp_gain(3, 0.0), 1)


func test_xp_from_a_kill_feeds_the_level_curve() -> void:
	# Level 1 needs 5 XP; a chaser gives 3, so two kills level you up with 1 banked.
	var per_kill: int = Progression.xp_gain(_stats(3, 3).xp_value, 1.0)
	assert_eq(per_kill, 3)
	assert_gt(per_kill * 2, Progression.xp_required(1))
	assert_eq(per_kill * 2 - Progression.xp_required(1), 1, "1 XP carries into level 2")
