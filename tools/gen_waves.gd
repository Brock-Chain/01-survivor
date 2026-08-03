extends SceneTree
## Authors the enemy roster AND the run schedule.
##
##   <console.exe> --headless --path . -s res://tools/gen_waves.gd
##
## Rebalanced twice on 2026-08-02. Pass 2 is driven by TELEMETRY from a real
## playtest, not a soak: HP never dropped below 72% and sat at 89-100% for most
## of the run, with only 13 damage taken all game, and 6-22 living enemies where
## the god-mode bot saw 38-63. A competent human clears far faster than the bot,
## which is exactly why soak numbers cannot set difficulty.
##
## Levers pulled: spawn intervals down again, Lancer share up (bolts were 38% of
## all damage taken despite being a minority of spawns — the ranged threat is
## the efficient one), and enemy speeds up.
##
## Pass 1, after the same playtest's written feedback:
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
	# Sizes come from EnemySize, never from a literal — see that file. Playtest
	# 2026-08-02: "the small enemies are TOO small". Balance is deliberately NOT
	# retuned to compensate; this is a legibility change, not a difficulty one.
	var drifter := _enemy(&"drifter", 3, 72.0, 1, 3, Color(1, 0.29, 0.72), EnemySize.MEDIUM, "enemy_drifter")
	# A needle that points where it is going. The triangle it used to wear belongs
	# to the enemy bolt, and sharing a silhouette with enemy FIRE is the one
	# confusion the colour law exists to prevent.
	var dart := _enemy(&"dart", 1, 152.0, 1, 2, Color(1, 0.55, 0.16), EnemySize.SMALL, "enemy_dart")
	dart.faces_travel = true
	var bulwark := _enemy(&"bulwark", 16, 46.0, 2, 9, Color(0.72, 0.35, 1), EnemySize.HEAVY, "enemy_bulwark")
	var lancer := _enemy(&"lancer", 4, 66.0, 1, 6, Color(1, 0.42, 0.55), EnemySize.MEDIUM, "enemy_lancer")
	lancer.behavior = EnemyStats.Behavior.RANGED
	lancer.attack_range = 195.0
	lancer.attack_interval = 1.9
	lancer.bolt_speed = 140.0

	# THE SHARD — a Prism at ~60% scale with a fraction of the health, entering as
	# a REGULAR enemy only after the player has already beaten the real thing.
	# Playtest 2026-08-02: "fighting them feels fun", so the boss encounter
	# becomes recurring instead of a one-off. Capped at 4 alive: the fight is fun
	# in small numbers and miserable as a swarm, and that cap is now data
	# (EnemyStats.max_alive) rather than a rule someone has to remember.
	# THE SPLITTER — dies into two Darts, so clearing it carelessly makes the
	# problem worse. Punishes autopilot fire in a way no stat block can.
	# Tint was (1, 0.78, 0.2) — squarely in the HOT YELLOW the colour law reserves
	# for enemy fire ("nothing friendly is ever yellow"), so a Splitter body read
	# as a bolt. Review finding 18. Moved into the hostile band; the hollow
	# silhouette now carries the "something is inside it" read instead of hue.
	var splitter := _enemy(&"splitter", 6, 54.0, 1, 5, Color(0.93, 0.34, 0.94), EnemySize.MEDIUM, "enemy_splitter")
	splitter.split_into_path = "res://resources/enemies/dart.tres"
	splitter.split_count = 2

	# THE RAM — telegraphs, then commits to a straight dash it cannot steer out
	# of. The Lancer punishes standing still; this punishes standing in a LANE.
	# Review finding 8: the Ram wore the DART'S SPRITE and a hue 0.08 from the
	# Lancer's, while being the only enemy with a lethal committed dash. It now
	# has its own narrow wedge, rotates to face its target, and sits at the hot
	# end of the band well clear of the Lancer's pink.
	var ram := _enemy(&"ram", 7, 46.0, 2, 7, Color(1, 0.26, 0.2), EnemySize.LARGE, "enemy_ram")
	ram.behavior = EnemyStats.Behavior.CHARGE
	ram.charge_range = 215.0
	ram.charge_telegraph = 0.62
	ram.charge_speed = 440.0
	ram.charge_time = 0.44
	ram.charge_recover = 0.95

	# THE HEAVY LANCER — the first VARIANT rather than a new archetype, and the
	# proof that the shape=family / size+colour=variant rule actually buys
	# content. Same chevron silhouette, so it costs nothing to learn: bigger,
	# hotter, longer-ranged, and firing roughly 65% faster.
	#
	# It exists because 5:00-10:00 has to turn into bullet hell on the way to
	# Nogaxeh, and bullet hell means BOLTS. Adding more chasers would just be more
	# of the same pressure; the ranged threat is the one that fills space.
	var lancer_heavy := _enemy(&"lancer_heavy", 9, 58.0, 1, 11, Color(1, 0.3, 0.62), EnemySize.LARGE, "enemy_lancer")
	lancer_heavy.behavior = EnemyStats.Behavior.RANGED
	lancer_heavy.attack_range = 230.0
	lancer_heavy.attack_interval = 1.15
	lancer_heavy.bolt_speed = 165.0

	var shard := _enemy(&"shard", 90, 30.0, 2, 40, Color(1, 0.42, 0.85), EnemySize.HEAVY, "")
	shard.scene_path = "res://scenes/enemies/shard.tscn"
	shard.max_alive = 4

	var roster: Array[EnemyStats] = [drifter, dart, bulwark, lancer, lancer_heavy,
			splitter, ram, shard]
	for e: EnemyStats in roster:
		_save(e, "%s/%s.tres" % [ENEMIES, e.id])

	# start, interval, hp_mult, elite%, intensity, types, weights
	var waves: Array[WaveResource] = [
		_wave(&"opening", 0.0, 0.72, 1.0, 0.0, 0, [drifter], [1.0]),
		_wave(&"pressure", 45.0, 0.50, 1.3, 0.02, 1, [drifter, dart], [3.0, 2.0]),
		_wave(&"ranged", 95.0, 0.40, 1.6, 0.04, 1, [drifter, dart, lancer], [3.0, 2.0, 2.6]),
		_wave(&"swarm", 150.0, 0.31, 2.0, 0.07, 2, [drifter, dart, lancer, bulwark, splitter], [2.6, 3.0, 3.0, 1.1, 1.4]),
		_wave(&"surge", 220.0, 0.24, 2.6, 0.10, 2, [drifter, dart, lancer, bulwark, splitter, ram], [2.0, 3.5, 3.4, 1.5, 1.8, 1.4]),
		# 5:00 -> 10:00 IS THE GENRE SHIFT. The player has just been handed the
		# dash, so the pressure stops being "a crowd to swim through" and becomes
		# "a floor covered in bolts" — ranged weight climbs hard across these
		# three waves and the melee share falls to make room. By the time Nogaxeh
		# arrives, most of what is on screen shoots.
		_wave(&"endless_1", 300.0, 0.21, 3.4, 0.14, 2, [drifter, dart, lancer, lancer_heavy, bulwark, splitter, ram, shard], [1.4, 3.0, 4.4, 1.6, 1.6, 1.8, 1.8, 0.9]),
		_wave(&"endless_2", 420.0, 0.19, 4.4, 0.17, 2, [dart, lancer, lancer_heavy, bulwark, splitter, ram, shard], [2.6, 4.6, 3.6, 1.6, 2.0, 2.0, 1.2]),
		_wave(&"endless_3", 600.0, 0.21, 5.8, 0.20, 2, [dart, lancer, lancer_heavy, bulwark, splitter, ram, shard], [2.4, 4.4, 5.0, 1.8, 2.2, 2.2, 1.5]),
		_wave(&"endless_4", 900.0, 0.19, 7.6, 0.24, 2, [dart, lancer, lancer_heavy, bulwark, splitter, ram, shard], [2.4, 4.4, 5.6, 2.0, 2.4, 2.4, 1.8]),
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
	# Counted, not hardcoded: the literal "7" survived adding an eighth enemy and
	# cheerfully reported the wrong number, which is the same class of stale
	# self-report as UPGRADE_LIST's phantom generator (review finding 23).
	print("gen_waves: %d enemies + %d waves + schedule" % [roster.size(), waves.size()])
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
	if sprite != "" and ResourceLoader.exists(tex):
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
