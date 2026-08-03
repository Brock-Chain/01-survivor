class_name Stats
extends Resource
## The player's mutable numbers, as data. Upgrades (M4) mutate these —
## keeping them in one Resource is the same pattern V3 uses for card stats.

@export var max_hp: int = 6
@export var move_speed: float = 130.0
## Weapon MODIFIERS. Base values live on WeaponResource; final = base + / x these,
## which is why one upgrade can improve two weapons with different base rates.
@export var damage_bonus: int = 0
@export var fire_rate_mult: float = 1.0
@export var projectile_bonus: int = 0
@export var projectile_speed_mult: float = 1.0
@export var magnet_radius: float = 48.0
## Hard ceiling on XP gain. `greed` is Epic, +50%, two stacks, and both XP
## effects used to stack MULTIPLICATIVELY: with `scholar` at 3 the run held 3.0x
## from 2:30 onward and reached level 79 on income worth level 54. Greed alone
## was 25 levels. Additive with a cap, same shape as the multishot tax.
const XP_MULT_CAP: float = 1.6
@export var xp_mult: float = 1.0
## Extra enemies a shot punches through before dying.
@export var pierce: int = 0
@export var crit_chance: float = 0.0
@export var crit_mult: float = 2.5
## Chance per kill to recover 1 HP. Healing as a BUILD CHOICE rather than a
## level-up option, so it is never a wasted pick at full health.
@export var lifesteal_chance: float = 0.0

## Orbital modifiers. Kept here rather than mutating WeaponResource, because a
## Resource is shared across runs — writing upgrades into it would leak the
## previous run's power into the next one.
@export var orbital_bonus_count: int = 0
@export var orbital_bonus_radius: float = 0.0
@export var orbital_speed_mult: float = 1.0

## Epic / Legendary effects. Zero or false means "not taken", so every one of
## these is inert until an upgrade turns it on — no branch runs for a player who
## never picked it up.
@export var ricochet: int = 0
@export var cryo_slow: float = 0.0
@export var execute_below: float = 0.0
@export var greed: bool = false
@export var aegis_interval: float = 0.0
@export var nova_radius: float = 0.0
@export var prism_shards: int = 0
@export var implode_radius: float = 0.0
@export var overclock_every: int = 0
@export var second_wind: bool = false
@export var chain_targets: int = 0

## The silent per-level drip (M7.2). Written by Main from `Progression`, which
## computes each as a pure function of the level — these are SET, never
## accumulated, so they cannot double-apply on a chained level-up.
@export var drip_damage_mult: float = 1.0
@export var drip_cooldown_mult: float = 1.0
@export var drip_move_speed_mult: float = 1.0


## Damage for a weapon whose authored damage is `base`, before that weapon's own
## taxes. Float on purpose: the multishot and ring taxes still have to multiply
## it, and rounding here would round three times per shot instead of once.
func damage_from(base: int) -> float:
	return (float(base) + float(damage_bonus)) * drip_damage_mult


## Cooldown scale for any weapon: the cards on top of the level drip. Lower is
## faster — `fire_rate_mult` has always been a cooldown multiplier, not a rate.
func cooldown_scale() -> float:
	return fire_rate_mult * drip_cooldown_mult


## Final move speed. The drip is capped inside Progression, not here.
func speed() -> float:
	return move_speed * drip_move_speed_mult


## XP effects fold into ONE additive bonus under a hard cap, rather than each
## multiplying the last. See XP_MULT_CAP.
func add_xp_bonus(bonus: float) -> void:
	xp_mult = minf(XP_MULT_CAP, xp_mult + bonus)


## Damage multiplier applied to EACH projectile once multishot has widened the
## volley. Volley damage must not scale linearly with projectile count.
##
## Measured 2026-08-02: a level-45 run reached 8 projectiles (+7) AND +19 flat
## damage. Those axes multiplied — 8 x 19 against a base of 1 x 1, roughly 150x,
## before pierce, ricochet, chain and Prism Core. The 5:00 boss died in SEVEN
## seconds. No single upgrade was overtuned; the product was.
##
## Square root, so total volley damage scales with sqrt(N) rather than N: eight
## projectiles deal ~2.8x one projectile's damage, not 8x. Multishot stays a
## strong CROWD tool — more projectiles still means more bodies hit — while
## single-target DPS, which is what deletes a boss, grows far more slowly. That
## split is the whole point: it narrows the DPS gap between a first-timer and a
## maxed profile, which is what lets one boss HP number serve both.
##
## Taxed against the weapon's OWN base count, not against 1. The scattergun fires
## 5 pellets by design and its damage was authored around that; only growth the
## player bought with upgrades is taxed.
static func volley_damage_mult(base_count: int, total_count: int) -> float:
	var base: float = float(maxi(1, base_count))
	var total: float = float(maxi(1, total_count))
	if total <= base:
		return 1.0
	return sqrt(base / total)
