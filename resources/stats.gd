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
## Extra enemies a shot punches through before dying.
@export var pierce: int = 0
@export var crit_chance: float = 0.0
@export var crit_mult: float = 2.5
## Chance per kill to recover 1 HP. Healing as a BUILD CHOICE rather than a
## level-up option, so it is never a wasted pick at full health.
@export var lifesteal_chance: float = 0.0
