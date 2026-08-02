extends SceneTree
## Authors the enemy roster AND the run schedule.
##
##   <console.exe> --headless --path . -s res://tools/gen_waves.gd
##
## Rebalanced 2026-08-02 after the first human playtest:
##   "too easy and a bit slow... most of the game I could just stay still and
##    beat all enemies without getting hit, even during 2:10-4:00."
##
## Two causes, both addressed here. Spawn intervals were far too generous — the
## soak showed only 8-14 enemies alive against a cap of 110, i.e. the kill rate
## was crushing the spawn rate. And every enemy walked straight into the
## auto-weapon, so holding position was strictly optimal. The Lancer (RANGED)
## fixes the second: it holds distance and shoots, and standing still is the
## worst thing you can do against it.

const WAVES: String = "res://resources/waves"
const ENEMIES: String = "res://resources/enemies"


func _init() -> void:
	var drifter := _enemy(&"drifter", 3, 62.0, 1, 3, Color(1, 0.29, 0.72), 14.0, "enemy_drifter")
	var dart := _enemy(&"dart", 1, 132.0, 1, 2, Color(1, 0.55, 0.16), 10.0, "enemy_dart")
	var bulwark := _enemy(&"bulwark", 14, 40.0, 2, 9, Color(0.72, 0.35, 1), 20.0, "enemy_bulwark")
	var lancer := _enemy(&"lancer", 4, 58.0, 1, 6, Color(1, 0.42, 0.55), 14.0, "enemy_lancer")
	lancer.behavior = EnemyStats.Behavior.RANGED
	lancer.attack_range = 195.0
	lancer.attack_interval = 2.3
	lancer.bolt_speed = 140.0

	for e: EnemyStats in [drifter, dart, bulwark, lancer]:
		_save(e, "%s/%s.tres" % [ENEMIES, e.id])

	# start, interval, hp_mult, elite%, intensity, types, weights
	var waves: Array[WaveResource] = [
		_wave(&"opening", 0.0, 0.85, 1.0, 0.0, 0, [drifter], [1.0]),
		_wave(&"pressure", 45.0, 0.62, 1.3, 0.02, 1, [drifter, dart], [3.0, 2.0]),
		_wave(&"ranged", 95.0, 0.52, 1.6, 0.04, 1, [drifter, dart, lancer], [3.0, 2.0, 1.6]),
		_wave(&"swarm", 150.0, 0.40, 2.0, 0.07, 2, [drifter, dart, lancer, bulwark], [3.0, 3.0, 1.8, 0.9]),
		_wave(&"surge", 220.0, 0.30, 2.6, 0.10, 2, [drifter, dart, lancer, bulwark], [2.5, 3.5, 2.2, 1.2]),
		_wave(&"endless_1", 300.0, 0.26, 3.4, 0.14, 2, [drifter, dart, lancer, bulwark], [2.0, 3.5, 2.4, 1.6]),
		_wave(&"endless_2", 420.0, 0.23, 4.4, 0.17, 2, [drifter, dart, lancer, bulwark], [2.0, 3.5, 2.6, 1.8]),
		_wave(&"endless_3", 600.0, 0.21, 5.8, 0.20, 2, [dart, lancer, bulwark], [3.0, 2.8, 2.0]),
		_wave(&"endless_4", 900.0, 0.19, 7.6, 0.24, 2, [dart, lancer, bulwark], [3.0, 3.0, 2.4]),
	]
	for w: WaveResource in waves:
		_save(w, "%s/%s.tres" % [WAVES, w.id])

	var schedule := RunSchedule.new()
	schedule.waves = waves
	schedule.boss_interval = 300.0
	schedule.bosses_first = 2      # playtest: one Prism was a pushover
	schedule.max_concurrent_bosses = 6
	schedule.boss_spawn_throttle = 0.5
	_save(schedule, "res://resources/run_schedule.tres")
	print("gen_waves: 4 enemies + %d waves + schedule" % waves.size())
	quit(0)


func _enemy(id: StringName, hp: int, speed: float, dmg: int, xp: int,
		tint: Color, size: float, sprite: String) -> EnemyStats:
	var e := EnemyStats.new()
	e.id = id
	e.max_hp = hp
	e.speed = speed
	e.damage = dmg
	e.xp_value = xp
	e.tint = tint
	e.size = size
	var tex: String = "res://assets/sprites/%s.png" % sprite
	if ResourceLoader.exists(tex):
		e.sprite = load(tex)
	return e


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
