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

## Flat multiplier on the whole curve, 2026-08-02 playtest. The run reached
## LEVEL 30 AT 4:11 — still a level every ~8 seconds, and level 30 is exactly
## where rarity odds saturate, so the entire rarity ladder was climbed before the
## boss even arrived and the last minute of the run had nothing left to escalate.
##
## Measured the way this dial has always been measured here — levels on a 6000 XP
## run — 1.45 takes 39 down to 33, i.e. ~15% fewer level-ups. The number looks
## large next to "15%" because the curve is quadratic: a flat 15% on COST buys
## only ~7% fewer LEVELS, which is not what was asked for.
##
## Applied as a multiplier rather than a steeper quadratic on purpose. The ask
## was "scarcer", not "back-loaded" — raising CURVE_QUADRATIC would have made
## late levels disproportionately expensive and changed the shape of the run.
const RATE: float = 1.45

static func xp_required(level: int) -> int:
	var n: float = float(level - 1)
	return int((5.0 + 4.0 * n + CURVE_QUADRATIC * n * n) * RATE)


## XP actually banked from a gem after the player's multiplier. Pure, so the
## rounding is testable. Floors at 1: a gem must never be worth nothing.
static func xp_gain(base_value: int, xp_mult: float) -> int:
	return maxi(1, roundi(base_value * xp_mult))
