class_name RunSchedule
extends Resource
## The shape of a whole run, as data: which wave is active when, and when boss
## events arrive. Pure — no nodes, no time of its own — so the run's pacing is
## unit-testable without playing it.
##
## Boss event `i` (0-based) happens at `boss_interval * (i + 1)` and spawns
## `i + 1` bosses, capped. With the default 300s that reads: one boss at 5:00,
## two at 10:00, three at 15:00 and every event after.

@export var waves: Array[WaveResource] = []
## Spacing of boss events, and therefore the time of the first one.
@export var boss_interval: float = 300.0
@export var max_concurrent_bosses: int = 3
## Normal spawns are throttled by this factor while a boss is alive, so the boss
## reads as the threat instead of drowning in adds.
@export var boss_spawn_throttle: float = 0.45


## The active wave at time `t` — the last one whose start_time has passed.
## Returns null only if the schedule has no wave starting at or before `t`.
func wave_at(t: float) -> WaveResource:
	var chosen: WaveResource = null
	for w: WaveResource in waves:
		if w == null or t < w.start_time:
			continue
		if chosen == null or w.start_time >= chosen.start_time:
			chosen = w
	return chosen


## When boss event `index` fires.
func boss_time(index: int) -> float:
	return boss_interval * float(index + 1)


## How many bosses spawn at event `index`. Grows by one per event, capped —
## the cap exists so a long endless run stays a positioning problem rather than
## turning into an unreadable wall of overlapping bosses.
func bosses_at_event(index: int) -> int:
	return clampi(index + 1, 1, maxi(1, max_concurrent_bosses))
