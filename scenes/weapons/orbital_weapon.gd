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
## REDESIGNED in M7.3. All three of its cards measured bottom-five (0/11, 1/10,
## 3/9), which is a weapon problem wearing three cards rather than three bad
## cards. The verb was the problem: a fixed ring of two shards on a 0.4s
## per-enemy cooldown is a lawnmower, and it was at its weakest in exactly the
## situation the weapon exists for — being surrounded.
##
## MOMENTUM is the fix, and it is a mechanic rather than a number. Every kill the
## ring lands feeds its spin, up to double speed, decaying back to base when the
## killing stops. Spin is also hit RATE, so a ring that is winning gets faster at
## winning, and the weapon peaks precisely when the arena does. It is visible
## without a HUD element, which is the test a juice-lab effect has to pass.

const ORB_SCENE: PackedScene = preload("res://scenes/weapons/orbital.tscn")

## Spin added per kill, the ceiling it stacks to, and how fast it bleeds back.
## Decay is per second and deliberately slow enough to survive the gap between
## two kills in a crowd, but not slow enough to survive a lull.
const MOMENTUM_PER_KILL: float = 0.07
const MOMENTUM_MAX: float = 1.0
const MOMENTUM_DECAY: float = 0.30

## Singularity (Legendary): how hard enemies inside the pull radius are dragged
## toward the ring, in px/s at the outer edge. They are pulled to the RING, not
## to the player — the ring is where they get shredded, and it stops the card
## being "drag everything onto your own hitbox".
const PULL_SPEED: float = 90.0

## Wired by Player (stats) and Main (container is unused — orbs are children of
## this node so they follow the player for free).
var stats: Stats
var resource: WeaponResource

var _orbs: Array[Orbital] = []
var _angle: float = 0.0
var _active: bool = false
## Kill-fed spin, 0 at rest. See MOMENTUM_PER_KILL.
var _momentum: float = 0.0


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


## Whether this weapon was ever unlocked. Public because the Run Director scales
## boss HP by how many weapons are actually firing.
func is_active() -> bool:
	return _active


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
		orb.killed.connect(_on_orb_killed)
		add_child(orb)
		_orbs.append(orb)
	# Same multishot tax the projectile weapons pay: extra orbs are extra bodies
	# hit, so the ring must not also multiply damage-per-orb. Applied here too or
	# the runaway simply relocates to the axis that was left untaxed.
	var ring_tax: float = Stats.volley_damage_mult(resource.count, want)
	for orb: Orbital in _orbs:
		orb.damage = maxi(1, roundi(stats.damage_from(resource.damage) * ring_tax))
		orb.nova_radius = stats.nova_radius
	_push_hit_rate()


## Divided by spin: a faster orbit passes through an enemy more often, so it must
## be ALLOWED to hit more often. Without this, Spin Up was a cosmetic upgrade
## that measured 1 pick in 10 offers. Momentum rides the same divisor, which is
## what makes it a real DPS gain rather than an animation.
func _push_hit_rate() -> void:
	var interval: float = resource.interval / maxf(0.25, _spin_mult())
	for orb: Orbital in _orbs:
		orb.hit_interval = interval


func _spin_mult() -> float:
	return stats.orbital_speed_mult * (1.0 + _momentum)


## Every kill feeds the ring. Fired from Orbital, which fires it from inside a
## physics callback — safe because this only touches a float.
func _on_orb_killed() -> void:
	_momentum = minf(MOMENTUM_MAX, _momentum + MOMENTUM_PER_KILL)


## Split Orbit widens the ring as well as filling it (M7.3): the radius card
## measured 0 picks in 11 offers as a standalone, because it was half of one idea
## sold separately. Six px per extra shard.
func _radius() -> float:
	return (resource.orbit_radius + stats.orbital_bonus_radius
			+ 6.0 * float(stats.orbital_bonus_count))


func _physics_process(delta: float) -> void:
	if _momentum > 0.0:
		_momentum = maxf(0.0, _momentum - MOMENTUM_DECAY * delta)
		_push_hit_rate()
	_angle += delta * resource.orbit_speed * _spin_mult()
	var radius: float = _radius()
	var n: int = _orbs.size()
	for i: int in n:
		var orb: Orbital = _orbs[i]
		if is_instance_valid(orb):
			orb.position = Vector2.RIGHT.rotated(_angle + TAU * float(i) / float(n)) * radius
	if stats.orbital_pull > 0.0:
		_drag_enemies(delta, radius)


## Singularity. Inert unless the Legendary was taken, so a player who never
## picked it up pays for exactly one float comparison per frame.
##
## Moves enemies directly rather than pushing velocity: these are CharacterBody2D
## chasers driving their own movement, and a force they overwrite every frame is
## a force that does nothing. Pulled TOWARD the ring from both sides, so an enemy
## already inside the ring is nudged back out into it.
func _drag_enemies(delta: float, radius: float) -> void:
	var here: Vector2 = global_position
	var reach: float = stats.orbital_pull
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null:
			continue
		var offset: Vector2 = enemy.global_position - here
		var dist: float = offset.length()
		if dist > reach or dist < 1.0:
			continue
		var toward_ring: float = radius - dist
		if absf(toward_ring) < 2.0:
			continue
		enemy.global_position += offset.normalized() * signf(toward_ring) \
				* minf(PULL_SPEED * delta, absf(toward_ring))
