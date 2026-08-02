class_name Orbital
extends Area2D
## One orbiting shard. Damages enemies on contact, with a PER-ENEMY cooldown so
## an orb resting against a slow tank does not delete it in a single frame —
## and, just as importantly, so damage does not scale with physics tick rate.

var damage: int = 1
var hit_interval: float = 0.45

## enemy instance id -> seconds until this orb may hit it again.
var _cooldowns: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _cooldowns.is_empty():
		return
	# Tick down and drop expired entries, so the dictionary cannot grow for the
	# whole run as enemies come and go.
	var expired: Array = []
	for key: int in _cooldowns:
		var left: float = float(_cooldowns[key]) - delta
		if left <= 0.0:
			expired.append(key)
		else:
			_cooldowns[key] = left
	for key: int in expired:
		_cooldowns.erase(key)
	# Enemies already overlapping never re-emit body_entered, so re-apply here.
	for body: Node2D in get_overlapping_bodies():
		if body is Enemy:
			_try_hit(body as Enemy)


func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:
		_try_hit(body as Enemy)


func _try_hit(enemy: Enemy) -> void:
	var key: int = enemy.get_instance_id()
	if _cooldowns.has(key):
		return
	_cooldowns[key] = hit_interval
	enemy.take_hit(damage)
