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


## For GATED weapon instances (the scattergun). Availability resolves ONCE, like
## OrbitalWeapon.setup — an unearned weapon must cost nothing per frame. The
## blaster's node never calls this; Player injects its resource directly.
func configure(p_resource: WeaponResource, unlocks: Array[StringName]) -> void:
	var ok: bool = p_resource.is_available(unlocks)
	resource = p_resource if ok else null
	set_physics_process(ok)


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
	var base_dir: Vector2 = (target.global_position - global_position).normalized()
	var count: int = maxi(1, resource.count + stats.projectile_bonus)
	_shots += 1
	var mega: bool = stats.overclock_every > 0 and _shots % stats.overclock_every == 0
	var crit: bool = stats.crit_chance > 0.0 and rng.randf() < stats.crit_chance
	# The cue is rolled with the shot: a crit must SOUND like it counted, or the
	# stat only exists in the damage numbers nobody is reading mid-swarm.
	Sfx.play(&"crit" if crit else resource.fire_sound, -9.0 if crit else -16.0)
	# Multishot is taxed here, not on the upgrade card, so EVERY source of extra
	# projectiles pays it and no future one can forget to. See
	# Stats.volley_damage_mult — without it, count and damage multiply and the
	# 5:00 boss dies in seven seconds.
	var spread_tax: float = Stats.volley_damage_mult(resource.count, count)
	var base_damage: int = maxi(1, roundi(
			(resource.damage + stats.damage_bonus) * _power_mult() * spread_tax))
	var damage: int = roundi(base_damage * stats.crit_mult) if crit else base_damage
	for i: int in count:
		var offset_deg: float = (i - (count - 1) / 2.0) * resource.spread_deg
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		projectile.apply_effects(stats, mega)
		projectile.setup(base_dir.rotated(deg_to_rad(offset_deg)), resource.projectile_speed * stats.projectile_speed_mult,
				damage, stats.pierce, crit)
		projectile.position = global_position
		container.add_child(projectile)
