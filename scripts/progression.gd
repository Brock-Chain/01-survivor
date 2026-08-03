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
##
## SUPERSEDED 2026-08-02 (M7.2): was 1.45. That value was a proxy fix for CARD
## SCREEN spam — the complaint was never "too many levels", it was "a decision
## every 7.9 seconds". CARD_EVERY fixes that directly and at 3x the strength, so
## 1.45 became an over-correction on top of it. Levels are now deliberately
## CHEAP and mostly silent: a level is a drip of stats, and every third one is a
## decision.
##
## Solved, not guessed. run_076 banked ~20,500 raw gem XP in 11 minutes, which
## this curve turns into level ~54 at 1.45. The same income reaches level 75 —
## the spec's baseline — at 0.61, i.e. levels ~2.4x cheaper. `test_progression`
## pins both ends.
const RATE: float = 0.61

## Levels between card screens. 79 level-ups in an 11-minute run meant a card
## screen every 7.9 seconds, and a decision that arrives that often stops being
## a decision — which is the real reason three defensive cards read as dead in
## the pick data. At ~75 levels a run this is ~25 screens, each worth 3x more.
const CARD_EVERY: int = 3
## The first level-up always offers a card, so the loop teaches itself before it
## goes quiet. Cards land on levels 2, 5, 8, ... — never a silent opening.
const FIRST_CARD_LEVEL: int = 2

## The silent drip, per level. Deliberately no max HP and no defense — the HP
## pool already grew 6 -> 19 through cards in a run where the player never
## dropped below 62% at a tick, and defense stays card-only so it remains a real
## choice.
##
## Damage is FLAT, not a percentage, and that is the one number here that was
## measured rather than reasoned. The spec's starting point was +1.5% per level;
## built that way and soaked against the pre-rework build on an identical
## blaster-only run, it produced **86 kills at 3:00 where the old build produced
## 371**, with the arena pinned at the live-enemy cap. The reason is that early
## DPS is dominated by the FLAT damage bonus on a base of 1: at level 12 a
## percentage drip is worth +16% of almost nothing, while the seven card picks it
## replaced were worth several whole points of damage. A percentage pays out
## exactly when the player no longer needs it.
##
## One point of damage every three levels is deliberately close to what those
## missing picks used to supply, so the shipped power curve stays near the
## pre-rework one — which is a MEASURED quantity (the 5:00 Prism at 49s) rather
## than a guess. The rework's goal was fewer and better decisions, never a
## quieter player.
const DRIP_DAMAGE_PER_LEVEL: float = 1.0 / 3.0
const DRIP_FIRE_RATE: float = 0.015

## Breadth, and the second thing measurement forced in. Damage and fire rate make
## the player kill ONE thing faster; only projectile COUNT clears a crowd, and
## count was a card-only axis that the old pool handed out five or six times in a
## 78-pick run. With 25 picks it is handed out once, and the soak showed exactly
## that: the arena pinned at the live-enemy cap from 3:00 while the pre-rework
## build held it at five.
##
## Taxed like every other projectile source (Stats.volley_damage_mult), so this
## buys REACH and never damage — which is the whole reason it is safe to give
## away for free.
const DRIP_PROJECTILE_EVERY: int = 20
const DRIP_MOVE_SPEED: float = 0.003
## The one drip with a ceiling. Damage and fire rate make the player stronger;
## move speed makes them UN-HITTABLE, and past that point every difficulty
## number downstream is decoration. Reached at level 68.
const DRIP_MOVE_SPEED_CAP: float = 0.20


static func xp_required(level: int) -> int:
	var n: float = float(level - 1)
	return int((5.0 + 4.0 * n + CURVE_QUADRATIC * n * n) * RATE)


## True on the levels that interrupt the run with a choice. Every other level
## passes in silence with only the drip.
static func offers_card(level: int) -> bool:
	return level >= FIRST_CARD_LEVEL and (level - FIRST_CARD_LEVEL) % CARD_EVERY == 0


## The drip values are pure functions of the level and are SET onto Stats, never
## accumulated into it. Idempotent by construction: a chained level-up that
## resolves three levels in one frame cannot apply the drip three times, and the
## value is assertable without replaying the run that produced it.
static func drip_damage_bonus(level: int) -> int:
	return int(DRIP_DAMAGE_PER_LEVEL * float(maxi(0, level - 1)))


static func drip_projectiles(level: int) -> int:
	return maxi(0, level - 1) / DRIP_PROJECTILE_EVERY


## A COOLDOWN scale — lower is faster, matching `Stats.fire_rate_mult`. Inverted
## rather than subtracted so the drip reads as a rate: +0.75% shots per second
## per level is 1 / (1 + 0.0075n), which can never reach zero cooldown.
static func drip_cooldown_mult(level: int) -> float:
	return 1.0 / (1.0 + DRIP_FIRE_RATE * float(maxi(0, level - 1)))


static func drip_move_speed_mult(level: int) -> float:
	return 1.0 + minf(DRIP_MOVE_SPEED_CAP, DRIP_MOVE_SPEED * float(maxi(0, level - 1)))


## XP actually banked from a gem after the player's multiplier. Pure, so the
## rounding is testable. Floors at 1: a gem must never be worth nothing.
static func xp_gain(base_value: int, xp_mult: float) -> int:
	return maxi(1, roundi(base_value * xp_mult))
