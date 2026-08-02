class_name Enemy
extends CharacterBody2D
## Chases its target. All numbers come from an EnemyStats resource —
## new enemy types are .tres files, not new scripts.

signal died(xp_value: int, at: Vector2, tint: Color)

const FLASH_TIME: float = 0.12

var stats: EnemyStats
var hp: int
## Kept so subclasses can reason about proportional health (the boss's phase
## threshold) without re-deriving the difficulty multiplier.
var max_hp: int
var target: Node2D
var is_elite: bool = false
var damage: int = 1
var xp_value: int = 1

@onready var visual: Sprite2D = $Visual
@onready var shape: CollisionShape2D = $CollisionShape2D


## Called by the spawner before add_child (so _ready sees everything).
func setup(p_stats: EnemyStats, p_target: Node2D, hp_mult: float = 1.0,
		p_elite: bool = false) -> void:
	stats = p_stats
	target = p_target
	is_elite = p_elite
	var elite_hp: float = Difficulty.ELITE_HP_MULT if is_elite else 1.0
	max_hp = stats.effective_hp(hp_mult * elite_hp)
	hp = max_hp
	damage = stats.damage + (Difficulty.ELITE_DAMAGE_BONUS if is_elite else 0)
	xp_value = roundi(stats.xp_value * (Difficulty.ELITE_XP_MULT if is_elite else 1.0))


func _ready() -> void:
	# White base sprite tinted per type — color is content (EnemyStats), not code.
	visual.modulate = stats.tint
	var size: float = stats.size * (Difficulty.ELITE_SCALE if is_elite else 1.0)
	visual.scale = Vector2.ONE * (size / 16.0)
	var rect: RectangleShape2D = shape.shape
	rect.size = Vector2(size - 2.0, size - 2.0)
	if is_elite:
		_apply_elite_rim()


## Elites keep their archetype's hue and gain a pulsing bright rim: same
## silhouette, obviously more dangerous. No new sprite, no new colour.
func _apply_elite_rim() -> void:
	var rim := Sprite2D.new()
	rim.texture = visual.texture
	rim.modulate = Difficulty.ELITE_RIM
	rim.scale = Vector2.ONE * 1.35
	rim.z_index = -1
	add_child(rim)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(rim, "modulate:a", 0.35, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(rim, "modulate:a", 0.9, 0.5).set_trans(Tween.TRANS_SINE)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	velocity = (target.global_position - global_position).normalized() * stats.speed
	move_and_slide()


func take_hit(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	Sfx.play(&"hit", -8.0)
	if hp <= 0:
		died.emit(xp_value, global_position, stats.tint)
		queue_free()
		return
	_flash()


func _flash() -> void:
	var mat: ShaderMaterial = visual.material
	mat.set_shader_parameter(&"flash", 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(mat, "shader_parameter/flash", 0.0, FLASH_TIME)
