extends SceneTree
## One-shot authoring tool for the run schedule.
##
##   <console.exe> --headless --path . -s res://tools/gen_waves.gd
##
## Hand-writing a typed `Array[EnemyStats]` into .tres text is guesswork; letting
## the engine serialize guarantees a format it can read back. After this runs the
## .tres files are ordinary editable data — this is a bootstrap, not a pipeline.
##
## PACING INTENT (BRIEF prime directive: one five-minute run):
##   0:00-1:00  learn the loop, chasers only
##   1:00-2:10  fast enemies enter, first elites
##   2:10-3:30  real swarm pressure
##   3:30-5:00  surge — should feel barely survivable
##   5:00       THE PRISM. Winnable. Everything past here is endless.

const OUT_DIR: String = "res://resources/waves"


func _init() -> void:
	var chaser: EnemyStats = load("res://resources/enemies/chaser.tres")
	var fast: EnemyStats = load("res://resources/enemies/fast.tres")
	if chaser == null or fast == null:
		push_error("gen_waves: missing enemy stats")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var da := DirAccess.open("res://resources")
	if da != null and not da.dir_exists("waves"):
		da.make_dir("waves")

	var waves: Array[WaveResource] = [
		_wave(&"opening", 0.0, 1.35, 1.0, 0.0, 0, [chaser], [1.0]),
		_wave(&"pressure", 60.0, 1.00, 1.35, 0.02, 1, [chaser, fast], [3.0, 1.0]),
		_wave(&"swarm", 130.0, 0.78, 1.75, 0.05, 1, [chaser, fast], [2.0, 2.0]),
		_wave(&"surge", 210.0, 0.62, 2.20, 0.09, 2, [chaser, fast], [2.0, 3.0]),
		_wave(&"endless_1", 300.0, 0.52, 3.00, 0.13, 2, [chaser, fast], [2.0, 3.0]),
		_wave(&"endless_2", 420.0, 0.46, 3.90, 0.16, 2, [chaser, fast], [2.0, 3.0]),
		_wave(&"endless_3", 600.0, 0.42, 4.90, 0.19, 2, [chaser, fast], [1.0, 2.0]),
		_wave(&"endless_4", 900.0, 0.40, 6.20, 0.22, 2, [chaser, fast], [1.0, 2.0]),
	]

	for w: WaveResource in waves:
		_save(w, "%s/%s.tres" % [OUT_DIR, w.id])

	var schedule := RunSchedule.new()
	schedule.waves = waves
	schedule.boss_interval = 300.0
	schedule.max_concurrent_bosses = 3
	schedule.boss_spawn_throttle = 0.45
	_save(schedule, "res://resources/run_schedule.tres")

	print("gen_waves: wrote %d waves + schedule" % waves.size())
	quit(0)


func _wave(id: StringName, start: float, interval: float, hp: float, elite: float,
		intensity: int, types: Array, weights: Array) -> WaveResource:
	var w := WaveResource.new()
	w.id = id
	w.start_time = start
	w.spawn_interval = interval
	w.hp_mult = hp
	w.elite_chance = elite
	w.intensity = intensity
	var typed: Array[EnemyStats] = []
	for t: EnemyStats in types:
		typed.append(t)
	w.types = typed
	var wts: Array[float] = []
	for f: float in weights:
		wts.append(f)
	w.weights = wts
	return w


func _save(res: Resource, path: String) -> void:
	res.resource_path = path
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		push_error("gen_waves: save failed %s (%d)" % [path, err])
	else:
		print("  wrote %s" % path)
