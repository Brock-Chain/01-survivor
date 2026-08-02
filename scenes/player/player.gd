class_name Player
extends CharacterBody2D
## Movement, contact damage intake, and the stats/health the run mutates.
## Call down, signal up: Main listens to our signals; we never reach up.

signal died
signal health_changed(hp: int, max_hp: int)

## Weapon data. The orbital is gated behind beating the Prism.
const BLASTER_WEAPON: WeaponResource = preload("res://resources/weapons/blaster.tres")
const ORBITAL_WEAPON: WeaponResource = preload("res://resources/weapons/orbital.tres")

@export var stats: Stats

var health: Health
## Temporary power-up effects. Never written into Stats — a six-second buff
## leaking into a permanent modifier would be silent and unbounded.
var buffs: BuffState = BuffState.new()
## Pause-safe clock: accumulates physics time, used for i-frame windows.
var _time: float = 0.0

@onready var hurtbox: Area2D = $Hurtbox
@onready var magnet: Area2D = $Magnet
@onready var magnet_shape: CollisionShape2D = $Magnet/CollisionShape2D
@onready var visual: Sprite2D = $Visual
@onready var weapon: Weapon = $Weapon
@onready var orbitals: OrbitalWeapon = $Orbitals
@onready var camera: GameCamera = $Camera2D


func _ready() -> void:
	health = Health.new(stats.max_hp)
	health.changed.connect(func(hp: int, max_hp: int) -> void: health_changed.emit(hp, max_hp))
	health.died.connect(_on_died)
	weapon.stats = stats
	weapon.buffs = buffs
	weapon.resource = BLASTER_WEAPON
	magnet.area_entered.connect(_on_magnet_area_entered)
	refresh_from_stats()
	health_changed.emit(health.hp, health.max_hp)


func _on_magnet_area_entered(area: Area2D) -> void:
	if area is XpGem:
		(area as XpGem).attract(self)


func _physics_process(delta: float) -> void:
	_time += delta
	for expired: StringName in buffs.tick(delta):
		if expired == BuffState.SHIELD:
			Sfx.play(&"click", -4.0)
	health.shielded = buffs.has(BuffState.SHIELD)
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * stats.move_speed
	move_and_slide()
	_check_contact_damage()
	_update_invuln_visual()


## Main calls this once, after _ready. Unlocks are passed DOWN rather than read
## from the Meta autoload: reaching up couples the player scene to save state and
## makes the whole scene chain uncompilable in a tool script (authoring the Shard
## died on "Identifier not found: Meta"). Same rule as the Resources.
func apply_unlocks(unlocks: Array[StringName]) -> void:
	orbitals.setup(stats, ORBITAL_WEAPON, unlocks)


## Re-read anything derived from stats. Main calls this after upgrades apply.
func refresh_from_stats() -> void:
	var circle: CircleShape2D = magnet_shape.shape
	circle.radius = stats.magnet_radius
	orbitals.refresh()


func _check_contact_damage() -> void:
	if health.is_invulnerable(_time):
		return
	for body: Node2D in hurtbox.get_overlapping_bodies():
		if body is Enemy:
			if apply_damage((body as Enemy).damage, &"contact"):
				break


## Public damage entry point. Contact damage and enemy projectiles both come
## through here so i-frames, the hurt cue and screenshake can never disagree.
## Returns true if the damage actually landed.
func apply_damage(amount: int, source: StringName = &"unknown") -> bool:
	if not health.take_damage(amount, _time):
		return false
	Telemetry.event(&"damage", {"amt": amount, "hp": health.hp,
			"max_hp": health.max_hp, "src": String(source)})
	Sfx.play(&"hurt")
	camera.add_trauma(0.5)
	return true


func _update_invuln_visual() -> void:
	if health.shielded:
		# A shield must look different from i-frames, or the player cannot tell
		# "briefly safe" from "protected".
		visual.modulate = Color(0.6, 1.0, 1.0, 0.85 + 0.15 * sin(_time * 8.0))
		return
	visual.modulate.r = 1.0
	visual.modulate.g = 1.0
	visual.modulate.b = 1.0
	if health.is_invulnerable(_time):
		visual.modulate.a = 0.4 + 0.6 * absf(sin(_time * 30.0))
	else:
		visual.modulate.a = 1.0


func _on_died() -> void:
	set_physics_process(false)
	weapon.set_physics_process(false)
	visual.modulate = Color(0.4, 0.4, 0.4, 0.8)
	died.emit()
