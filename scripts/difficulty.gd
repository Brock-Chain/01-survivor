class_name Difficulty
extends RefCounted
## Difficulty as pure functions of elapsed time — tunable data, not
## scattered constants, and unit-testable at exact time points.


## Seconds between spawns: 1.4s at start, linearly down to 0.4s floor (~2min).
static func spawn_interval(t: float) -> float:
	return clampf(1.4 - 0.008 * t, 0.4, 1.4)


## Enemy HP multiplier: +0.5 every 45s, stepped.
static func hp_mult(t: float) -> float:
	return 1.0 + floorf(t / 45.0) * 0.5


## Chance a spawn is the fast enemy type: 0 before 2min, ramps to 40% cap.
static func fast_ratio(t: float) -> float:
	if t < 120.0:
		return 0.0
	return minf(0.4, 0.1 + (t - 120.0) * 0.002)
