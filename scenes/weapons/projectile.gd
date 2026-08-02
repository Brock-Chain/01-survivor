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
## Extra targets it redirects to after a hit (Ricochet).
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
	enemy.take_hit(damage, execute_below)

	if _can_spawn:
		if prism_shards > 0:
			_burst(prism_shards)
		if chain_targets > 0:
			_chain(enemy)

	if ricochet > 0:
		var next: Enemy = _nearest_excluding([enemy], global_position, RICOCHET_RANGE)
		if next != null:
			ricochet -= 1
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
		get_parent().add_child(shard)


## Chain Lightning: arc to the nearest few other enemies. Modelled as very
## short-lived fast bolts rather than drawn lightning, so it reuses the whole
## existing projectile path instead of needing a new render system.
func _chain(from: Enemy) -> void:
	var hit: Array[Enemy] = [from]
	for i: int in chain_targets:
		var next: Enemy = _nearest_excluding(hit, from.global_position, CHAIN_RANGE)
		if next == null:
			return
		hit.append(next)
		var bolt: Projectile = duplicate() as Projectile
		bolt._can_spawn = false
		bolt.prism_shards = 0
		bolt.chain_targets = 0
		bolt.ricochet = 0
		bolt._life = 0.3
		bolt.setup((next.global_position - from.global_position).normalized(), 620.0,
				maxi(1, roundi(damage * 0.6)))
		bolt.global_position = from.global_position
		bolt.scale = Vector2.ONE * 0.7
		get_parent().add_child(bolt)


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
