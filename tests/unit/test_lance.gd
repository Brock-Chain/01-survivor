extends GutTest
## The lance's hit test is pure geometry — pin it down without a scene.
## segment_hit(from, dir, length, half_width, point).


func test_point_on_the_line_hits() -> void:
	assert_true(LanceWeapon.segment_hit(
			Vector2.ZERO, Vector2.RIGHT, 300.0, 10.0, Vector2(150, 0)))


func test_point_inside_corridor_hits() -> void:
	assert_true(LanceWeapon.segment_hit(
			Vector2.ZERO, Vector2.RIGHT, 300.0, 10.0, Vector2(150, 9.9)))


func test_point_outside_corridor_misses() -> void:
	assert_false(LanceWeapon.segment_hit(
			Vector2.ZERO, Vector2.RIGHT, 300.0, 10.0, Vector2(150, 10.1)))


func test_point_beyond_range_misses() -> void:
	assert_false(LanceWeapon.segment_hit(
			Vector2.ZERO, Vector2.RIGHT, 300.0, 10.0, Vector2(320, 0)))


func test_point_behind_origin_misses() -> void:
	assert_false(LanceWeapon.segment_hit(
			Vector2.ZERO, Vector2.RIGHT, 300.0, 10.0, Vector2(-40, 0)))


func test_endpoint_cap_is_round() -> void:
	# Just past the tip but within half_width of the endpoint still counts —
	# the clamp caps the segment with a circle, not a wall.
	assert_true(LanceWeapon.segment_hit(
			Vector2.ZERO, Vector2.RIGHT, 300.0, 10.0, Vector2(306, 0)))


func test_diagonal_direction() -> void:
	var dir: Vector2 = Vector2.ONE.normalized()
	assert_true(LanceWeapon.segment_hit(
			Vector2(10, 10), dir, 200.0, 8.0, Vector2(110, 110)))
	assert_false(LanceWeapon.segment_hit(
			Vector2(10, 10), dir, 200.0, 8.0, Vector2(110, 140)))


func test_gated_weapons_respect_unlocks() -> void:
	var scatter: WeaponResource = load("res://resources/weapons/scattergun.tres")
	var lance: WeaponResource = load("res://resources/weapons/lance.tres")
	var blaster: WeaponResource = load("res://resources/weapons/blaster.tres")
	# A bare [] literal is an UNTYPED Array and trips the typed-argument check
	# at runtime (a debugger break, which stalls headless GUT at a prompt).
	var none: Array[StringName] = []
	var hunter: Array[StringName] = [MetaState.UNLOCK_ELITE_HUNTER]
	var proven: Array[StringName] = [MetaState.UNLOCK_ENDLESS_PROVEN]
	assert_false(scatter.is_available(none), "scattergun locked for a fresh profile")
	assert_false(lance.is_available(none), "lance locked for a fresh profile")
	assert_true(scatter.is_available(hunter))
	assert_true(lance.is_available(proven))
	assert_true(blaster.is_available(none), "blaster is always available")
