class_name Enemy
extends CharacterBody2D
## Chases its target. All numbers come from an EnemyStats resource —
## new enemy types are .tres files, not new scripts.

signal died(xp_value: int, at: Vector2, tint: Color)

const FLASH_TIME: float = 0.12
const BOLT_SCENE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

var stats: EnemyStats
var hp: int
## Kept so subclasses can reason about proportional health (the boss's phase
## threshold) without re-deriving the difficulty multiplier.
var max_hp: int
var target: Node2D
var is_elite: bool = false
var damage: int = 1
var xp_value: int = 1
## Injected by the spawner. Falls back to our parent only if unset.
var bolt_container: Node2D
## Injected too, so a death payload can place its children.
var spawner: Spawner
var _shoot_cd: float = 0.0
## Cryo Rounds. Strongest slow wins and the longest duration wins, rather than
## stacking — otherwise sustained fire freezes everything solid.
var _slow_factor: float = 1.0
var _slow_left: float = 0.0
## CHARGE state: 0 stalking, 1 telegraphing, 2 dashing, 3 recovering.
var _charge_phase: int = 0
var _charge_t: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO

@onready var visual: Sprite2D = $Visual
@onready var shape: CollisionShape2D = $CollisionShape2D


## Called by the spawner before add_child (so _ready sees everything).
func setup(p_stats: EnemyStats, p_target: Node2D, hp_mult: float = 1.0,
		p_elite: bool = false) -> void:
	stats = p_stats
	target = p_target
	is_elite = p_elite
	var elite_hp: float = Difficulty.ELITE_HP_MULT if is_elite else 1.0
	max_hp = stats.effective_hp(hp_mult * elite_hp)
	hp = max_hp
	damage = stats.damage + (Difficulty.ELITE_DAMAGE_BONUS if is_elite else 0)
	xp_value = roundi(stats.xp_value * (Difficulty.ELITE_XP_MULT if is_elite else 1.0))


func _ready() -> void:
	# Silhouette and colour are both content (EnemyStats), never code.
	if stats.sprite != null:
		visual.texture = stats.sprite
	visual.modulate = stats.tint
	_shoot_cd = stats.attack_interval * randf_range(0.4, 1.0)
	var size: float = stats.size * (Difficulty.ELITE_SCALE if is_elite else 1.0)
	visual.scale = Vector2.ONE * (size / 16.0)
	var rect: RectangleShape2D = shape.shape
	rect.size = Vector2(size - 2.0, size - 2.0)
	if is_elite:
		_apply_elite_rim()


