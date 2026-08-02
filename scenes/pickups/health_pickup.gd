class_name HealthPickup
extends Area2D
## Health as a WORLD DROP rather than a level-up option.
##
## Playtest, 2026-08-02: "getting a heal as a level reward option while at full
## health seems like poor game design." Correct — a reward you cannot use is a
## punished level-up. As a drop it is never wasted, because it only exists when
## you are already hurt, and it makes you MOVE to collect it, which is exactly
## the pressure the game was missing.
##
## Unlike an XP gem it is not magnetised and it expires: choosing whether the
## detour is worth it is the decision.

signal collected

const COLLECT_DIST: float = 14.0
const LIFETIME: float = 12.0
const FADE_AT: float = 3.0

var _target: Node2D
var _life: float = LIFETIME
var _bob_t: float = 0.0

@onready var visual: Sprite2D = $Visual


func setup(p_target: Node2D) -> void:
	_target = p_target


func _ready() -> void:
	_bob_t = randf() * TAU
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(visual, "scale", Vector2.ONE * 1.25, 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(visual, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	# Blink out over the last few seconds so "hurry" is legible, not a surprise.
	if _life < FADE_AT:
		visual.modulate.a = 0.35 + 0.65 * absf(sin(_life * 12.0))
	_bob_t += delta * 3.0
	visual.position.y = sin(_bob_t) * 2.0
	if is_instance_valid(_target) and global_position.distance_to(_target.global_position) <= COLLECT_DIST:
		collected.emit()
		queue_free()
