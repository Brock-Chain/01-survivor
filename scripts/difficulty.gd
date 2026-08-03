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


## REMOVED 2026-08-02 — `spawn_interval`, `hp_mult` and `fast_ratio` used to live
## here. Review finding 20: all three had ZERO production callers. The Run
## Director reads `spawn_interval` and `hp_mult` off each WaveResource `.tres`
## instead, and enemy-type choice moved to wave weights when the spawner became
## mechanism-only — `fast_ratio` died with it.
##
## They were not harmless. `tests/unit/test_difficulty.gd` asserted eleven exact
## values against them and passed, so the suite was green on tuning functions
## that could not affect the game: anyone editing `spawn_interval` to make the
## run harder would have seen nothing change and all tests still pass. A green
## check that verifies nothing is worse than no check.
##
## The curve now lives in ONE place — `tools/gen_waves.gd` and the `.tres` files
## it writes. `MAX_ALIVE`, `should_spawn` and the `ELITE_*` constants above are
## live and stay.
