class_name BuffState
extends RefCounted
## Timed buffs, as pure logic. Time is INJECTED (callers pass delta) so this is
## unit-testable without the scene tree — the same discipline as Health.
##
## Deliberately NOT part of Stats. Stats are permanent run modifiers that
## upgrades write into; a buff is temporary and must never leak into them, or a
## six-second shield would quietly become a permanent one.

## Ids. Referenced by content and by the HUD, so they live in one place.
const SHIELD: StringName = &"shield"
const POWER: StringName = &"power"
const HASTE: StringName = &"haste"

var _remaining: Dictionary = {}


## Grant or refresh. Takes the LONGER of the two rather than adding: picking up
## a second shield with 5s left must never *shorten* it to the new duration, and
## stacking to a minute of invulnerability off a lucky streak is worse.
func grant(id: StringName, duration: float) -> void:
	if duration <= 0.0:
		return
	_remaining[id] = maxf(float(_remaining.get(id, 0.0)), duration)


## Advance all timers. Returns the ids that expired on THIS tick, so the caller
## can fire a cue exactly once when a buff drops.
func tick(delta: float) -> Array[StringName]:
	var expired: Array[StringName] = []
	for id: StringName in _remaining.keys():
		var left: float = float(_remaining[id]) - delta
		if left <= 0.0:
			_remaining.erase(id)
			expired.append(id)
		else:
			_remaining[id] = left
	return expired


func has(id: StringName) -> bool:
	return _remaining.has(id)


func remaining(id: StringName) -> float:
	return float(_remaining.get(id, 0.0))


## Longest-lived first, so a HUD listing them is stable rather than reordering
## itself every frame as a Dictionary rehashes.
func active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _remaining.keys():
		ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return float(_remaining[a]) > float(_remaining[b]))
	return ids


func clear() -> void:
	_remaining.clear()
