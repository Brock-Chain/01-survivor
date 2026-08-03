class_name Projectile
extends Area2D
## Straight-flying bullet. Dies on first enemy hit or when its lifetime ends —
## lifetime is the leak-guard: nothing lives forever off-screen.
##
## Carries most of the Epic/Legendary weapon effects. Every one defaults to off,
## so a player who has taken none pays for none: each branch below is guarded by
## a value that stays zero until an upgrade sets it.

const LIFETIME: float = 1.2
const CHAIN_RANGE: float = 150.0
const RICOCHET_RANGE: float = 190.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 340.0
var damage: int = 1
## Extra enemies this shot survives before dying.
var pierce: int = 0
## Extra targets it redirects to after a hit, carrying only whatever damage the
## last target could not absorb (Ricochet).
var ricochet: int = 0
## Shards it bursts into on first impact (Prism Core).
var prism_shards: int = 0
## Enemies it arcs to on hit (Chain Lightning).
var chain_targets: int = 0
## Slow fraction applied to whatever it hits (Cryo Rounds).
var cryo: float = 0.0
## HP fraction below which a hit enemy dies outright (Executioner).
var execute_below: float = 0.0

var _life: float = LIFETIME
## Shards and chain bolts must never spawn their own, or one shot recurses into
## thousands. Children are always created inert.
var _can_spawn: bool = true


func setup(p_direction: Vector2, p_speed: float, p_damage: int,
		p_pierce: int = 0, crit: bool = false) -> void:
	direction = p_direction
	speed = p_speed
	damage = p_damage
	pierce = p_pierce
	rotation = direction.angle()
	if crit:
		scale = Vector2.ONE * 1.7  # a crit you cannot see is a crit that did not happen


## Copies the run's weapon effects onto this shot. Separate from setup() so the
## common path stays cheap and readable.
func apply_effects(stats: Stats, mega: bool = false) -> void:
	ricochet = stats.ricochet
	prism_shards = stats.prism_shards
	chain_targets = stats.chain_targets
	cryo = stats.cryo_slow
	execute_below = stats.execute_below
	if mega:
		# Overclock: the periodic mega-bolt. Big, fast, goes through everything —
		# it should read as an event, not a slightly better shot.
		damage *= 4
		pierce += 6
		speed *= 1.3
		scale = Vector2.ONE * 2.6


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not (body is Enemy):
		return
	var enemy: Enemy = body as Enemy
	if cryo > 0.0:
		enemy.apply_slow(cryo, 1.6)
	var absorbed: int = enemy.take_hit(damage, execute_below, global_position)

	if _can_spawn:
		if prism_shards > 0:
			_burst(prism_shards)
		if chain_targets > 0:
			_chain(enemy)

	# Playtest 2026-08-03: "bounces should only carry over the remainder of the
	# damage, they're too strong right now." They were — a bounce redirected at
	# FULL damage, so Ricochet at two stacks was a flat 5x on every shot, and the
	# 5x landed on a boss exactly as happily as on a crowd of 1 HP Darts.
	#
	# Carrying only the OVERKILL makes the card what its fiction always claimed:
	# a shot that punches through chaff keeps going, a shot that was fully
	# stopped is stopped. Against a boss the remainder is always 0, so Ricochet
	# now adds nothing to single-target DPS — which is the whole point of the
	# nerf, and the same split the multishot tax already draws.
	if ricochet > 0:
		var carry: int = maxi(0, damage - absorbed)
		var next: Enemy = null
		if carry > 0:
			next = _nearest_excluding([enemy], global_position, RICOCHET_RANGE)
		if next != null:
			ricochet -= 1
			damage = carry
			direction = (next.global_position - global_position).normalized()
			rotation = direction.angle()
			return  # redirected rather than consumed
	if pierce <= 0:
		queue_free()
		return
	pierce -= 1


