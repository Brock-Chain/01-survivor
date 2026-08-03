class_name EnemyProjectile
extends Area2D
## Boss and Lancer fire. Yellow by the colour law — nothing friendly is ever
## yellow, so "this can hurt me" reads before the shape does.
##
## Lifetime-capped like the player's projectile: a bullet that can outlive its
## shooter is an unbounded live set waiting to happen.
##
## GLOW AND STREAK, and that pairing is the whole point. Playtest 2026-08-03:
## "orange dart looks more like a projectile". It did — a Dart and a bolt were
## the same construction, a small flat rotated triangle differing only in hue,
## so hue was the ONLY thing telling a body apart from a bullet on the busiest
## screen in the game. Hue is the weakest signal available and it was carrying
## the whole load.
##
## Enemies now glow and do NOT streak; a bolt glows and streaks. Motion is the
## discriminator, because motion is what actually differs: a thing that leaves a
## tracer is flying, and a thing that does not is walking at you. That reads at
## 12px in a crowd in a way a colour swap never could — and it left every enemy
## tint in the colour law untouched.

const LIFETIME: float = 6.0

## Points in the streak. One per physics frame, so at 60Hz this is ~0.12s of
## history — long enough to read as a tracer, short enough that a boss's 22-bolt
## ring is 22 short dashes and not a plate of spaghetti.
const TRAIL_POINTS: int = 7
## Diameter of the glow in pixels. The bolt sprite is 12px, so the halo reads as
## light spilling off a hot object rather than as a second, bigger object.
const HALO_PIXELS: float = 15.0
const HALO_ALPHA: float = 0.42
## The colour law's "incoming enemy damage" yellow, shared with Enemy.TELEGRAPH.
const GLOW: Color = Color(1.0, 0.85, 0.32)

var velocity: Vector2 = Vector2.ZERO
var damage: int = 1

var _life: float = LIFETIME
var _trail_points: PackedVector2Array = PackedVector2Array()

@onready var trail: Line2D = $Trail


func setup(p_velocity: Vector2, p_damage: int) -> void:
	velocity = p_velocity
	damage = p_damage


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = velocity.angle() + PI * 0.5  # sprite points 'up'
	_add_halo()


## Borrows Enemy's shared halo texture and material rather than building its own.
## One soft-dot image and one additive material serve every glowing thing in the
## game — a second copy here would be a second thing to keep in sync for no gain.
func _add_halo() -> void:
	var halo := Sprite2D.new()
	halo.texture = Enemy.halo_texture()
	halo.material = Enemy.halo_material()
	halo.modulate = Color(GLOW.r, GLOW.g, GLOW.b, HALO_ALPHA)
	halo.scale = Vector2.ONE * (HALO_PIXELS / float(Enemy.HALO_TEXTURE_SIZE))
	halo.z_index = -1
	add_child(halo)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	global_position += velocity * delta
	_update_trail()


## The streak. Points are GLOBAL because the Line2D is top_level — see the scene.
func _update_trail() -> void:
	_trail_points.append(global_position)
	while _trail_points.size() > TRAIL_POINTS:
		_trail_points.remove_at(0)
	# Below two points a Line2D draws nothing anyway, and assigning a 1-point
	# array every frame for the bolt's first frame is pure churn.
	if _trail_points.size() < 2:
		return
	trail.points = _trail_points


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).apply_damage(damage, &"bolt")
		queue_free()
