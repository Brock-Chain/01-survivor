class_name WaveResource
extends Resource
## One phase of the run's spawn schedule. New waves are .tres files, not code.
##
## A wave answers "what is spawning right now, how fast, and how hard" — it does
## NOT know about time beyond its own start; ordering is RunSchedule's job.

@export var id: StringName
## Seconds into the run when this wave takes over. RunSchedule picks the LAST
## wave whose start_time has passed, so waves may be listed in any order.
@export var start_time: float = 0.0
@export var spawn_interval: float = 1.4
@export var hp_mult: float = 1.0
## Chance in [0,1] that a spawn is promoted to an elite.
@export var elite_chance: float = 0.0
## Music/pressure tier this wave represents. Consumed by the audio layer via the
## director's intensity signal — data, so retuning pacing retunes the music too.
@export var intensity: int = 0

@export var types: Array[EnemyStats] = []
## Parallel to `types`. Entries past the end default to 1.0, so a wave that
## wants uniform odds can leave this empty entirely.
@export var weights: Array[float] = []


## Weighted pick of one enemy type. RNG is INJECTED so a seeded run reproduces
## exactly — the same requirement UpgradePool has, for the same reason.
func pick_type(rng: RandomNumberGenerator) -> EnemyStats:
	if types.is_empty():
		return null
	var total: float = 0.0
	for i: int in types.size():
		total += weight_at(i)
	if total <= 0.0:
		return types[0]
	var roll: float = rng.randf() * total
	for i: int in types.size():
		roll -= weight_at(i)
		if roll <= 0.0:
			return types[i]
	return types[types.size() - 1]


func weight_at(index: int) -> float:
	if index < 0 or index >= types.size():
		return 0.0
	return maxf(0.0, weights[index]) if index < weights.size() else 1.0
