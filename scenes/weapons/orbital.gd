class_name Orbital
extends Area2D
## One orbiting shard. Damages enemies on contact, with a PER-ENEMY cooldown so
## an orb resting against a slow tank does not delete it in a single frame —
## and, just as importantly, so damage does not scale with physics tick rate.

## Fired when this shard lands a killing blow, so the ring can feed on it. The
## weapon owns the momentum; a shard only reports what it did.
signal killed

var damage: int = 1
var hit_interval: float = 0.45
## Nova Orbit: detonation radius when an orbital lands the killing blow.
var nova_radius: float = 0.0

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
	var at: Vector2 = enemy.global_position
	# Shoved away from the ORB, which is what makes the ring read as a physical
	# barrier sweeping enemies aside rather than a damage aura.
	enemy.take_hit(damage, 0.0, global_position)
	if is_instance_valid(enemy):
		return
	killed.emit()
	# Detonate only on a KILL, not on every contact — a constant AoE would make
	# the orbital a lawnmower rather than a reward for finishing something off.
	if nova_radius > 0.0:
		_nova(at)


func _nova(at: Vector2) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var other: Enemy = node as Enemy
		if other != null and at.distance_to(other.global_position) <= nova_radius:
			other.take_hit(damage)
