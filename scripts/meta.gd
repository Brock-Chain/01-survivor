extends Node
## Autoload `Meta`: owns the persistent MetaState and its file.
##
## The ONLY thing that touches user://. Everything else asks this node, so there
## is exactly one place where a save can be written, and exactly one place to
## look when progress goes missing.

signal unlocked(ids: Array[StringName])

const SAVE_PATH: String = "user://save.cfg"

var state: MetaState = MetaState.new()


func _ready() -> void:
	load_state()


func load_state() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(SAVE_PATH)
	if err != OK:
		# No save yet is the normal first-run path, not a failure.
		state = MetaState.new()
		return
	state = MetaState.from_config(cfg)


func save_state() -> bool:
	var cfg := ConfigFile.new()
	state.to_config(cfg)
	var err: int = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Meta: could not write %s (%d)" % [SAVE_PATH, err])
		return false
	return true


## End-of-run entry point. Takes the flat result Dictionary so the run's objects
## never cross into persistent state.
func absorb_run(result: Dictionary) -> Array[StringName]:
	var gained: Array[StringName] = state.absorb(result)
	save_state()
	if not gained.is_empty():
		unlocked.emit(gained)
	return gained


## For a run banked at victory that then continued into endless: improve the
## records without counting a second run.
func update_records(result: Dictionary) -> void:
	state.update_records(result)
	save_state()


func has_unlock(id: StringName) -> bool:
	return state.has_unlock(id)


## Dev/testing escape hatch — also what a "clear progress" button would call.
func reset() -> void:
	state = MetaState.new()
	save_state()
