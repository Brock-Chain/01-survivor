class_name UpgradePool
extends RefCounted
## Weighted draw of N distinct, eligible upgrades. The RNG is INJECTED so
## tests (and future daily-run seeds) are reproducible — RNG discipline
## starts in game 1 because balancing without it is misery.

## Tier each of the last offers was drawn at, parallel to the returned array.
var last_tiers: Array[Rarity.Tier] = []
## True if the last draw contained a Rare-or-better, so the caller can reset
## its pity counter without re-inspecting the offers.
var rolled_high: bool = false

var _upgrades: Array[UpgradeResource]
var _rng: RandomNumberGenerator


func _init(upgrades: Array[UpgradeResource], rng: RandomNumberGenerator) -> void:
	_upgrades = upgrades
	_rng = rng


## stacks: Dictionary[StringName -> int] of how many times each id was taken.
## unlocks: ids the player has earned; gates unlock-locked upgrades.
## Returns up to `count` distinct upgrades that are still eligible.
func draw(count: int, stacks: Dictionary,
		unlocks: Array[StringName] = []) -> Array[UpgradeResource]:
	return draw_tiered(count, stacks, unlocks, 0.0, 0)


## Rolls a TIER per card, then picks an upgrade from that tier. Falls DOWN to
## lower tiers when a rolled tier is exhausted — never up: being handed a
## Legendary because the Commons ran out would make the rarest thing in the game
## a consolation prize.
##
## Returns the offers; read `last_tiers` for the tier each was drawn at, and
## `rolled_high` to reset a pity counter.
func draw_tiered(count: int, stacks: Dictionary, unlocks: Array[StringName],
		progress: float, pity: int) -> Array[UpgradeResource]:
	var eligible: Array[UpgradeResource] = _upgrades.filter(
		func(u: UpgradeResource) -> bool:
			return u.is_eligible(int(stacks.get(u.id, 0)), unlocks)
	)
	var result: Array[UpgradeResource] = []
	last_tiers = []
	rolled_high = false

	while result.size() < count and not eligible.is_empty():
		var tier: Rarity.Tier = Rarity.roll(_rng, progress, pity)
		var picked: UpgradeResource = _pick_at_or_below(eligible, tier)
		if picked == null:
			break
		if int(picked.rarity) >= int(Rarity.PITY_TIER):
			rolled_high = true
		result.append(picked)
		last_tiers.append(picked.rarity)
		eligible.erase(picked)  # without replacement — offers are distinct
		# ...and drop everything that READS the same. Split Shot (Rare) and Scatter
		# (Uncommon) are both PROJECTILE_COUNT at magnitude 1.0 with byte-identical
		# description text, so a hand could offer both — and did, at level 29
		# (playtest 2026-08-03: "split shot and scatter same shit").
		#
		# Keyed on DESCRIPTION rather than on `effect`, deliberately. Effect is far
		# too coarse: four upgrades share DAMAGE and four share FIRE_RATE as a
		# deliberate tiered ladder (+2/+3/+6/+12), and three weapon drafts share
		# EFFECT 26 while offering genuinely different weapons. The description is
		# what the player actually tells two cards apart by, so it is the honest key
		# — if a hand would show the same sentence twice, that hand is the bug.
		#
		# This is a GUARD, not a substitute for fixing the duplicate content.
		#
		# An EMPTY description is never a match. It carries no information, so it
		# cannot be evidence that two cards read the same — and treating it as one
		# collapses the whole pool to a single offer the moment anything ships
		# without description text. That is not hypothetical: every upgrade built by
		# test_upgrade_pool's `_mk` helper omits it, and the first version of this
		# guard turned four green tests red on exactly that.
		if not picked.description.is_empty():
			for twin: UpgradeResource in eligible.duplicate():
				if twin.description == picked.description:
					eligible.erase(twin)
	return result


## The best available tier at or below `tier`. Descending, so an exhausted tier
## degrades gracefully instead of returning nothing.
func _pick_at_or_below(eligible: Array[UpgradeResource], tier: Rarity.Tier) -> UpgradeResource:
	for t: int in range(int(tier), -1, -1):
		var at_tier: Array[UpgradeResource] = eligible.filter(
			func(u: UpgradeResource) -> bool: return int(u.rarity) == t)
		if not at_tier.is_empty():
			return _weighted_pick(at_tier)
	return null


func _weighted_pick(from: Array[UpgradeResource]) -> UpgradeResource:
	var total: float = 0.0
	for u: UpgradeResource in from:
		total += u.weight
	var roll: float = _rng.randf() * total
	var acc: float = 0.0
	for u: UpgradeResource in from:
		acc += u.weight
		if roll < acc:
			return u
	return from[-1]  # float edge (roll == total): last element
