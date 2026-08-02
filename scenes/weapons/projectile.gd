class_name Projectile
extends Area2D
## Straight-flying bullet. Dies on first enemy hit or when its lifetime ends —
## lifetime is the leak-guard: nothing lives forever off-screen.

const LIFETIME: float = 1.2

var direction: Vector2 = Vector2.RIGHT
var speed: float = 340.0
var damage: int = 1
## Extra enemies this shot survives before dying.
var pierce: int = 0

var _life: float = LIFETIME


func setup(p_direction: Vector2, p_speed: float, p_damage: int,
		p_pierce: int = 0, crit: bool = false) -> void:
	direction = p_direction
	speed = p_speed
	damage = p_damage
	pierce = p_pierce
	rotation = direction.angle()
	if crit:
		scale = Vector2.ONE * 1.7  # a crit you cannot see is a crit that did not happen


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:
		(body as Enemy).take_hit(damage)
		if pierce <= 0:
			queue_free()
			return
		pierce -= 1
