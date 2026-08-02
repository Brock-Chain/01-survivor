class_name OrbitalWeapon
extends Node2D
## The second weapon: cyan shards circling the player, damaging on contact.
##
## Chosen over a melee arc or chain lightning for three reasons that all still
## hold: it needs no facing direction (movement is 8-way and the player has
## none), it stays readable at 12px where a thin chain bolt would not, and its
## upgrade axes — count, radius, spin — barely overlap the projectile weapon's
## damage / fire-rate / multishot. Two weapons whose builds diverge is what
## actually tests whether weapons-as-data works.
##
## Unlocked by beating the Prism, so a first victory hands over a new way to
## play rather than a number.

const ORB_SCENE: PackedScene = preload("res://scenes/weapons/orbital.tscn")

## Wired by Player (stats) and Main (container is unused — orbs are children of
## this node so they follow the player for free).
var stats: Stats
var resource: WeaponResource

var _orbs: Array[Orbital] = []
var _angle: float = 0.0
var _active: bool = false


func _ready() -> void:
	set_physics_process(false)


## Called by Player once stats exist. Availability is resolved ONCE here rather
## than per frame — an unearned weapon should cost nothing at all.
func setup(p_stats: Stats, p_resource: WeaponResource,
		unlocks: Array[StringName]) -> void:
	stats = p_stats
	resource = p_resource
	_active = resource != null and resource.is_available(unlocks)
	if not _active:
		return
	set_physics_process(true)
	refresh()


## Rebuild the orb ring from current stats. Called on setup and after any
## upgrade that changes count or radius.
func refresh() -> void:
	if not _active:
		return
	var want: int = maxi(1, resource.count + stats.orbital_bonus_count)
	while _orbs.size() > want:
		var extra: Orbital = _orbs.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()
	while _orbs.size() < want:
		var orb: Orbital = ORB_SCENE.instantiate()
		add_child(orb)
		_orbs.append(orb)
	for orb: Orbital in _orbs:
		orb.damage = maxi(1, resource.damage + stats.damage_bonus)
		# Divided by spin: a faster orbit passes through an enemy more often, so
		# it must be ALLOWED to hit more often. Without this, Spin Up was a
		# cosmetic upgrade that measured 1 pick in 10 offers.
		orb.hit_interval = resource.interval / maxf(0.25, stats.orbital_speed_mult)


func _physics_process(delta: float) -> void:
	_angle += delta * resource.orbit_speed * stats.orbital_speed_mult
	var radius: float = resource.orbit_radius + stats.orbital_bonus_radius
	var n: int = _orbs.size()
	for i: int in n:
		var orb: Orbital = _orbs[i]
		if is_instance_valid(orb):
			orb.position = Vector2.RIGHT.rotated(_angle + TAU * float(i) / float(n)) * radius
