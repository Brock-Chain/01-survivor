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


## HP this type spawns with under a difficulty multiplier. Pure, so the scaling
## curve is testable without instancing an Enemy. Never returns less than 1 —
## a rounding-down multiplier must never produce an unkillable 0-HP enemy.
func effective_hp(hp_mult: float) -> int:
	return maxi(1, roundi(max_hp * hp_mult))
