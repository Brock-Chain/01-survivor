class_name PowerUp
extends Area2D
## A dropped power-up. Behaves like the health drop: not magnetised, and it
## EXPIRES — deciding whether the detour is worth it is the whole point. If it
## flew to you automatically there would be no decision.

signal collected(resource: PowerUpResource)

const COLLECT_DIST: float = 19.0
const LIFETIME: float = 14.0
const FADE_AT: float = 3.0

var resource: PowerUpResource

var _target: Node2D
var _life: float = LIFETIME
var _spin: float = 0.0

@onready var visual: Sprite2D = $Visual


func setup(p_resource: PowerUpResource, p_target: Node2D) -> void:
	resource = p_resource
	_target = p_target


func _ready() -> void:
	if resource != null:
		if resource.sprite != null:
			visual.texture = resource.sprite
		visual.modulate = resource.tint
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(visual, "scale", Vector2.ONE * 1.3, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(visual, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	# Slow rotation so it reads as "special" among static gems at a glance.
	_spin += delta * 1.4
	visual.rotation = _spin
	if _life < FADE_AT:
		visual.modulate.a = 0.35 + 0.65 * absf(sin(_life * 11.0))
	if is_instance_valid(_target) and global_position.distance_to(_target.global_position) <= COLLECT_DIST:
		collected.emit(resource)
		queue_free()
