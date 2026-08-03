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
	# Was `_close()`, which DROPPED the previous run's ending row. Both of the only
	# two runs that ever reached a boss ended by restart, so both were missing
	# `run_end` and the endings report systematically omitted exactly the runs that
	# mattered. Main finishes its own run now, so this is the belt-and-braces path:
	# if it ever fires, something bypassed Main and that is worth seeing in the log.
	end_run("interrupted")
	# ...and reset the clock, or the new run's `run_start` is stamped with the
	# PREVIOUS run's elapsed time (run_080 opened at t:660.2).
	_run_t = 0.0
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = "%s/run_%03d.jsonl" % [DIR, _next_index()]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("Telemetry: cannot write %s" % path)
		enabled = false
		return
	print("[telemetry] %s" % ProjectSettings.globalize_path(path))
	# `dev` and `commit` exist because establishing that run_076 was played clean
	# took a cross-check of save.cfg's best_time against a victory event. A run
	# that cannot say what it was played with is not evidence.
	event(&"run_start", {
		"seed": seed_value,
		"started": Time.get_datetime_string_from_system(true),
		"dev": _dev_flags(),
		"commit": _git_head(),
	})


## The `--dev-` flags active for this run. Empty means a clean run — the single
## most important fact about a telemetry file, and until now it recorded nothing.
func _dev_flags() -> Array[String]:
	var flags: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-"):
			flags.append(arg)
	return flags


## Short commit hash, read straight from .git — no build step, no generated file.
## Only ever non-empty when running from source, which is how playtests happen;
## an exported build has no .git in its PCK and simply reports "".
func _git_head() -> String:
	var head: FileAccess = FileAccess.open("res://.git/HEAD", FileAccess.READ)
	if head == null:
		return ""
	var line: String = head.get_line().strip_edges()
	if not line.begins_with("ref: "):
		return line.substr(0, 8)  # detached HEAD stores the sha itself
	var ref: FileAccess = FileAccess.open("res://.git/" + line.substr(5), FileAccess.READ)
	if ref == null:
		return ""  # a packed ref; not worth a parser
	return ref.get_line().strip_edges().substr(0, 8)


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
	# Always flush on the periodic tick, not just every N events. Without this a
	# run sits entirely in the OS buffer until 40 events accumulate, so a
	# partially-played run reads as a 0-byte file and closing the window mid-run
	# can lose the lot. A flush every 5s costs nothing at this write volume.
	if _pending >= FLUSH_EVERY or type == &"tick":
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


## Last resort only. This used to also fire on NOTIFICATION_WM_CLOSE_REQUEST,
## which an autoload receives BEFORE the main scene does — so every window-close
## wrote a bare `quit` row with no kills, level or outcome, and Main's finish
## found the file already closed. Main owns the ending now (it is the only node
## that knows what the run achieved); PREDELETE runs after Main's _exit_tree, so
## a `lost` row means nothing finalised the run and that is a bug worth seeing.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		end_run("lost")