## Elites keep their archetype's hue and gain a pulsing bright rim: same
## silhouette, obviously more dangerous. No new sprite, no new colour.
func _apply_elite_rim() -> void:
	var rim := Sprite2D.new()
	rim.texture = visual.texture
	rim.modulate = Difficulty.ELITE_RIM
	rim.scale = Vector2.ONE * 1.35
	rim.z_index = -1
	add_child(rim)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(rim, "modulate:a", 0.35, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(rim, "modulate:a", 0.9, 0.5).set_trans(Tween.TRANS_SINE)


## Applied by a Cryo projectile.
func apply_slow(fraction: float, duration: float) -> void:
	_slow_factor = minf(_slow_factor, maxf(0.25, 1.0 - fraction))
	_slow_left = maxf(_slow_left, duration)
	visual.modulate = stats.tint.lerp(Color(0.55, 0.85, 1.0), 0.55)


func _tick_slow(delta: float) -> void:
	if _slow_left <= 0.0:
		return
	_slow_left -= delta
	if _slow_left <= 0.0:
		_slow_factor = 1.0
		visual.modulate = stats.tint


func speed_now() -> float:
	return stats.speed * _slow_factor


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	_tick_slow(delta)
	if stats.behavior == EnemyStats.Behavior.RANGED:
		_act_ranged(delta)
	elif stats.behavior == EnemyStats.Behavior.CHARGE:
		_act_charge(delta)
	else:
		velocity = (target.global_position - global_position).normalized() * speed_now()
	move_and_slide()


## Holds its preferred range and shoots. Backs off when crowded in, closes when
## too far — so the player cannot simply walk away from it either.
func _act_ranged(delta: float) -> void:
	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	var dir: Vector2 = to_target.normalized()
	if dist > stats.attack_range * 1.15:
		velocity = dir * speed_now()
	elif dist < stats.attack_range * 0.75:
		velocity = -dir * speed_now() * 0.8
	else:
		velocity = dir.orthogonal() * speed_now() * 0.35  # strafe, never static

	_shoot_cd -= delta
	if _shoot_cd <= 0.0 and dist <= stats.attack_range * 1.3:
		_shoot_cd = stats.attack_interval
		# Quiet: with several Lancers alive this fires constantly, and the cue's
		# job is "incoming from off-screen", not percussion.
		Sfx.play(&"bolt", -14.0)
		var bolt: EnemyProjectile = BOLT_SCENE.instantiate()
		bolt.setup(dir * stats.bolt_speed, damage)
		bolt.global_position = global_position
		_bolt_parent().add_child(bolt)


## Stalk, telegraph, dash, recover. The recovery is the point: a charger that
## could turn mid-dash would be unavoidable, and one that never committed would
## be a slightly faster chaser. Standing in an open lane is what it punishes.
func _act_charge(delta: float) -> void:
	_charge_t -= delta
	var to_target: Vector2 = target.global_position - global_position
	match _charge_phase:
		0:
			velocity = to_target.normalized() * speed_now()
			if to_target.length() <= stats.charge_range:
				_charge_phase = 1
				_charge_t = stats.charge_telegraph
				# Flare white: the tell has to be visible before it can be fair.
				visual.modulate = Color(1, 1, 1, 1)
		1:
			velocity = Vector2.ZERO  # planting is part of the tell
			if _charge_t <= 0.0:
				_charge_phase = 2
				_charge_t = stats.charge_time
				_charge_dir = to_target.normalized()
				visual.modulate = stats.tint
		2:
			velocity = _charge_dir * stats.charge_speed
			if _charge_t <= 0.0:
				_charge_phase = 3
				_charge_t = stats.charge_recover
		_:
			velocity = velocity.lerp(Vector2.ZERO, 6.0 * delta)
			if _charge_t <= 0.0:
				_charge_phase = 0


func _bolt_parent() -> Node:
	return bolt_container if is_instance_valid(bolt_container) else get_parent()


## `execute_below` is Executioner: an enemy left under that fraction of its max
## HP dies outright. Passed in per hit rather than read from a global, so the
## enemy stays ignorant of who shot it.
func take_hit(amount: int, execute_below: float = 0.0) -> void:
	if hp <= 0:
		return
	hp -= amount
	if hp > 0 and execute_below > 0.0 and float(hp) <= float(max_hp) * execute_below:
		hp = 0
	Sfx.play(&"hit", -8.0)
	if hp <= 0:
		_split()
		died.emit(xp_value, global_position, stats.tint)
		queue_free()
		return
	_flash()


## The Splitter's death payload. Deferred because this runs inside a physics
## callback, and adding physics bodies mid-flush is forbidden.
func _split() -> void:
	if stats.split_count <= 0 or spawner == null:
		return
	var child: EnemyStats = stats.resolve_split()
	if child == null:
		return
	var at: Vector2 = global_position
	for i: int in stats.split_count:
		var offset: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / float(stats.split_count)) * 12.0
		spawner.spawn_at.call_deferred(child, at + offset, 1.0, false)


func _flash() -> void:
	var mat: ShaderMaterial = visual.material
	mat.set_shader_parameter(&"flash", 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(mat, "shader_parameter/flash", 0.0, FLASH_TIME)
