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
## Per-type scene, as a PATH rather than a PackedScene. Empty uses the spawner's
## default. Set this when a type needs BEHAVIOUR the shared Enemy script lacks —
## the Shard is a shrunken Prism, so it wants boss.gd, not a new archetype.
##
## A path, not a typed PackedScene, because an authoring tool that only wants to
## write numbers would otherwise have to LOAD the whole gameplay scene graph —
## and that chain reaches player.gd, which legitimately uses the Sfx/Telemetry
## autoloads that do not exist in a `-s` tool run. Autoloads in node scripts are
## fine; pulling node scripts into a data tool is not.
@export_file("*.tscn") var scene_path: String = ""

var _scene_cache: PackedScene


## Resolved once, at runtime, where the autoloads actually exist.
func resolve_scene() -> PackedScene:
	if scene_path.is_empty():
		return null
	if _scene_cache == null:
		_scene_cache = load(scene_path) as PackedScene
	return _scene_cache
## Maximum of this type alive at once. 0 = unlimited. Exists because a type can
## be fun in small numbers and miserable in a swarm.
@export var max_alive: int = 0
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
