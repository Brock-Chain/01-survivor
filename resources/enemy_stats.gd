class_name EnemyStats
extends Resource
## One .tres per enemy type — new enemies are content, not code.

@export var id: StringName
@export var max_hp: int = 3
@export var speed: float = 55.0
@export var damage: int = 1
@export var xp_value: int = 3
@export var tint: Color = Color(0.9, 0.3, 0.3)
@export var size: float = 14.0
