class_name EnemyStats
extends Resource
## One .tres per enemy type — new enemies are content, not code.

## How a type behaves.
##
## RANGED is what makes standing still stop working: playtest 2026-08-02 found
## the player could hold position all run, because every enemy walked into the
## auto-weapon's fire. CHARGE punishes the opposite habit — sitting in an open
## lane — by committing to a straight dash it cannot steer out of.
enum Behavior { CHASE, RANGED, CHARGE }

@export var id: StringName
@export var behavior: Behavior = Behavior.CHASE
@export var max_hp: int = 3
@export var speed: float = 55.0
@export var damage: int = 1
@export var xp_value: int = 3
@export var tint: Color = Color(0.9, 0.3, 0.3)
@export var size: float = 14.0

## Per-type silhouette. Null keeps the scene's default (the Drifter square).
@export var sprite: Texture2D

## Rotate the sprite to point along travel. For DIRECTIONAL silhouettes only —
## the Ram's wedge is drawn pointing up and is unreadable at any other angle. A
## shape that turns is also the cheapest possible "this one is aimed at you".
## Radially symmetric types (square, octagon, diamond) leave this false: spinning
## them would read as a bug.
##
## THE DART TURNED THIS OFF on 2026-08-03, and the reason generalises. Playtest:
## "orange dart looks more like a projectile". It did, and the neon pass did not
## fix it — a 1:1 crop showed the Dart still reading as a tracer round with the
## glow on. The cause was never colour. A small pointed shape ROTATED ALONG ITS
## VELOCITY is the visual grammar of a bullet, and the Dart had every part of it:
## needle silhouette, warm hue, 16px, aimed where it was going.
##
## So the rule this flag now follows: **bolts point where they travel, bodies do
## not.** Facing is reserved for a shape whose ROTATION IS A TELEGRAPH the player
## must read (the Ram's wind-up). Spending it on a plain chaser buys a little
## "flying at you" and pays for it by making that chaser look like ammunition.
@export var faces_travel: bool = false

## Per-type scene, as a PATH rather than a PackedScene. Empty uses the spawner's
## default. Set this when a type needs BEHAVIOUR the shared Enemy script lacks —
## the Shard is a shrunken Prism, so it wants boss.gd, not a new archetype.
##
## A path, not a typed PackedScene, because an authoring tool that only wants to
## write numbers would otherwise have to LOAD the whole gameplay scene graph —
## and that chain reaches player.gd, which legitimately uses autoloads that do
## not exist in a `-s` tool run. Autoloads in node scripts are fine; pulling node
## scripts into a data tool is not.
@export_file("*.tscn") var scene_path: String = ""

## Maximum of this type alive at once. 0 = unlimited. Exists because a type can
## be fun in small numbers and miserable in a swarm.
@export var max_alive: int = 0

@export_group("Death payload")
## What this leaves behind when it dies (the Splitter). A path, for the same
## reason `scene_path` is one.
@export_file("*.tres") var split_into_path: String = ""
@export var split_count: int = 0

@export_group("Ranged")
## RANGED only: the distance it tries to hold, and how often it fires.
@export var attack_range: float = 190.0
@export var attack_interval: float = 2.4
@export var bolt_speed: float = 135.0

@export_group("Charge")
## CHARGE only. Telegraph, then a fast straight dash, then a recovery it cannot
## steer through — the recovery IS the counterplay. A charger that could turn
## mid-dash would be unavoidable; one that never committed would just be a
## slightly faster chaser.
@export var charge_range: float = 210.0
@export var charge_telegraph: float = 0.65
@export var charge_speed: float = 430.0
@export var charge_time: float = 0.42
@export var charge_recover: float = 0.9

var _scene_cache: PackedScene
var _split_cache: Resource


## HP this type spawns with under a difficulty multiplier. Pure, so the scaling
## curve is testable without instancing an Enemy. Never returns less than 1 —
## a rounding-down multiplier must never produce an unkillable 0-HP enemy.
func effective_hp(hp_mult: float) -> int:
	return maxi(1, roundi(max_hp * hp_mult))


## Resolved once, at runtime, where the autoloads actually exist.
func resolve_scene() -> PackedScene:
	if scene_path.is_empty():
		return null
	if _scene_cache == null:
		_scene_cache = load(scene_path) as PackedScene
	return _scene_cache


func resolve_split() -> EnemyStats:
	if split_into_path.is_empty():
		return null
	if _split_cache == null:
		_split_cache = load(split_into_path)
	return _split_cache as EnemyStats
