extends GutTest
## Run/meta separation, unlock rules, and save round-trips.
##
## This is the system V2 reuses wholesale, so its invariants are tested here
## where they are still cheap to change. No file I/O: ConfigFile round-trips
## through text in memory, which tests the same serialization path.


func _result(kills: int, time: float, won: bool) -> Dictionary:
	return {"seed": 1, "time": time, "kills": kills, "level": 5, "won": won}


func _round_trip(m: MetaState) -> MetaState:
	var out := ConfigFile.new()
	m.to_config(out)
	var back := ConfigFile.new()
	assert_eq(back.parse(out.encode_to_text()), OK, "config parses")
	return MetaState.from_config(back)


# --- run / meta separation --------------------------------------------------

func test_absorb_takes_values_not_a_reference() -> void:
	var meta := MetaState.new()
	var run := RunState.with_seed(42)
	run.kills = 10
	run.elapsed = 100.0
	meta.absorb(run.to_result())
	# Mutating the run afterwards must not reach into the saved record.
	run.kills = 9999
	run.elapsed = 9999.0
	assert_eq(meta.best_kills, 10, "meta kept its own copy")
	assert_eq(meta.best_time, 100.0)


func test_run_state_result_is_a_flat_snapshot() -> void:
	var run := RunState.with_seed(7)
	run.kills = 3
	var first: Dictionary = run.to_result()
	run.kills = 4
	assert_eq(int(first["kills"]), 3, "an earlier snapshot is not live")


func test_unlocks_array_is_not_aliased_by_round_trip() -> void:
	var meta := MetaState.new()
	meta.absorb(_result(5, 10.0, true))
	var loaded := _round_trip(meta)
	loaded.unlocks.append(&"injected")
	assert_false(meta.has_unlock(&"injected"), "loaded state is independent")


# --- records ----------------------------------------------------------------

func test_records_keep_the_best_not_the_last() -> void:
	var meta := MetaState.new()
	meta.absorb(_result(50, 300.0, false))
	meta.absorb(_result(10, 60.0, false))
	assert_eq(meta.best_kills, 50, "a worse run never lowers a record")
	assert_eq(meta.best_time, 300.0)
	assert_eq(meta.runs_played, 2)
	assert_eq(meta.total_kills, 60, "totals accumulate, records do not")


# --- unlock rules -----------------------------------------------------------

func test_first_victory_unlocks_the_orbital() -> void:
	var meta := MetaState.new()
	assert_false(meta.has_unlock(MetaState.UNLOCK_ORBITAL))
	var gained := meta.absorb(_result(200, 320.0, true))
	assert_true(gained.has(MetaState.UNLOCK_ORBITAL), "reported as newly gained")
	assert_true(meta.has_unlock(MetaState.UNLOCK_ORBITAL))


func test_losing_never_unlocks_the_orbital() -> void:
	var meta := MetaState.new()
	assert_eq(meta.absorb(_result(500, 290.0, false)).size(), 0)
	assert_false(meta.has_unlock(MetaState.UNLOCK_ORBITAL))


func test_an_unlock_is_reported_once_and_kept_forever() -> void:
	var meta := MetaState.new()
	meta.absorb(_result(200, 320.0, true))
	var second := meta.absorb(_result(200, 320.0, true))
	assert_false(second.has(MetaState.UNLOCK_ORBITAL), "not re-reported")
	assert_true(meta.has_unlock(MetaState.UNLOCK_ORBITAL), "still held")


func test_banked_victory_survives_dying_in_endless() -> void:
	# BRIEF: continuing is pure upside — a later loss can never revoke a win.
	var meta := MetaState.new()
	meta.absorb(_result(200, 320.0, true))
	meta.absorb(_result(5, 30.0, false))
	assert_true(meta.has_unlock(MetaState.UNLOCK_ORBITAL))
	assert_eq(meta.victories, 1)


# --- persistence ------------------------------------------------------------

func test_save_round_trip_preserves_everything() -> void:
	var meta := MetaState.new()
	meta.absorb(_result(120, 340.0, true))
	meta.absorb(_result(80, 150.0, false))
	var loaded := _round_trip(meta)
	assert_eq(loaded.runs_played, meta.runs_played)
	assert_eq(loaded.victories, meta.victories)
	assert_eq(loaded.best_kills, meta.best_kills)
	assert_almost_eq(loaded.best_time, meta.best_time, 0.001)
	assert_eq(loaded.total_kills, meta.total_kills)
	assert_true(loaded.has_unlock(MetaState.UNLOCK_ORBITAL), "unlocks survive")


func test_empty_config_loads_as_a_fresh_profile() -> void:
	var loaded := MetaState.from_config(ConfigFile.new())
	assert_eq(loaded.runs_played, 0)
	assert_eq(loaded.unlocks.size(), 0)


func test_corrupt_values_fall_back_instead_of_crashing() -> void:
	# A corrupt save costs progress; a crash on boot costs the whole game.
	var cfg := ConfigFile.new()
	cfg.set_value(MetaState.SECTION, "runs_played", "not a number")
	cfg.set_value(MetaState.SECTION, "unlocks", "not an array")
	var loaded := MetaState.from_config(cfg)
	assert_eq(loaded.runs_played, 0)
	assert_eq(loaded.unlocks.size(), 0)


func test_duplicate_unlocks_in_a_save_are_collapsed() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(MetaState.SECTION, "unlocks", ["orbital", "orbital"])
	assert_eq(MetaState.from_config(cfg).unlocks.size(), 1)


func test_endless_survival_earns_endless_proven_via_update_records() -> void:
	# The exact shape of a real winning run: banked at victory (~5:20), then
	# death in endless past 10:00. Absorb sees time=320 so it can never grant
	# ENDLESS_PROVEN; the records-only update after the endless death must.
	var meta := MetaState.new()
	meta.absorb(_result(200, 320.0, true))
	assert_false(meta.has_unlock(MetaState.UNLOCK_ENDLESS_PROVEN),
			"not proven at the banking point")
	var gained: Array[StringName] = meta.update_records(_result(900, 640.0, true))
	assert_true(meta.has_unlock(MetaState.UNLOCK_ENDLESS_PROVEN),
			"surviving to the double boss earns it")
	assert_true(gained.has(MetaState.UNLOCK_ENDLESS_PROVEN), "and it is reported")
	assert_eq(meta.runs_played, 1, "endless still never counts as a second run")


func test_update_records_reports_an_unlock_only_once() -> void:
	var meta := MetaState.new()
	meta.absorb(_result(200, 320.0, true))
	meta.update_records(_result(900, 640.0, true))
	assert_eq(meta.update_records(_result(950, 700.0, true)).size(), 0)


# --- seeding ----------------------------------------------------------------

func test_same_seed_reproduces_the_same_draw() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	var run := RunState.with_seed(20260802)
	a.seed = run.seed_value
	b.seed = RunState.with_seed(20260802).seed_value
	for i: int in 8:
		assert_eq(a.randi(), b.randi(), "draw %d matches" % i)
