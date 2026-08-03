class_name Nogaxeh
extends Boss
## NOGAXEH — the 10:00 mirror. The only hostile hexagon in the game.
##
## For ten minutes "hexagon = me" is how the player reads the screen at a glance.
## This breaks that rule exactly once, at the climax, and the break IS the reveal:
## the shape you have been all run is standing opposite you. Its name is HEXAGON
## spelled backwards, and the HUD banner spells the word forwards before flipping
## it, so the reveal is typography rather than dialogue nobody reads mid-fight.
##
## It fights with TESSELLATION, the real reason hexagons are the bestagon: they
## tile a plane with the least perimeter for the most area. The Prism fires rings
## you weave through; Nogaxeh denies SPACE. Same shape as you, opposite verb.
##
## THE SPINE IS THE UNCANNY MIRROR, THE TEXTURE IS DREAD (playtest 2026-08-02:
## "Nogaxeh was a bit too easy... needs better attacks, more presence and
## intimidation"). Concretely: it PLANTS rather than chases, it dashes like the
## player does — with a trail — and the music thins to bass on its arrival and
## rebuilds one stem per phase.
##
## FOUR PHASES since M7.2/7.3, and NOTHING ELSE SPAWNS for the whole fight:
##   1  Two FULL 1200 HP Prisms arrive with it and it is invulnerable until both
##      are dead. Not the old half-health escorts: the thing you beat at 5:00
##      comes back as a minion at full strength, and that lands harder unweakened.
##   2  Vulnerable. Dread gives way — it starts mirroring you, dashing and
##      trailing the way you do.
##   3  Vulnerable, denser.
##   4  Four MORE full Prisms and the shield is back up. The final stretch.
##      Breaking that shield STUNS it and it begins charging an explosion.
##
## THE FINISH. The stun lasts FUSE seconds and NOGAXEH dies either way: kill it
## and it simply dies, run out the clock and it detonates first. The blast is a
## PERCENTAGE of max HP, so stacking HP cannot trivialise it — a player who
## arrives above half survives and a player who arrives hurt does not. The
## attrition of phases 2 and 3 is what makes the finale lethal, which is the
## whole reason the fight is long.
##
## Event budget: 4000 here plus six 1200 HP Prisms = 11,200, 3.5x the old mirror
## event. Budgeted in SECONDS at measured DPS, never as a ratio to the 5:00
## fight — the old ESCORT_HP reasoned from such a ratio and produced a 22-second
## "climax", because the player's DPS quadrupled between 5:00 and 10:00.
##
## Phase 1 -> 2 is NOT an HP threshold; it cannot be, since the boss is
## invulnerable until the escorts die. The director drives it. Phase spawns and
## escort spawns are the director's too — a boss must not reach around the only
## system allowed to create bosses. This class owns the shield STATE, the stun,
## and their tells.

## Fired when the phase-4 shield breaks and the fuse starts, and again when the
## fuse runs out. Main hangs the warning and the blast off these; the boss never
## reaches out to damage the player itself.
signal fuse_lit(seconds: float)
signal detonated(at: Vector2)

## Arms in the lattice. Six, obviously.
const ARMS: int = 6
## Bolts per arm, per phase. An arm is a LINE, drawn by giving each bolt a
## different speed along one bearing so they separate into a spoke as they
## travel — the lattice grows outward rather than arriving all at once.
##
## Doubled and extended to four phases (M7.2). The spec's word was "double the
## projectiles"; density is what makes the mirror a bullet-hell fight rather
## than a health bar, and the dash the player earns at 5:00 is what makes that
## fair.
const PER_ARM: Array[int] = [8, 11, 13, 15]

## Seconds between the shield breaking and the blast. Long enough to be a real
## decision — burn everything and kill it, or run for the edge — short enough
## that it is a sprint rather than a lull.
const FUSE: float = 5.0
## Blast damage as a FRACTION OF THE PLAYER'S MAX HP, inside and outside
## BLAST_CORE. Percentages, so a 40 HP build eats the same proportion as a 6 HP
## one and stacking HP cannot buy its way out of the finale.
const BLAST_CORE: float = 150.0
const BLAST_CORE_FRACTION: float = 0.70
const BLAST_EDGE_FRACTION: float = 0.50
## Fraction of bolt_speed the innermost bolt of an arm gets. Below this the arm
## reads as a clump at the boss rather than as a spoke.
const ARM_SPEED_FLOOR: float = 0.5

