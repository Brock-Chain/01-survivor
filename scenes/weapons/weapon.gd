class_name Weapon
extends Node2D
## Auto-fires at the nearest enemy in range. Multi-shot fans out in a small
## spread. Reads everything from the player's Stats — upgrades tune it live.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapons/projectile.tscn")

## Wired by Player (stats) and Main (container).
var stats: Stats
var container: Node2D
## Base numbers. Injected by Player; upgrades never write to it.
var resource: WeaponResource
## Injected by Main so crit rolls stay part of the seeded run.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Temporary power-up multipliers, applied on top of Stats.
var buffs: BuffState

var _cooldown: float = 0.0
## Overclock: shots since the last mega-bolt.
var _shots: int = 0


func _physics_process(delta: float) -> void:
	if stats == null or container == null or resource == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target: Enemy = _nearest_enemy()
	if target == null:
		return
	_fire_at(target)
	_cooldown = resource.interval * stats.fire_rate_mult * _haste_mult()


## Haste halves the interval; Overcharge doubles damage. Both are temporary
## and read from BuffState, never from Stats.
func _haste_mult() -> float:
	return 0.5 if buffs != null and buffs.has(BuffState.HASTE) else 1.0


func _power_mult() -> float:
	return 2.0 if buffs != null and buffs.has(BuffState.POWER) else 1.0


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_d: float = resource.range * resource.range
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
	var count: int = maxi(1, resource.count + stats.projectile_bonus)
	_shots += 1
	var mega: bool = stats.overclock_every > 0 and _shots % stats.overclock_every == 0
	var crit: bool = stats.crit_chance > 0.0 and rng.randf() < stats.crit_chance
	var base_damage: int = maxi(1, roundi((resource.damage + stats.damage_bonus) * _power_mult()))
	var damage: int = roundi(base_damage * stats.crit_mult) if crit else base_damage
	for i: int in count:
		var offset_deg: float = (i - (count - 1) / 2.0) * resource.spread_deg
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		projectile.apply_effects(stats, mega)
		projectile.setup(base_dir.rotated(deg_to_rad(offset_deg)), resource.projectile_speed * stats.projectile_speed_mult,
				damage, stats.pierce, crit)
		projectile.position = global_position
		container.add_child(projectile)
