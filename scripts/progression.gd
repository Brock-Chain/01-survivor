class_name Progression
extends RefCounted
## XP curve as a pure function — one place to tune, trivially testable.


## XP needed to go from `level` to `level + 1`. Level starts at 1.
static func xp_required(level: int) -> int:
	return 5 + (level - 1) * 4


## XP actually banked from a gem after the player's multiplier. Pure, so the
## rounding is testable. Floors at 1: a gem must never be worth nothing.
static func xp_gain(base_value: int, xp_mult: float) -> int:
	return maxi(1, roundi(base_value * xp_mult))
