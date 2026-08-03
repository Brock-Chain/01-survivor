extends Node
## Autoload `Audio`: volume and mute, persisted.
##
## Separate from the Music autoload because it governs the BUSES, not the
## soundtrack — SFX obey it too, and it has to survive the title screen, a run,
## and a scene reload alike. Persisted as JSON through `UserStore`, for the same
## reason MetaState is: this path is user-writable, and a parser that constructs
## objects while parsing (`.tres` or ConfigFile alike) is an execution surface.

const SAVE_PATH: String = "user://settings.json"
const SECTION: String = "audio"
## Below this the slider is effectively off, so silence it properly rather than
## leaving a -60dB whisper that still costs mixing.
const MIN_LINEAR: float = 0.02

var music_volume: float = 0.8
var sfx_volume: float = 0.8
var muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply()
	_save()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply()
	_save()


func set_muted(value: bool) -> void:
	muted = value
	_apply()
	_save()


func _apply() -> void:
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"SFX", sfx_volume)


## Sliders are LINEAR because that is what a person expects to drag; buses are in
## decibels. linear_to_db is the conversion, and anything under the floor is
## muted outright rather than left as an inaudible-but-mixed signal.
func _apply_bus(bus_name: StringName, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var silent: bool = muted or linear <= MIN_LINEAR
	AudioServer.set_bus_mute(idx, silent)
	if not silent:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _load() -> void:
	# A missing file, a corrupt file and a hostile file all arrive here as {},
	# and every field below has a default. No settings yet is the normal first
	# run, not a failure.
	var data: Dictionary = UserStore.section(SAVE_PATH, SECTION)
	music_volume = clampf(UserStore.get_float(data, "music", 0.8), 0.0, 1.0)
	sfx_volume = clampf(UserStore.get_float(data, "sfx", 0.8), 0.0, 1.0)
	muted = UserStore.get_bool(data, "muted", false)


## READ-MODIFY-WRITE, via `merge_section`. Writing a fresh object here was
## invisible while audio owned the whole file and became data loss the moment
## anything else shared it: `Settings` owns the "game" key of this same path, and
## one drag of the music slider would have erased it. Merging is what makes two
## independent owners of one file safe.
func _save() -> void:
	UserStore.merge_section(SAVE_PATH, SECTION, {
		"music": music_volume, "sfx": sfx_volume, "muted": muted,
	})
