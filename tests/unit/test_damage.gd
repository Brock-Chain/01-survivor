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

## HP multipliers are authored per WAVE in tools/gen_waves.gd, not derived from a
## time curve — `Difficulty.hp_mult` was removed as dead code (review finding
## 20). These are the real shipped values: opening 1.0, swarm 2.0, endless_1 3.4.
const WAVE_OPENING: float = 1.0
const WAVE_SWARM: float = 2.0
const WAVE_ENDLESS_1: float = 3.4


func test_effective_hp_is_base_hp_at_run_start() -> void:
	assert_eq(_stats(3).effective_hp(WAVE_OPENING), 3)


func test_effective_hp_scales_with_the_wave_multiplier() -> void:
	assert_eq(_stats(4).effective_hp(1.5), 6)
	assert_eq(_stats(3).effective_hp(WAVE_SWARM), 6)


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
	var hp: int = _stats(3).effective_hp(WAVE_SWARM)  # 3 * 2.0 -> 6 HP
	assert_eq(hp, 6)
	assert_eq(_shots_to_kill(hp, 1), 6)
	assert_eq(_shots_to_kill(hp, 2), 3)
	assert_eq(_shots_to_kill(hp, 4), 2, "partial damage still requires a second hit")


func test_damage_curve_keeps_the_base_enemy_killable_late() -> void:
	# At 5 minutes a chaser must not be a sponge for a player who took no damage
	# upgrades — this is the balance assumption the 5:00 boss depends on, and it
	# is now pinned against the wave the run is actually in at that moment.
	var hp: int = _stats(3).effective_hp(WAVE_ENDLESS_1)
	assert_lt(_shots_to_kill(hp, 1), 25, "base weapon still kills a chaser in under 25 shots at 5min")


# --- multishot tax ----------------------------------------------------------

func test_volley_tax_is_neutral_at_a_weapons_base_count() -> void:
	# A weapon firing its authored number of projectiles pays nothing. The
	# scattergun's 5 pellets ARE its design; only growth the player bought is taxed.
	assert_almost_eq(Stats.volley_damage_mult(1, 1), 1.0, 0.001)
	assert_almost_eq(Stats.volley_damage_mult(5, 5), 1.0, 0.001)
	assert_almost_eq(Stats.volley_damage_mult(5, 3), 1.0, 0.001, "never a bonus")


func test_volley_damage_grows_sublinearly_with_projectile_count() -> void:
	# The whole point: total volley damage rises as sqrt(N), not N. The measured
	# failure was 8 projectiles x +19 damage multiplying into a 7-second boss.
	var total_at_8: float = 8.0 * Stats.volley_damage_mult(1, 8)
	assert_almost_eq(total_at_8, 2.83, 0.01, "8 projectiles deal ~2.8x, not 8x")
	assert_lt(total_at_8, 8.0, "must never scale linearly")
	assert_gt(total_at_8, 1.0, "must still be worth taking")


func test_volley_tax_still_rewards_every_extra_projectile() -> void:
	# Sub-linear must not mean non-monotonic: taking Split Shot has to be an
	# upgrade, or the card is a trap.
	var previous: float = 0.0
	for n: int in range(1, 13):
		var total: float = float(n) * Stats.volley_damage_mult(1, n)
		assert_gt(total, previous, "volley %d must beat volley %d" % [n, n - 1])
		previous = total


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
	# Level 1 needs 3 XP and a chaser gives 3, so the FIRST KILL levels you up —
	# and Progression.FIRST_CARD_LEVEL makes that first level-up a card screen.
	# Deliberate: the audience is a stranger's first ten minutes, and one kill
	# into the run they have been shown the entire loop. It cost three kills
	# before M7.2, when levels were 2.4x more expensive.
	var per_kill: int = Progression.xp_gain(_stats(3, 3).xp_value, 1.0)
	assert_eq(per_kill, 3)
	assert_eq(per_kill, Progression.xp_required(1), "one kill, one level, one card")
	assert_true(Progression.offers_card(2), "and that level-up must offer a card")
