class_name RunSchedule
extends Resource
## The shape of a whole run, as data: which wave is active when, and when boss
## events arrive. Pure — no nodes, no time of its own — so the run's pacing is
## unit-testable without playing it.
##
## Boss event `i` (0-based) happens at `boss_interval * (i + 1)` and spawns
## `bosses_first * (i + 1)` bosses, capped. With the defaults that reads: TWO
## Prisms at 5:00, four at 10:00, six at 15:00 and after.
##
## Playtest 2026-08-02: the 10:00 double-boss "was okay for a 1st boss fight" —
## against a maxed player. So the first fight becomes two bosses tuned for a
## FIVE-minute player, and every later event steps up from there. When distinct
## boss types exist, later events should swap in new ones rather than just
## stacking more Prisms.

@export var waves: Array[WaveResource] = []
## Spacing of boss events, and therefore the time of the first one.
@export var boss_interval: float = 300.0
## Bosses at the first event. Later events multiply this.
@export var bosses_first: int = 2
@export var max_concurrent_bosses: int = 6
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


## How many bosses spawn at event `index`. The cap exists so a long endless run
## stays a positioning problem rather than an unreadable wall of hitboxes.
func bosses_at_event(index: int) -> int:
	return clampi(maxi(1, bosses_first) * (index + 1), 1, maxi(1, max_concurrent_bosses))
