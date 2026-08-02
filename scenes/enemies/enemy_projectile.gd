class_name EnemyProjectile
extends Area2D
## Boss and Lancer fire. Yellow by the colour law — nothing friendly is ever
## yellow, so "this can hurt me" reads before the shape does.
##
## Lifetime-capped like the player's projectile: a bullet that can outlive its
## shooter is an unbounded live set waiting to happen.

const LIFETIME: float = 6.0

var velocity: Vector2 = Vector2.ZERO
var damage: int = 1

var _life: float = LIFETIME


func setup(p_velocity: Vector2, p_damage: int) -> void:
	velocity = p_velocity
	damage = p_damage


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = velocity.angle() + PI * 0.5  # sprite points 'up'


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	global_position += velocity * delta


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).apply_damage(damage, &"bolt")
		queue_free()