## HONEYCOMB: bolts leave the six VERTICES of a hexagon rather than its centre,
## so the wall arrives as a tiling front with gaps only at the edge midpoints.
const CELL_RADIUS: float = 26.0
const CELL_BOLTS: int = 3
const CELL_FAN: float = 0.30

## SHEAR: two counter-rotating rings. Neither is dense enough to trap you; the
## gaps drifting in opposite directions are what make standing still fatal.
const SHEAR_PER_RING: int = 11
const SHEAR_OFFSET: float = 0.16

## The mirror dash — faster and longer than the Prism's reposition, because it is
## quoting the player's verb rather than shuffling.
const MIRROR_DASH_SPEED: float = 430.0
const MIRROR_DASH_TIME: float = 0.34
const TRAIL_POINTS: int = 22

var _lattice_spin: float = 0.0
var _shear_spin: float = 0.0
var _pattern: int = 0
var _trail: PackedVector2Array = PackedVector2Array()
## Seconds left on the fuse. Negative means no fuse is burning, which is not the
## same as zero — zero is the frame it goes off.
var _fuse_left: float = -1.0

@onready var membrane: Sprite2D = $Membrane
@onready var trail_line: Line2D = $Trail


func _ready() -> void:
	super._ready()
	membrane.visible = false
	trail_line.visible = false


## Shards still detach at phase 2 like the parent's. Everything else about this
## fight's shape lives in _fire and in the director.
func _on_phase(new_phase: int) -> void:
	if new_phase == 2:
		detach_shards()


## Phase 1 -> 2, driven by the director when the opening pair of Prisms is dead.
## An HP threshold cannot do this: the boss is invulnerable for the whole of
## phase 1, so its HP never moves and the threshold would never fire.
func escorts_cleared() -> void:
	drop_shield()
	if phase == 1:
		force_phase()


## THE FINISH. The phase-4 shield breaks, NOGAXEH stops dead, and the fuse
## starts. It cannot attack or move from here — the danger is the clock.
func begin_fuse() -> void:
	drop_shield()
	_fuse_left = FUSE
	_attack_cd = INF
	_telegraph_left = 0.0
	_dash_left = 0.0
	velocity = Vector2.ZERO
	Sfx.play(&"boss_telegraph", 0.0)
	fuse_lit.emit(FUSE)
	# Swells to white over the whole fuse: the tell for "this is about to go off"
	# is the boss itself getting brighter, readable without a HUD element.
	var t: Tween = create_tween()
	t.tween_property(visual, "modulate", Color(2.2, 2.0, 2.4), FUSE)


func is_fusing() -> bool:
	return _fuse_left >= 0.0


func _tick_fuse(delta: float) -> void:
	_fuse_left -= delta
	if _fuse_left > 0.0:
		return
	_fuse_left = -1.0
	detonated.emit(global_position)
	# It dies EITHER WAY. The five seconds only decide whether the player eats
	# the blast, so the run resolves identically from the director's side — same
	# `died` payload, same listeners, same true ending. Mirrors Enemy.take_hit's
	# death rather than calling it, because there is no damage and no attacker.
	hp = 0
	died.emit(xp_value, global_position, stats.tint)
	queue_free()


## Raised by the director when the escorts arrive. The hollow hex RING fills with
## a translucent membrane: the cell closes. That is the entire indicator on the
## boss itself — no icon, no text; the silhouette says it.
func raise_shield() -> void:
	invulnerable = true
	membrane.visible = true
	membrane.modulate.a = 0.0
	var t: Tween = create_tween()
	t.tween_property(membrane, "modulate:a", 0.72, 0.35)


## The cell shatters open. Deliberately louder than strictly necessary: this is
## the moment the player's damage starts counting again and they must not miss it.
func drop_shield() -> void:
	if not invulnerable:
		return
	invulnerable = false
	Sfx.play(&"boss_death", -8.0)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(membrane, "modulate:a", 0.0, 0.25)
	t.tween_property(membrane, "scale", Vector2.ONE * 1.6, 0.25)
	t.chain().tween_callback(func() -> void:
		membrane.visible = false
		membrane.scale = Vector2.ONE)


func _physics_process(delta: float) -> void:
	# A stunned boss does not attack, move or orbit. Everything it was doing
	# stops the instant the shield breaks — the only thing still running is the
	# clock, which is what makes those five seconds read as a countdown.
	if is_fusing():
		_tick_fuse(delta)
		return
	super._physics_process(delta)
	_update_trail()


