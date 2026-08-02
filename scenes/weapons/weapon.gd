class_name Weapon
extends Node2D
## Auto-fires at the nearest enemy in range. Multi-shot fans out in a small
## spread. Reads everything from the player's Stats — upgrades tune it live.

const RANGE: float = 260.0
const SPREAD_DEG: float = 7.0

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapons/projectile.tscn")

## Wired by Player (stats) and Main (container).
var stats: Stats
var container: Node2D
## Injected by Main so crit rolls stay part of the seeded run.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	if stats == null or container == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target: Enemy = _nearest_enemy()
	if target == null:
		return
	_fire_at(target)
	_cooldown = stats.fire_interval


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_d: float = RANGE * RANGE
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null:
			continue
		var d: float = global_position.distance_squared_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _fire_at(target: Enemy) -> void:
	Sfx.play(&"shoot", -10.0)
	var base_dir: Vector2 = (target.global_position - global_position).normalized()
	var count: int = stats.projectile_count
	var crit: bool = stats.crit_chance > 0.0 and rng.randf() < stats.crit_chance
	var damage: int = roundi(stats.damage * stats.crit_mult) if crit else stats.damage
	for i: int in count:
		var offset_deg: float = (i - (count - 1) / 2.0) * SPREAD_DEG
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		projectile.setup(base_dir.rotated(deg_to_rad(offset_deg)), stats.projectile_speed,
				damage, stats.pierce, crit)
		projectile.position = global_position
		container.add_child(projectile)
