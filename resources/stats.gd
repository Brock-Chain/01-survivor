class_name Stats
extends Resource
## The player's mutable numbers, as data. Upgrades (M4) mutate these —
## keeping them in one Resource is the same pattern V3 uses for card stats.

@export var max_hp: int = 6
@export var move_speed: float = 130.0
@export var damage: int = 1
@export var fire_interval: float = 0.8
@export var projectile_count: int = 1
@export var projectile_speed: float = 340.0
@export var magnet_radius: float = 48.0
@export var xp_mult: float = 1.0