## The mirror's trail, drawn only while dashing. The player leaves one; so does
## this. Cheapest possible way to make "it moves like you" legible.
func _update_trail() -> void:
	if _dash_left > 0.0:
		_trail.append(global_position)
		while _trail.size() > TRAIL_POINTS:
			_trail.remove_at(0)
		trail_line.points = _trail
		trail_line.visible = _trail.size() >= 2
		return
	if _trail.is_empty():
		return
	# Retract rather than vanish, so the trail dissolves from the tail forward.
	_trail.remove_at(0)
	trail_line.points = _trail
	trail_line.visible = _trail.size() >= 2


## Cycles the patterns. Phase 1 is LATTICE only — one attack, slowly, so the
## player learns to read it before anything else is introduced. That restraint
## IS the dread.
func _fire() -> void:
	Sfx.play(&"bolt", -8.0)
	var tier: int = clampi(phase - 1, 0, PER_ARM.size() - 1)
	if phase == 1:
		_fire_lattice(tier)
	else:
		# Phase 2 alternates two patterns; 3 and 4 cycle all three, so the arena
		# stops having a shape the player can memorise exactly when it fills up.
		_pattern = (_pattern + 1) % (2 if phase == 2 else 3)
		match _pattern:
			0:
				_fire_lattice(tier)
			1:
				_fire_honeycomb(tier)
			_:
				_fire_shear(tier)
	if phase >= 2:
		_dash_dir = (target.global_position - global_position).normalized()
		_dash_left = MIRROR_DASH_TIME
	_attack_cd = p1_interval if phase == 1 else p2_interval


## LATTICE — six arms at 60 degrees, each a growing spoke. The signature.
func _fire_lattice(tier: int) -> void:
	var per_arm: int = PER_ARM[tier]
	# Aim an arm AT the player, then rotate by half a step each volley, so the
	# safe wedge is never twice in the same place.
	var base: float = (target.global_position - global_position).angle() + _lattice_spin
	_lattice_spin += PI / float(ARMS)
	for arm: int in ARMS:
		var dir: Vector2 = Vector2.RIGHT.rotated(base + TAU * float(arm) / float(ARMS))
		for i: int in per_arm:
			var t: float = float(i) / maxf(1.0, float(per_arm - 1))
			_bolt(global_position, dir * (bolt_speed * lerpf(ARM_SPEED_FLOOR, 1.0, t)))


## HONEYCOMB — six cells fire outward from the vertices of a hexagon around the
## boss, each a small fan. A tiling wall with gaps only where the cells meet.
func _fire_honeycomb(tier: int) -> void:
	var bolts: int = CELL_BOLTS + tier
	var base: float = (target.global_position - global_position).angle()
	for cell: int in ARMS:
		var angle: float = base + TAU * float(cell) / float(ARMS)
		var origin: Vector2 = global_position + Vector2.RIGHT.rotated(angle) * CELL_RADIUS
		for i: int in bolts:
			var spread: float = (float(i) - float(bolts - 1) * 0.5) * CELL_FAN
			_bolt(origin, Vector2.RIGHT.rotated(angle + spread) * bolt_speed * 0.92)


## SHEAR — two rings whose gaps drift in opposite directions. Neither ring alone
## is a wall; the point is that no spot stays safe for two volleys running.
func _fire_shear(tier: int) -> void:
	var per_ring: int = SHEAR_PER_RING + tier * 3
	_shear_spin += SHEAR_OFFSET
	for ring: int in 2:
		var way: float = 1.0 if ring == 0 else -1.0
		var speed: float = bolt_speed * (1.0 if ring == 0 else 0.72)
		for i: int in per_ring:
			var angle: float = _shear_spin * way \
					+ TAU * (float(i) + 0.5 * float(ring)) / float(per_ring)
			_bolt(global_position, Vector2.RIGHT.rotated(angle) * speed)


func _bolt(at: Vector2, vel: Vector2) -> void:
	var bolt: EnemyProjectile = PROJECTILE_SCENE.instantiate()
	bolt.setup(vel, damage)
	bolt.global_position = at
	_bolt_parent().add_child(bolt)


## Dread: it PLANTS rather than chases. The Prism drifts steadily toward you;
## this holds still between attacks and only closes by dashing, which makes the
## dash read as a decision instead of as locomotion.
func _move(delta: float) -> void:
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_dir * MIRROR_DASH_SPEED
	else:
		velocity = velocity.lerp(Vector2.ZERO, minf(1.0, 6.0 * delta))
	move_and_slide()
