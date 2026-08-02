class_name Spawner
extends Node
## Timer-free spawner: a cooldown accumulator driven by Difficulty curves.
## Spawns on a ring around the player, clamped into the arena.

signal enemy_spawned(enemy: Enemy)

const SPAWN_RADIUS: float = 380.0
const ARENA_MARGIN: float = 24.0

@export var enemy_scene: PackedScene
@export var chaser_stats: EnemyStats
@export var fast_stats: EnemyStats

## Wired by Main at _ready (call down).
var target: Node2D
var container: Node2D
var arena: Rect2

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _elapsed: float = 0.0
var _cooldown: float = 0.8


func _ready() -> void:
	rng.randomize()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	_elapsed += delta
	_cooldown -= delta
	if _cooldown <= 0.0:
		# At the cap we burn the cooldown without spawning, so the spawner
		# throttles itself instead of queueing a backlog to dump later.
		if Difficulty.should_spawn(container.get_child_count()):
			_spawn()
		_cooldown = Difficulty.spawn_interval(_elapsed)


func _spawn() -> void:
	var angle: float = rng.randf_range(0.0, TAU)
	var pos: Vector2 = target.global_position + Vector2.RIGHT.rotated(angle) * SPAWN_RADIUS
	pos.x = clampf(pos.x, arena.position.x + ARENA_MARGIN, arena.end.x - ARENA_MARGIN)
	pos.y = clampf(pos.y, arena.position.y + ARENA_MARGIN, arena.end.y - ARENA_MARGIN)

	var stats: EnemyStats = chaser_stats
	if fast_stats != null and rng.randf() < Difficulty.fast_ratio(_elapsed):
		stats = fast_stats

	var enemy: Enemy = enemy_scene.instantiate()
	enemy.setup(stats, target, Difficulty.hp_mult(_elapsed))
	enemy.position = pos
	container.add_child(enemy)
	enemy_spawned.emit(enemy)
