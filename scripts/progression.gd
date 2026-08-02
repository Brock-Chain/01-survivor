class_name Progression
extends RefCounted
## XP curve as a pure function — one place to tune, trivially testable.


## XP needed to go from `level` to `level + 1`. Level starts at 1.
##
## Superlinear since 2026-08-02. The curve was flat (`5 + 4L`), so late levels
## never cost more than early ones relative to income — telemetry showed level 57
## reached in under six minutes, a level every ~6 seconds. When a pick costs
## nothing, a weak upgrade is not rejected, it is just noise, which is why the
## defensive upgrades read as dead in the pick-rate data.
##
## The quadratic term is tuned to ~30% fewer levels on a typical run: measured
## against a 6000 XP run it gives level 39 where the flat curve gave 55. Options
## are buffed via the rarity system to compensate.
const CURVE_QUADRATIC: float = 0.17

static func xp_required(level: int) -> int:
	var n: float = float(level - 1)
	return int(5.0 + 4.0 * n + CURVE_QUADRATIC * n * n)


## XP actually banked from a gem after the player's multiplier. Pure, so the
## rounding is testable. Floors at 1: a gem must never be worth nothing.
static func xp_gain(base_value: int, xp_mult: float) -> int:
	return maxi(1, roundi(base_value * xp_mult))
