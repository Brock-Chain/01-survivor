class_name Projectile
extends Area2D
## Straight-flying bullet. Dies on first enemy hit or when its lifetime ends —
## lifetime is the leak-guard: nothing lives forever off-screen.

const LIFETIME: float = 1.2

var direction: Vector2 = Vector2.RIGHT
var speed: float = 340.0
var damage: int = 1

var _life: float = LIFETIME


func setup(p_direction: Vector2, p_speed: float, p_damage: int) -> void:
	direction = p_direction
	speed = p_speed
	damage = p_damage
	rotation = direction.angle()


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
		queue_free()
