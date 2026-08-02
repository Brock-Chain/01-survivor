class_name Progression
extends RefCounted
## XP curve as a pure function — one place to tune, trivially testable.


## XP needed to go from `level` to `level + 1`. Level starts at 1.
static func xp_required(level: int) -> int:
	return 5 + (level - 1) * 4
