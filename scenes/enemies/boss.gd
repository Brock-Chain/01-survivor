class_name Boss
extends Enemy
## THE PRISM — a hexagonal core orbited by three shards.
##
## Extends Enemy on purpose. To the rest of the game a boss must BE a very large
## enemy: the weapon's nearest-target query and the projectile's hit check both
## cast to Enemy, so anything that merely resembles one is untargetable AND
## invulnerable. (It shipped that way for one build; the boss spawned on time and
## simply could not be killed.) Inheriting means zero special cases in weapon,
## projectile, Main, the death burst, or the kill counter.
##
## EVERY attack is telegraphed — shards flare and a cue plays before anything can
## damage you. Untelegraphed damage violates BRIEF defect #4 ("a run that ends
## without the player understanding why"), which is the entire reason the boss
## exists rather than a bigger chaser.
##
## Two phases, not three. Deliberately scoped to ship finished, not ambitious.

signal phase_changed(phase: int)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

const SHARD_COUNT: int = 3
const SHARD_ORBIT: float = 40.0
const SHARD_SPIN: float = 1.15

## Long enough to actually react to at player move speed.
const TELEGRAPH: float = 0.85
const P1_INTERVAL: float = 3.1
const P2_INTERVAL: float = 2.1
const SPREAD_P1: int = 10
const SPREAD_P2: int = 14
const BOLT_SPEED: float = 108.0
const DASH_SPEED: float = 250.0
const DASH_TIME: float = 0.55

@export var boss_stats: EnemyStats

var phase: int = 1

var _shards: Array[Sprite2D] = []
var _spin: float = 0.0
var _attack_cd: float = 2.2
var _telegraph_left: float = 0.0
var _dash_left: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO


## Called by the director before add_child. Separate from Enemy.setup so the
## director never has to know the boss's stats resource.
func configure(p_target: Node2D, hp_mult: float = 1.0) -> void:
	setup(boss_stats, p_target, hp_mult, false)


func _ready() -> void:
	super._ready()
	_build_shards()


func _build_shards() -> void:
	for i: int in SHARD_COUNT:
		var shard := Sprite2D.new()
		shard.texture = visual.texture
		shard.modulate = stats.tint
		shard.scale = Vector2.ONE * 0.42
		shard.z_index = 1
		add_child(shard)
		_shards.append(shard)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	_spin += delta * SHARD_SPIN
	_orbit_shards()
	_move(delta)
	_attack(delta)


func _orbit_shards() -> void:
	for i: int in _shards.size():
		var shard: Sprite2D = _shards[i]
		if is_instance_valid(shard):
			shard.position = Vector2.RIGHT.rotated(
					_spin + TAU * float(i) / float(SHARD_COUNT)) * SHARD_ORBIT


func _move(delta: float) -> void:
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_dir * DASH_SPEED
	elif _telegraph_left > 0.0:
		velocity = Vector2.ZERO  # planting is part of the tell
	else:
		velocity = (target.global_position - global_position).normalized() * stats.speed
	move_and_slide()


func _attack(delta: float) -> void:
	if _telegraph_left > 0.0:
		_telegraph_left -= delta
		if _telegraph_left <= 0.0:
			_fire()
		return
	_attack_cd -= delta
	if _attack_cd <= 0.0:
		_begin_telegraph()


## The tell: shards flare to white and a cue plays. Nothing can hurt the player
## until this finishes.
func _begin_telegraph() -> void:
	_telegraph_left = TELEGRAPH
	Sfx.play(&"levelup", -12.0)
	for shard: Sprite2D in _shards:
		if not is_instance_valid(shard):
			continue
		var t: Tween = create_tween()
		t.tween_property(shard, "modulate", Color(1, 1, 1, 1), TELEGRAPH * 0.7)
		t.tween_property(shard, "modulate", stats.tint, TELEGRAPH * 0.3)


func _fire() -> void:
	var count: int = SPREAD_P1 if phase == 1 else SPREAD_P2
	# Offset the ring by half a step off the player's bearing, so a gap always
	# sits where they are standing and weaving is a real choice, not a coin flip.
	var base: float = (target.global_position - global_position).angle()
	for i: int in count:
		var angle: float = base + TAU * (float(i) + 0.5) / float(count)
		var bolt: EnemyProjectile = PROJECTILE_SCENE.instantiate()
		bolt.setup(Vector2.RIGHT.rotated(angle) * BOLT_SPEED, damage)
		bolt.global_position = global_position
		get_parent().add_child(bolt)
	if phase == 2:
		_dash_dir = (target.global_position - global_position).normalized()
		_dash_left = DASH_TIME
	_attack_cd = P1_INTERVAL if phase == 1 else P2_INTERVAL


func take_hit(amount: int) -> void:
	var was_alive: bool = hp > 0
	super.take_hit(amount)
	if was_alive and hp > 0 and phase == 1 and hp <= max_hp / 2:
		_enter_phase_two()


## Shards detach and are replaced by real spawns, so the arena gets busier
## exactly as the core gets more aggressive.
func _enter_phase_two() -> void:
	phase = 2
	_attack_cd = minf(_attack_cd, 1.0)
	for shard: Sprite2D in _shards:
		if is_instance_valid(shard):
			shard.queue_free()
	_shards.clear()
	phase_changed.emit(phase)