## Prism Core: burst into a fan on impact. Children are inert so shards cannot
## themselves burst — otherwise one shot recurses into thousands.
func _burst(count: int) -> void:
	_can_spawn = false
	var base: float = direction.angle()
	for i: int in count:
		var spread: float = (float(i) - (float(count) - 1.0) * 0.5) * 0.45
		var shard: Projectile = duplicate() as Projectile
		shard._can_spawn = false
		shard.prism_shards = 0
		shard.chain_targets = 0
		shard.ricochet = 0
		shard._life = 0.45
		shard.setup(Vector2.RIGHT.rotated(base + spread), speed * 0.9,
				maxi(1, roundi(damage * 0.5)))
		shard.global_position = global_position
		shard.scale = Vector2.ONE * 0.8
		# We are INSIDE body_entered — a physics flush. Adding an Area2D here
		# trips "Can't change this state while flushing queries" on every burst.
		get_parent().add_child.call_deferred(shard)


## Chain Lightning: arc to the nearest few other enemies.
##
## Playtest 2026-08-02, verbatim: "the chain lightning doesn't look like lightning
## at all". It was modelled as very short-lived fast PROJECTILES flying between
## enemies, which reads as more bullets, because that is exactly what it was.
##
## Now the damage is applied DIRECTLY and the arc is DRAWN — a jagged polyline
## with a wide translucent body under a white-hot core, fading out. That is the
## same construction as LanceWeapon._flash_line, the project's working precedent
## for an instant beam, and it is why a lance reads as a beam while this did not.
##
## Removing the child projectiles also removes the recursion trap structurally:
## the rule that chain and burst children must be created INERT (DECISIONS.md,
## "one shot recurses into thousands") cannot be violated by code that spawns no
## children at all.
const ARC_SEGMENTS: int = 7
## Peak perpendicular deviation, in pixels, at the middle of a hop. Tapered by
## sin(t*PI) so both ends stay exactly on their enemies — an arc that misses the
## thing it damaged is worse than a straight line.
const ARC_JITTER: float = 8.0
const ARC_FADE: float = 0.17
const ARC_BODY_WIDTH: float = 4.5
const ARC_CORE_WIDTH: float = 1.5


func _chain(from: Enemy) -> void:
	var hit: Array[Enemy] = [from]
	var origin: Vector2 = from.global_position
	var arc_damage: int = maxi(1, roundi(damage * 0.6))
	for i: int in chain_targets:
		var next: Enemy = _nearest_excluding(hit, origin, CHAIN_RANGE)
		if next == null:
			return
		hit.append(next)
		var landed: Vector2 = next.global_position
		# Chains hop OUTWARD from the last enemy struck, so the bolt walks the
		# crowd instead of spraying from one point.
		next.take_hit(arc_damage, execute_below, origin)
		_draw_arc(origin, landed)
		origin = landed


func _draw_arc(a: Vector2, b: Vector2) -> void:
	var parent: Node = get_parent()
	if not is_instance_valid(parent):
		return
	var span: Vector2 = b - a
	if span.length_squared() < 1.0:
		return
	var perp: Vector2 = span.orthogonal().normalized()
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in ARC_SEGMENTS + 1:
		var t: float = float(i) / float(ARC_SEGMENTS)
		var wobble: float = 0.0
		if i > 0 and i < ARC_SEGMENTS:
			wobble = randf_range(-ARC_JITTER, ARC_JITTER) * sin(t * PI)
		points.append(a + span * t + perp * wobble)
	# Player damage is cyan burning to white — same colour grammar as the lance.
	_add_arc(parent, points, ARC_BODY_WIDTH, Color(0.30, 0.92, 1.0, 0.45))
	_add_arc(parent, points, ARC_CORE_WIDTH, Color(1.0, 1.0, 1.0, 0.95))


func _add_arc(parent: Node, points: PackedVector2Array, width: float,
		colour: Color) -> void:
	var line := Line2D.new()
	line.points = points
	line.width = width
	line.default_color = colour
	line.z_index = 2
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	# The fade tween is owned by the LINE, not by this projectile: we are inside
	# body_entered and this projectile is usually freed on the very same frame.
	line.ready.connect(func() -> void:
		var fade: Tween = line.create_tween()
		fade.tween_property(line, "modulate:a", 0.0, ARC_FADE)
		fade.tween_callback(line.queue_free), CONNECT_ONE_SHOT)
	# add_child mid-physics-flush is forbidden; same rule the old version followed.
	parent.add_child.call_deferred(line)


func _nearest_excluding(exclude: Array[Enemy], from: Vector2, radius: float) -> Enemy:
	var best: Enemy = null
	var best_d: float = radius * radius
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or exclude.has(enemy):
			continue
		var d: float = from.distance_squared_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best
