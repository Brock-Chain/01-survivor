class_name Difficulty
extends RefCounted
## Difficulty as pure functions of elapsed time — tunable data, not
## scattered constants, and unit-testable at exact time points.

## Hard ceiling on living enemies. A SAFETY BOUND, not a difficulty lever —
## pressure comes from spawn_interval and hp_mult. Without it the spawn curve
## outruns achievable DPS and the live set grows without limit for the whole run.
const MAX_ALIVE: int = 110


## The spawn guard, kept pure so the bound is unit-testable rather than only
## observable by playing for ten minutes.
static func should_spawn(alive: int) -> bool:
	return alive < MAX_ALIVE


## Elite promotion. An elite is the SAME archetype under pressure — same
## silhouette, same behaviour, more of everything — so the player reads it
## instantly instead of learning a sixth enemy.
const ELITE_HP_MULT: float = 3.2
const ELITE_XP_MULT: float = 3.0
const ELITE_SCALE: float = 1.45
const ELITE_DAMAGE_BONUS: int = 1
## Elites keep their type's hue and gain a bright rim, so "dangerous" reads
## without breaking the colour law.
const ELITE_RIM: Color = Color(1.0, 0.95, 0.75, 1.0)


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
