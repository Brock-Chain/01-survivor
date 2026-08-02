class_name XpGem
extends Area2D
## Idles with a bob until the player's magnet wakes it, then accelerates
## home. Collects itself by distance — no second pickup area needed.

signal collected(xp_value: int)

const HOME_ACCEL: float = 900.0
const MAX_SPEED: float = 460.0
const COLLECT_DIST: float = 12.0

var xp_value: int = 1

var _target: Node2D
var _speed: float = 0.0
var _bob_t: float = 0.0

@onready var visual: Sprite2D = $Visual


func setup(p_xp_value: int) -> void:
	xp_value = p_xp_value


## Called by the player's magnet area. Idempotent.
func attract(target: Node2D) -> void:
	if _target == null:
		_target = target


func _ready() -> void:
	_bob_t = randf() * TAU
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(visual, "scale", Vector2.ONE * 1.15, 0.4).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(visual, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	if _target == null:
		_bob_t += delta * 3.0
		visual.position.y = sin(_bob_t) * 2.0
		return
	if not is_instance_valid(_target):
		_target = null
		return
	_speed = minf(_speed + HOME_ACCEL * delta, MAX_SPEED)
	var to_target: Vector2 = _target.global_position - global_position
	if to_target.length() <= COLLECT_DIST:
		collected.emit(xp_value)
		queue_free()
		return
	global_position += to_target.normalized() * _speed * delta
