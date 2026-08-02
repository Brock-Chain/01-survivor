class_name EnemyStats
extends Resource
## One .tres per enemy type — new enemies are content, not code.

## How this type behaves. RANGED is what makes standing still stop working:
## playtest 2026-08-02 found the player could hold position all run, because
## every enemy walked into the auto-weapon's fire.
enum Behavior { CHASE, RANGED }

@export var id: StringName
@export var behavior: Behavior = Behavior.CHASE
## Per-type silhouette. Null keeps the scene's default (the Drifter hexagon).
@export var sprite: Texture2D
## RANGED only: distance it tries to hold, and how often it fires.
@export var attack_range: float = 190.0
@export var attack_interval: float = 2.4
@export var bolt_speed: float = 135.0
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
