class_name Enemy
extends CharacterBody2D
## Chases its target. All numbers come from an EnemyStats resource —
## new enemy types are .tres files, not new scripts.

signal died(xp_value: int, at: Vector2, tint: Color)

const FLASH_TIME: float = 0.12

var stats: EnemyStats
var hp: int
var target: Node2D

@onready var visual: Sprite2D = $Visual
@onready var shape: CollisionShape2D = $CollisionShape2D


## Called by the spawner before add_child (so _ready sees everything).
func setup(p_stats: EnemyStats, p_target: Node2D, hp_mult: float = 1.0) -> void:
	stats = p_stats
	target = p_target
	hp = maxi(1, roundi(stats.max_hp * hp_mult))


func _ready() -> void:
	# White base sprite tinted per type — color is content (EnemyStats), not code.
	visual.modulate = stats.tint
	visual.scale = Vector2.ONE * (stats.size / 16.0)
	var rect: RectangleShape2D = shape.shape
	rect.size = Vector2(stats.size - 2.0, stats.size - 2.0)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	velocity = (target.global_position - global_position).normalized() * stats.speed
	move_and_slide()


func take_hit(damage: int) -> void:
	if hp <= 0:
		return
	hp -= damage
	Sfx.play(&"hit", -8.0)
	if hp <= 0:
		died.emit(stats.xp_value, global_position, stats.tint)
		queue_free()
		return
	_flash()


func _flash() -> void:
	var mat: ShaderMaterial = visual.material
	mat.set_shader_parameter(&"flash", 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(mat, "shader_parameter/flash", 0.0, FLASH_TIME)
