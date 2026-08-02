class_name Player
extends CharacterBody2D
## Movement, contact damage intake, and the stats/health the run mutates.
## Call down, signal up: Main listens to our signals; we never reach up.

signal died
signal health_changed(hp: int, max_hp: int)

@export var stats: Stats

var health: Health
## Pause-safe clock: accumulates physics time, used for i-frame windows.
var _time: float = 0.0

@onready var hurtbox: Area2D = $Hurtbox
@onready var magnet: Area2D = $Magnet
@onready var magnet_shape: CollisionShape2D = $Magnet/CollisionShape2D
@onready var visual: Sprite2D = $Visual
@onready var weapon: Weapon = $Weapon
@onready var camera: GameCamera = $Camera2D


func _ready() -> void:
	health = Health.new(stats.max_hp)
	health.changed.connect(func(hp: int, max_hp: int) -> void: health_changed.emit(hp, max_hp))
	health.died.connect(_on_died)
	weapon.stats = stats
	magnet.area_entered.connect(_on_magnet_area_entered)
	refresh_from_stats()
	health_changed.emit(health.hp, health.max_hp)


func _on_magnet_area_entered(area: Area2D) -> void:
	if area is XpGem:
		(area as XpGem).attract(self)


func _physics_process(delta: float) -> void:
	_time += delta
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * stats.move_speed
	move_and_slide()
	_check_contact_damage()
	_update_invuln_visual()


## Re-read anything derived from stats. Main calls this after upgrades apply.
func refresh_from_stats() -> void:
	var circle: CircleShape2D = magnet_shape.shape
	circle.radius = stats.magnet_radius


func _check_contact_damage() -> void:
	if health.is_invulnerable(_time):
		return
	for body: Node2D in hurtbox.get_overlapping_bodies():
		if body is Enemy:
			if apply_damage((body as Enemy).damage):
				break


## Public damage entry point. Contact damage and enemy projectiles both come
## through here so i-frames, the hurt cue and screenshake can never disagree.
## Returns true if the damage actually landed.
func apply_damage(amount: int) -> bool:
	if not health.take_damage(amount, _time):
		return false
	Sfx.play(&"hurt")
	camera.add_trauma(0.5)
	return true


func _update_invuln_visual() -> void:
	if health.is_invulnerable(_time):
		visual.modulate.a = 0.4 + 0.6 * absf(sin(_time * 30.0))
	else:
		visual.modulate.a = 1.0


func _on_died() -> void:
	set_physics_process(false)
	weapon.set_physics_process(false)
	visual.modulate = Color(0.4, 0.4, 0.4, 0.8)
	died.emit()
