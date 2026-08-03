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
## THREE PHASES, and it is alone for the first two:
##   1  >66% HP   Dread. Slow, huge, heavily telegraphed lattices. It waits.
##   2  >33% HP   It starts mirroring you: dashes across the arena, trailing.
##   3  <=33% HP  Two elite Prisms arrive AND IT SHIELDS ITSELF until they die,
##                so the escorts cannot be ignored. The pentagon beaten at 5:00
##                comes back as its minion.
## The escort spawn is RunDirector's — a boss must not reach around the only
## system allowed to create bosses. This class owns the shield STATE and its
## tells.

## Arms in the lattice. Six, obviously.
const ARMS: int = 6
## Bolts per arm, per phase. An arm is a LINE, drawn by giving each bolt a
## different speed along one bearing so they separate into a spoke as they
## travel — the lattice grows outward rather than arriving all at once.
const PER_ARM: Array[int] = [4, 6, 7]
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
		_pattern = (_pattern + 1) % (2 if phase == 2 else 3)
		match _pattern:
			0:
				_fire_lattice(tier)
			1:
				_fire_honeycomb()
			_:
				_fire_shear()
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
func _fire_honeycomb() -> void:
	var base: float = (target.global_position - global_position).angle()
	for cell: int in ARMS:
		var angle: float = base + TAU * float(cell) / float(ARMS)
		var origin: Vector2 = global_position + Vector2.RIGHT.rotated(angle) * CELL_RADIUS
		for i: int in CELL_BOLTS:
			var spread: float = (float(i) - float(CELL_BOLTS - 1) * 0.5) * CELL_FAN
			_bolt(origin, Vector2.RIGHT.rotated(angle + spread) * bolt_speed * 0.92)


## SHEAR — two rings whose gaps drift in opposite directions. Neither ring alone
## is a wall; the point is that no spot stays safe for two volleys running.
func _fire_shear() -> void:
	_shear_spin += SHEAR_OFFSET
	for ring: int in 2:
		var way: float = 1.0 if ring == 0 else -1.0
		var speed: float = bolt_speed * (1.0 if ring == 0 else 0.72)
		for i: int in SHEAR_PER_RING:
			var angle: float = _shear_spin * way \
					+ TAU * (float(i) + 0.5 * float(ring)) / float(SHEAR_PER_RING)
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
