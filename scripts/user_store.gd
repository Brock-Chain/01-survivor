class_name UserStore
extends RefCounted
## The one place `user://` is parsed. JSON, and only JSON.
##
## Why not ConfigFile — measured on Godot 4.7.1, not assumed. A crafted `.cfg`
## makes `ConfigFile.load()` CONSTRUCT OBJECTS: `x=Object(Node,"name":"pwned")`
## returns a live Node, and `x=Resource("user://evil.tres")` builds a Resource
## with an attacker's script attached AND RUNS ITS `_init()` — inside `load()`,
## before the first `get_value()`, and therefore before any amount of tolerant
## type-checking can intervene. The old comment in this project claimed
## "ConfigFile is typed and cannot execute anything". That was false, and it was
## the reason recorded in a PUBLIC repo.
##
## The property we want is structural, not defensive: `JSON.parse_string()`
## returns only Dictionary/Array/String/float/bool/null. Its grammar has six
## value types and none of them is a class name — it is not that the parser
## refuses to build an object, it is that the syntax cannot express the request.
## Validation cannot save a parser that constructs objects, because construction
## happens during parsing.
##
## Full write-up: hub/knowledge/save-files-and-trust.md.
##
## GOTCHA: JSON numbers are IEEE-754 doubles. Anything that must survive a
## round trip bit-for-bit — a 64-bit seed, a large counter — is stored as a
## STRING. Nothing here needs that today; the next game's run seed will.

## Read a JSON object from `user://`. Anything unreadable, unparseable, or not
## an object reads as `{}` — a corrupt save costs progress, a crash on boot
## costs the whole game.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}  # no save yet is the normal first run, not a failure
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("UserStore: could not open %s (%d)" % [path, FileAccess.get_open_error()])
		return {}
	return parse(file.get_as_text())


## `JSON.new().parse()`, deliberately, NOT the `JSON.parse_string()` helper. The
## helper pushes an ENGINE error on malformed input, and a corrupt or hostile
## save is an expected condition here, not an engine fault — logging it as one
## means the smoke gate's `ERROR` grep goes red for a case the game handles by
## design. The instance form returns a status and stays quiet.
static func parse(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Variant = json.data
	return data as Dictionary if data is Dictionary else {}


static func write(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("UserStore: could not write %s (%d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


## Read a named section, always as a Dictionary. Two autoloads share
## `settings.json` and each owns one key; a section written as garbage by hand
## reads as empty rather than poisoning its owner.
static func section(path: String, name: String) -> Dictionary:
	var raw: Variant = read(path).get(name)
	return raw as Dictionary if raw is Dictionary else {}


## READ-MODIFY-WRITE, and that is load-bearing. `Audio` and `Settings` own
## different keys of one file and each saves independently; writing a fresh
## object from either would drop the other's values on the floor. Both had that
## bug once, in both directions.
static func merge_section(path: String, name: String, values: Dictionary) -> bool:
	var all: Dictionary = read(path)
	var existing: Variant = all.get(name)
	var merged: Dictionary = (existing as Dictionary).duplicate() if existing is Dictionary else {}
	merged.merge(values, true)
	all[name] = merged
	return write(path, all)


## Tolerant scalar reads. JSON gives every number back as a float, so an int
## field must be narrowed on the way in or `runs_played` becomes 12.0 and every
## comparison against it starts lying.
static func get_int(data: Dictionary, key: String, fallback: int) -> int:
	var raw: Variant = data.get(key)
	return int(raw) if raw is float or raw is int else fallback


static func get_float(data: Dictionary, key: String, fallback: float) -> float:
	var raw: Variant = data.get(key)
	return float(raw) if raw is float or raw is int else fallback


static func get_bool(data: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = data.get(key)
	return raw as bool if raw is bool else fallback
