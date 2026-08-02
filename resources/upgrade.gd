class_name UpgradeResource
extends Resource
## One upgrade = one .tres file. This is THE pattern the future deckbuilder
## is built on: content as typed, inspector-editable data — never code.

enum Effect {
	MOVE_SPEED,       ## magnitude = fractional bonus (0.15 = +15%)
	MAX_HP,           ## magnitude = flat HP added
	DAMAGE,           ## magnitude = flat damage added
	FIRE_RATE,        ## magnitude = fractional interval reduction (0.12 = 12% faster)
	PROJECTILE_COUNT, ## magnitude = shots added
	PROJECTILE_SPEED, ## magnitude = fractional bonus
	MAGNET,           ## magnitude = flat radius added (px)
	XP_GAIN,          ## magnitude = fractional bonus
	HEAL,             ## magnitude = flat HP restored (does not consume a stack slot conceptually, but stacks cap re-offers)
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var effect: Effect
@export var magnitude: float = 0.0
@export var max_stacks: int = 5
## Relative draw weight. Higher = offered more often. Must be > 0.
@export var weight: float = 1.0


## Applies this upgrade to stats. HEAL is the exception — it touches Health,
## handled by the caller (Main) since Stats doesn't know about current HP.
func apply_to(stats: Stats) -> void:
	match effect:
		Effect.MOVE_SPEED:
			stats.move_speed *= 1.0 + magnitude
		Effect.MAX_HP:
			stats.max_hp += int(magnitude)
		Effect.DAMAGE:
			stats.damage += int(magnitude)
		Effect.FIRE_RATE:
			stats.fire_interval *= 1.0 - magnitude
		Effect.PROJECTILE_COUNT:
			stats.projectile_count += int(magnitude)
		Effect.PROJECTILE_SPEED:
			stats.projectile_speed *= 1.0 + magnitude
		Effect.MAGNET:
			stats.magnet_radius += magnitude
		Effect.XP_GAIN:
			stats.xp_mult *= 1.0 + magnitude
		Effect.HEAL:
			pass  # handled by Main against Health
