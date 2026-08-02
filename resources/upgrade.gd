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
	HEAL,             ## DEPRECATED — healing is a drop now, not a level reward
	PIERCE,           ## magnitude = extra enemies each shot passes through
	CRIT_CHANCE,      ## magnitude = added crit chance (0.08 = +8%)
	LIFESTEAL,        ## magnitude = added chance per kill to recover 1 HP
	ORBITAL_COUNT,    ## magnitude = extra orbiting shards
	ORBITAL_RADIUS,   ## magnitude = flat orbit radius (px)
	ORBITAL_SPEED,    ## magnitude = fractional spin bonus
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var effect: Effect
@export var magnitude: float = 0.0
## Times this may be taken. **0 or less means UNLIMITED** — at least one such
## upgrade must exist or the pool dries up and late levels offer nothing. That
## is not hypothetical: it shipped, and at level 37 the only legal draw left was
## a heal.
@export var max_stacks: int = 5
## Relative draw weight. Higher = offered more often. Must be > 0.
@export var weight: float = 1.0
## Empty means always offerable. Otherwise this upgrade only enters the pool
## once that unlock is held — so orbital upgrades cannot clutter the offers of a
## player who has never beaten the Prism.
@export var requires_unlock: StringName = &""


## Applies this upgrade to stats. HEAL is the exception — it touches Health,
## handled by the caller (Main) since Stats doesn't know about current HP.
## True if this may still be offered at `taken` stacks.
## `unlocks` is passed in, never read from the Meta autoload: otherwise these
## become untestable without a save file, and content data ends up coupled to
## persistent state.
func is_eligible(taken: int, unlocks: Array[StringName] = []) -> bool:
	if requires_unlock != &"" and not unlocks.has(requires_unlock):
		return false
	return true if max_stacks <= 0 else taken < max_stacks


func apply_to(stats: Stats) -> void:
	match effect:
		Effect.MOVE_SPEED:
			stats.move_speed *= 1.0 + magnitude
		Effect.MAX_HP:
			stats.max_hp += int(magnitude)
		Effect.DAMAGE:
			stats.damage_bonus += int(magnitude)
		Effect.FIRE_RATE:
			stats.fire_rate_mult *= 1.0 - magnitude
		Effect.PROJECTILE_COUNT:
			stats.projectile_bonus += int(magnitude)
		Effect.PROJECTILE_SPEED:
			stats.projectile_speed_mult *= 1.0 + magnitude
		Effect.MAGNET:
			stats.magnet_radius += magnitude
		Effect.XP_GAIN:
			stats.xp_mult *= 1.0 + magnitude
		Effect.HEAL:
			pass  # legacy; healing is a world drop now
		Effect.PIERCE:
			stats.pierce += int(magnitude)
		Effect.CRIT_CHANCE:
			stats.crit_chance = minf(0.85, stats.crit_chance + magnitude)
		Effect.LIFESTEAL:
			stats.lifesteal_chance = minf(0.6, stats.lifesteal_chance + magnitude)
		Effect.ORBITAL_COUNT:
			stats.orbital_bonus_count += int(magnitude)
		Effect.ORBITAL_RADIUS:
			stats.orbital_bonus_radius += magnitude
		Effect.ORBITAL_SPEED:
			stats.orbital_speed_mult *= 1.0 + magnitude
