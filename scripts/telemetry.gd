extends Node
## Autoload `Telemetry`: records a playtest as newline-delimited JSON so balance
## questions become measurements instead of opinions.
##
## Writes to `user://telemetry/run_NNN.jsonl`, one JSON object per line. JSONL
## rather than a Resource because this is a LOG, not authored content: it is
## append-only, survives a crash mid-run (every line already written is still
## valid), and `tools/analyze_telemetry.py` can stream it without Godot.
##
## OFF by default. Enabled by `--dev-telemetry`, or automatically in a debug
## build on desktop. Never on web: `user://` there is browser storage we have no
## way to read back, so it would cost writes and return nothing.
##
## Local only. Nothing is transmitted anywhere.

const DIR: String = "user://telemetry"
const FLUSH_EVERY: int = 40

var enabled: bool = false

var _file: FileAccess
var _pending: int = 0
var _run_t: float = 0.0


func _ready() -> void:
	var forced: bool = OS.get_cmdline_user_args().has("--dev-telemetry")
	var web: bool = OS.get_name() == "Web"
	enabled = forced or (OS.is_debug_build() and not web)
	if web:
		enabled = false


func begin_run(seed_value: int) -> void:
	if not enabled:
		return
	_close()
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = "%s/run_%03d.jsonl" % [DIR, _next_index()]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("Telemetry: cannot write %s" % path)
		enabled = false
		return
	print("[telemetry] %s" % ProjectSettings.globalize_path(path))
	event(&"run_start", {
		"seed": seed_value,
		"started": Time.get_datetime_string_from_system(true),
	})


func _next_index() -> int:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return 1
	var n: int = 0
	for f: String in dir.get_files():
		if f.begins_with("run_") and f.ends_with(".jsonl"):
			n += 1
	return n + 1


## `t` is stamped here from the run clock so every event is comparable without
## the caller having to remember to pass it.
func event(type: StringName, data: Dictionary = {}) -> void:
	if not enabled or _file == null:
		return
	var row: Dictionary = {"t": snappedf(_run_t, 0.01), "e": String(type)}
	row.merge(data)
	_file.store_line(JSON.stringify(row))
	_pending += 1
	if _pending >= FLUSH_EVERY:
		_file.flush()
		_pending = 0


## Main pushes the run clock in so Telemetry never needs to know about the
## director, the pause state, or who owns time.
func set_run_time(t: float) -> void:
	_run_t = t


func end_run(reason: String, data: Dictionary = {}) -> void:
	if not enabled or _file == null:
		return
	var row: Dictionary = {"reason": reason}
	row.merge(data)
	event(&"run_end", row)
	_close()


func _close() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null
	_pending = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_close()
