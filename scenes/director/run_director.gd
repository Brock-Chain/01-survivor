class_name RunDirector
extends Node
## SYSTEM CONTRACT — Run Director
##
## Purpose: own the SHAPE of a run — what spawns when, when elites appear, when
##   bosses arrive, and when the run is won.
##
## Data: RunSchedule (.tres) holding Array[WaveResource] (.tres). All pacing is
##   data; this script is policy only and contains no tuning numbers.
##
## Ownership:
##   Owns:      elapsed run time, the active wave, spawn cadence, boss
##              scheduling, victory state, the intensity signal.
##   Does NOT own: how an enemy is instantiated or placed (Spawner), run stats
##              such as kills and XP (Main), or player state (Player).
##   Calls down to: Spawner.spawn().
##   Signals up: wave_changed, intensity_changed, boss_spawned, boss_defeated,
##              victory.
##
## Invariants:
##   1. Boss event i fires exactly once, in order, never before its time.
##   2. `victory` is emitted at most once per run, on the FIRST boss event
##      cleared. Continuing into endless can never revoke it.
##   3. Cadence spawns never push living enemies past Difficulty.MAX_ALIVE.
##      Bosses are scheduled rather than spawned by cadence and are exempt.
##   4. Same seed + same schedule => same spawn sequence.
##
## Failure mode: `can_spawn()` is false at the cap, with no schedule, or when no
##   wave covers the current time. A schedule with a gap degrades to "nothing
##   spawns" — never a crash, never a partially-applied wave.
##
## Done when: a full run reaches the boss and can be won; victory banks and
##   offers Restart or Continue; endless reaches the double boss.

signal wave_changed(wave: WaveResource)
signal intensity_changed(level: int)
signal boss_spawned(boss: Node2D)
signal boss_defeated(bosses_remaining: int)
## Emitted once, the first time a boss event is fully cleared.
signal victory(event_index: int)

## Bosses read as the threat only if the adds thin out, so while one is alive the
## normal cadence is stretched. Boss-tier intensity for the audio layer.
const BOSS_INTENSITY: int = 3

@export var schedule: RunSchedule
@export var boss_scene: PackedScene

## Wired by Main at _ready (call down).
var spawner: Spawner
var target: Node2D
var boss_container: Node2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var elapsed: float = 0.0
var bosses_alive: int = 0

var _cooldown: float = 0.0
var _wave: WaveResource
var _next_boss_event: int = 0
var _intensity: int = -1
var _won: bool = false


func _physics_process(delta: float) -> void:
	if schedule == null or not is_instance_valid(target):
		return
	elapsed += delta
	_update_wave()
	_check_boss_event()
	_tick_spawns(delta)


## False whenever a cadence spawn must not happen. Checked before every spawn so
## an incomplete schedule degrades quietly instead of erroring.
func can_spawn() -> bool:
	if _wave == null or _wave.types.is_empty() or spawner == null:
		return false
	return Difficulty.should_spawn(spawner.alive_count())


func _update_wave() -> void:
	var next: WaveResource = schedule.wave_at(elapsed)
	if next == _wave:
		return
	_wave = next
	if _wave != null:
		_cooldown = minf(_cooldown, _wave.spawn_interval)
		wave_changed.emit(_wave)
	_publish_intensity()


## Boss tier overrides the wave's own tier, so the music escalates for the fight
## and settles back to whatever the wave asked for afterwards.
func _publish_intensity() -> void:
	var level: int = BOSS_INTENSITY if bosses_alive > 0 else (_wave.intensity if _wave != null else 0)
	if level == _intensity:
		return
	_intensity = level
	intensity_changed.emit(level)


func _tick_spawns(delta: float) -> void:
	if _wave == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	# Burn the cooldown even when we decline to spawn, so a full arena throttles
	# itself rather than banking a backlog to dump the moment space frees up.
	if can_spawn():
		var stats: EnemyStats = _wave.pick_type(rng)
		if stats != null:
			spawner.spawn(stats, _wave.hp_mult, rng.randf() < _wave.elite_chance)
	var interval: float = _wave.spawn_interval
	if bosses_alive > 0:
		interval /= maxf(0.05, schedule.boss_spawn_throttle)
	_cooldown = interval


func _check_boss_event() -> void:
	if boss_scene == null or elapsed < schedule.boss_time(_next_boss_event):
		return
	var count: int = schedule.bosses_at_event(_next_boss_event)
	var event: int = _next_boss_event
	_next_boss_event += 1
	for i: int in count:
		_spawn_boss(i, count, event)
	_publish_intensity()


func _spawn_boss(index: int, count: int, event: int) -> void:
	var boss: Boss = boss_scene.instantiate()
	# Spread multiple bosses evenly around the arena so a double-boss event is a
	# positioning problem rather than one overlapping blob of hitboxes.
	var angle: float = TAU * (float(index) / float(maxi(1, count))) - PI * 0.5
	boss.position = spawner.ring_position(angle)
	boss.configure(target, 1.0 + float(event) * 0.4)
	bosses_alive += 1
	boss.died.connect(_on_boss_died.bind(event))
	boss_container.add_child(boss)
	boss_spawned.emit(boss)


func _on_boss_died(_xp_value: int, _at: Vector2, _tint: Color, event: int) -> void:
	bosses_alive = maxi(0, bosses_alive - 1)
	boss_defeated.emit(bosses_alive)
	if bosses_alive == 0 and not _won:
		_won = true
		victory.emit(event)
	_publish_intensity()
