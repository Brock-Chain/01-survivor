extends Node
## Autoload `Audio`: volume and mute, persisted.
##
## Separate from the Music autoload because it governs the BUSES, not the
## soundtrack — SFX obey it too, and it has to survive the title screen, a run,
## and a scene reload alike. Kept in the same ConfigFile as the save for the same
## reason MetaState uses one: it is user-writable, so it must not be a Resource.

const SAVE_PATH: String = "user://settings.cfg"
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
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # no settings yet is the normal first run, not a failure
	music_volume = clampf(float(cfg.get_value(SECTION, "music", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value(SECTION, "sfx", 0.8)), 0.0, 1.0)
	muted = bool(cfg.get_value(SECTION, "muted", false))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "music", music_volume)
	cfg.set_value(SECTION, "sfx", sfx_volume)
	cfg.set_value(SECTION, "muted", muted)
	cfg.save(SAVE_PATH)
