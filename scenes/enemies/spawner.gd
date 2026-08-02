class_name Spawner
extends Node
## MECHANISM ONLY: places one enemy on a ring around the target, clamped into
## the arena. What spawns, how often, and how hard is the Run Director's policy.
##
## Split this way so pacing lives in .tres data the director reads, and this
## script never needs to change when the run's shape does.

signal enemy_spawned(enemy: Enemy)

const SPAWN_RADIUS: float = 380.0
const ARENA_MARGIN: float = 24.0

@export var enemy_scene: PackedScene

## Wired by Main at _ready (call down). `rng` is shared with the director so a
## seeded run reproduces both the spawn sequence and its placement.
var target: Node2D
var container: Node2D
var arena: Rect2
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func alive_count() -> int:
	return container.get_child_count() if is_instance_valid(container) else 0


## A point on the spawn ring, CLAMPED INTO THE ARENA. The clamp is the whole
## point: an unclamped ring position lands outside the walls on any angle facing
## a nearby edge, and a spawn that collides with walls is stuck there forever —
## permanently out of weapon range. Every ring placement goes through here.
func ring_position(angle: float) -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
	var pos: Vector2 = target.global_position + Vector2.RIGHT.rotated(angle) * SPAWN_RADIUS
	pos.x = clampf(pos.x, arena.position.x + ARENA_MARGIN, arena.end.x - ARENA_MARGIN)
	pos.y = clampf(pos.y, arena.position.y + ARENA_MARGIN, arena.end.y - ARENA_MARGIN)
	return pos


func spawn(stats: EnemyStats, hp_mult: float = 1.0, elite: bool = false) -> Enemy:
	if stats == null or enemy_scene == null:
		return null
	if not is_instance_valid(target) or not is_instance_valid(container):
		return null

	var pos: Vector2 = ring_position(rng.randf_range(0.0, TAU))

	var enemy: Enemy = enemy_scene.instantiate()
	enemy.setup(stats, target, hp_mult, elite)
	enemy.position = pos
	container.add_child(enemy)
	enemy_spawned.emit(enemy)
	return enemy
