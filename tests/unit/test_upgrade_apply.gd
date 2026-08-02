extends GutTest
## Every Effect must mutate Stats exactly as its .tres description promises —
## the regression net for "adding upgrade #11 silently broke upgrade #4".


func _mk(effect: UpgradeResource.Effect, magnitude: float) -> UpgradeResource:
	var u := UpgradeResource.new()
	u.effect = effect
	u.magnitude = magnitude
	return u


func test_move_speed_is_multiplicative() -> void:
	var s := Stats.new()
	_mk(UpgradeResource.Effect.MOVE_SPEED, 0.12).apply_to(s)
	assert_almost_eq(s.move_speed, 130.0 * 1.12, 0.001)


func test_max_hp_and_damage_are_flat() -> void:
	var s := Stats.new()
	_mk(UpgradeResource.Effect.MAX_HP, 2.0).apply_to(s)
	_mk(UpgradeResource.Effect.DAMAGE, 1.0).apply_to(s)
	assert_eq(s.max_hp, 8)
	assert_eq(s.damage_bonus, 1, "a modifier, not an absolute")


func test_fire_rate_reduces_interval() -> void:
	var s := Stats.new()
	_mk(UpgradeResource.Effect.FIRE_RATE, 0.12).apply_to(s)
	assert_almost_eq(s.fire_rate_mult, 0.88, 0.001)


func test_projectiles_and_magnet_and_xp() -> void:
	var s := Stats.new()
	_mk(UpgradeResource.Effect.PROJECTILE_COUNT, 1.0).apply_to(s)
	_mk(UpgradeResource.Effect.PROJECTILE_SPEED, 0.2).apply_to(s)
	_mk(UpgradeResource.Effect.MAGNET, 28.0).apply_to(s)
	_mk(UpgradeResource.Effect.XP_GAIN, 0.15).apply_to(s)
	assert_eq(s.projectile_bonus, 1)
	assert_almost_eq(s.projectile_speed_mult, 1.2, 0.001)
	assert_almost_eq(s.magnet_radius, 76.0, 0.001)
	assert_almost_eq(s.xp_mult, 1.15, 0.001)


func test_heal_does_not_touch_stats() -> void:
	var s := Stats.new()
	var before_hp: int = s.max_hp
	_mk(UpgradeResource.Effect.HEAL, 3.0).apply_to(s)
	assert_eq(s.max_hp, before_hp, "HEAL is Main's job against Health, not Stats")


func test_stacking_compounds() -> void:
	var s := Stats.new()
	var boots := _mk(UpgradeResource.Effect.MOVE_SPEED, 0.12)
	boots.apply_to(s)
	boots.apply_to(s)
	assert_almost_eq(s.move_speed, 130.0 * 1.12 * 1.12, 0.001)
