class_name LanceWeapon
extends Node2D
## The third weapon: PRISM LANCE — an instant piercing beam.
##
## Locks the nearest enemy's bearing, then hits EVERYTHING along that line at
## once. A different verb from the other three: the blaster streams at one
## target, the scattergun cones up close, the orbitals hold a zone — the lance
## rewards lining enemies up, which no other weapon asks for.
##
## Instant rather than swept, drawn as a Line2D flash rather than a body: at
## 640x360 a thin travelling beam is unreadable, but a full-length flash that
## fades is unmissable. No physics nodes involved — the hit test is geometry
## against the enemies group, so it can never fight the physics flush.
##
## Unlocked by ENDLESS_PROVEN (surviving to the double boss): the flashiest
## weapon is the reward for the deepest run.

const BEAM_FADE: float = 0.22
## Half-width of the damage corridor. Slightly wider than the visual so a
## near-miss on screen still counts — generosity reads as accuracy here.
const HALF_WIDTH: float = 9.0

## Wired by Player (stats, buffs) and Main (rng — crit rolls stay seeded).
var stats: Stats
var buffs: BuffState
var resource: WeaponResource
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _cooldown: float = 0.0


func _ready() -> void:
	set_physics_process(false)


## Availability resolves ONCE — an unearned weapon costs nothing per frame.
func configure(p_resource: WeaponResource, unlocks: Array[StringName]) -> void:
	var ok: bool = p_resource.is_available(unlocks)
	resource = p_resource if ok else null
	set_physics_process(ok)


func _physics_process(delta: float) -> void:
	if stats == null or resource == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target: Enemy = _nearest_enemy()
	if target == null:
		return
	_fire((target.global_position - global_position).normalized())
	_cooldown = resource.interval * stats.fire_rate_mult * _haste_mult()


func _haste_mult() -> float:
	return 0.5 if buffs != null and buffs.has(BuffState.HASTE) else 1.0


func _power_mult() -> float:
	return 2.0 if buffs != null and buffs.has(BuffState.POWER) else 1.0


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_d: float = resource.range * resource.range
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null:
			continue
		var d: float = global_position.distance_squared_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _fire(dir: Vector2) -> void:
	var crit: bool = stats.crit_chance > 0.0 and rng.randf() < stats.crit_chance
	var base: int = maxi(1, roundi((resource.damage + stats.damage_bonus) * _power_mult()))
	var damage: int = roundi(base * stats.crit_mult) if crit else base
	Sfx.play(&"crit" if crit else resource.fire_sound, -8.0 if crit else -14.0)
	var length: float = resource.range
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null:
			continue
		# +6: roughly an enemy's half-size, so the corridor tests centers fairly.
		if segment_hit(global_position, dir, length, HALF_WIDTH + 6.0,
				enemy.global_position):
			# Pushed along the BEAM, not away from the muzzle: the lance's whole
			# identity is a line, so the shove should read as the line sweeping.
			enemy.take_hit(damage, stats.execute_below,
					enemy.global_position - dir * 24.0)
	_flash(dir, length, crit)


## True if `point` lies within `half_width` of the segment from..from+dir*length.
## Static and pure so the unit suite can pin the geometry down without a scene.
static func segment_hit(from: Vector2, dir: Vector2, length: float,
		half_width: float, point: Vector2) -> bool:
	var rel: Vector2 = point - from
	var t: float = clampf(rel.dot(dir), 0.0, length)
	return rel.distance_to(dir * t) <= half_width


## Two Line2Ds — a wide translucent body and a white-hot core — fading out
## together. Colour law: player damage is cyan, core burns to white.
func _flash(dir: Vector2, length: float, crit: bool) -> void:
	var width: float = HALF_WIDTH * (2.6 if crit else 2.0)
	_flash_line(dir, length, width, Color(0.30, 0.95, 1.0, 0.5))
	_flash_line(dir, length, width * 0.3, Color(1.0, 1.0, 1.0, 0.9))


func _flash_line(dir: Vector2, length: float, width: float, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2.ZERO, dir * length])
	line.width = width
	line.default_color = color
	add_child(line)
	var tween: Tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, BEAM_FADE)
	tween.tween_callback(line.queue_free)
