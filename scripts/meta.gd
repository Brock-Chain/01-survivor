extends Node
## Autoload `Meta`: owns the persistent MetaState and its file.
##
## The ONLY thing that touches user://. Everything else asks this node, so there
## is exactly one place where a save can be written, and exactly one place to
## look when progress goes missing.

signal unlocked(ids: Array[StringName])

## `.json`, not `.cfg` — see `UserStore` for the measurement behind that. The
## extension change is deliberate and doubles as the migration: an old `save.cfg`
## is simply never read again, rather than needing a converter that would have to
## parse it with the very parser being retired. The file is left on disk, not
## deleted, so nothing is destroyed by the switch — but records and unlocks in an
## existing profile do start from zero.
const SAVE_PATH: String = "user://save.json"
## Where dev runs write instead. Review finding 12: `--dev-godmode` soaks and
## `--dev-autopick` bots banked EVERY run into the real profile, which is how the
## shipping save ended up with best_kills=1047 and an `elite_hunter` unlock that
## no human earned. Records that came from a bot are worse than no records: they
## silently retire the near-miss line on the death screen forever.
const DEV_SAVE_PATH: String = "user://save_dev.json"

## The file actually in use. A var, not a const, so Main can redirect it before
## anything is written. Everything still goes through this one node, so there is
## still exactly one place a save can be written and one place to look.
var save_path: String = SAVE_PATH

var state: MetaState = MetaState.new()


## Previous `config/name` values, newest first. Renaming the application moves
## `user://` wholesale — it happened once already when the project became PRISM,
## and the save plus forty telemetry runs had to be hand-copied on one machine.
## Doing it in code this time, because the telemetry baseline the whole balance
## pass rests on is not something a rename should be allowed to orphan.
const LEGACY_APP_DIRS: Array[String] = ["PRISM", "01-survivor"]
## The `.json` names only. The old `.cfg` files are deliberately NOT carried
## across: nothing reads that format any more, so copying them would move dead
## bytes and imply a migration that does not happen.
const MIGRATED_FILES: Array[String] = ["save.json", "settings.json"]


func _ready() -> void:
	_migrate_legacy_user_data()
	load_state()


## Copy a previous name's user data across, ONCE, and only into a profile that
## does not exist yet. A player who already has a BESTAGON save is never touched.
func _migrate_legacy_user_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		return
	var current: String = OS.get_user_data_dir()
	var parent: String = current.get_base_dir()
	for legacy: String in LEGACY_APP_DIRS:
		var old: String = parent.path_join(legacy)
		if old == current or not DirAccess.dir_exists_absolute(old):
			continue
		var moved: int = 0
		for name: String in MIGRATED_FILES:
			if _copy_file(old.path_join(name), current.path_join(name)):
				moved += 1
		moved += _copy_dir(old.path_join("telemetry"), current.path_join("telemetry"))
		print("[meta] migrated %d file(s) from %s" % [moved, old])
		return


func _copy_file(from: String, to: String) -> bool:
	if not FileAccess.file_exists(from) or FileAccess.file_exists(to):
		return false
	var src: FileAccess = FileAccess.open(from, FileAccess.READ)
	if src == null:
		return false
	var dst: FileAccess = FileAccess.open(to, FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_buffer(src.get_buffer(src.get_length()))
	return true


## Flat copy — telemetry has no subdirectories, and a general recursive copy is
## more failure modes than this needs.
func _copy_dir(from: String, to: String) -> int:
	if not DirAccess.dir_exists_absolute(from):
		return 0
	DirAccess.make_dir_recursive_absolute(to)
	var moved: int = 0
	for name: String in DirAccess.get_files_at(from):
		if _copy_file(from.path_join(name), to.path_join(name)):
			moved += 1
	return moved


## Called by Main the moment ANY --dev- flag is seen, before the run starts and
## therefore before absorb_run can fire. Reloads, so a dev run sees the dev
## profile's progress rather than the human's.
func use_dev_profile() -> void:
	if save_path == DEV_SAVE_PATH:
		return
	save_path = DEV_SAVE_PATH
	load_state()
	print("[dev] save redirected to %s" % save_path)


func load_state() -> void:
	# UserStore.read returns {} for missing, unreadable or corrupt, and
	# MetaState.from_dict defaults every field — so a first run and a hostile
	# file take the same path, which is the point.
	state = MetaState.from_dict(UserStore.read(save_path))


func save_state() -> bool:
	return UserStore.write(save_path, state.to_dict())


## End-of-run entry point. Takes the flat result Dictionary so the run's objects
## never cross into persistent state.
func absorb_run(result: Dictionary) -> Array[StringName]:
	var gained: Array[StringName] = state.absorb(result)
	save_state()
	if not gained.is_empty():
		unlocked.emit(gained)
	return gained


## For a run banked at victory that then continued into endless: improve the
## records and earn late milestones without counting a second run.
func update_records(result: Dictionary) -> void:
	var gained: Array[StringName] = state.update_records(result)
	save_state()
	if not gained.is_empty():
		unlocked.emit(gained)


func has_unlock(id: StringName) -> bool:
	return state.has_unlock(id)


## Dev/testing escape hatch — also what a "clear progress" button would call.
func reset() -> void:
	state = MetaState.new()
	save_state()
