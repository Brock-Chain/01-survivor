class_name UpgradePool
extends RefCounted
## Weighted draw of N distinct, eligible upgrades. The RNG is INJECTED so
## tests (and future daily-run seeds) are reproducible — RNG discipline
## starts in game 1 because balancing without it is misery.

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
	var eligible: Array[UpgradeResource] = _upgrades.filter(
		func(u: UpgradeResource) -> bool:
			return u.is_eligible(int(stacks.get(u.id, 0)), unlocks)
	)
	var result: Array[UpgradeResource] = []
	while result.size() < count and not eligible.is_empty():
		var picked: UpgradeResource = _weighted_pick(eligible)
		result.append(picked)
		eligible.erase(picked)  # without replacement — offers are distinct
	return result


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
