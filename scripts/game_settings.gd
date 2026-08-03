extends Node
## Autoload `Settings`: gameplay preferences that are not audio, persisted.
##
## Shares `user://settings.json` with the Audio autoload but owns its own key.
## The two answer different questions — a player who muted the game has not asked
## for a calmer camera — and sharing one file is what keeps "the settings" a
## single thing the player can delete.
##
## JSON rather than a Resource or ConfigFile, for the same reason MetaState and
## Audio use it: this path is user-writable, and any parser that constructs
## objects while parsing is an execution surface. See `UserStore`.

const SAVE_PATH: String = "user://settings.json"
const SECTION: String = "game"

## Playtest 2026-08-03: "Camera shake is too much. We should tune it down AND add
## a toggle in menu to turn it off." The tune-down is GameCamera.MAX_OFFSET; this
## is the opt-out on top of it.
##
## Both, not either. Tuning serves the median player and an opt-out serves the
## one who gets motion sick, and no amount of the first fixes the second.
var shake_enabled: bool = true


func _ready() -> void:
	# The pause panel that toggles this runs WHILE the tree is paused, so an
	# autoload it calls into cannot be PAUSABLE.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()


func set_shake_enabled(value: bool) -> void:
	shake_enabled = value
	_save()


## The multiplier GameCamera applies. A float rather than a branch at the call
## site, so the camera keeps ONE code path and the off case cannot drift away
## from the on case as trauma tuning changes around it.
func shake_scale() -> float:
	return 1.0 if shake_enabled else 0.0


func _load() -> void:
	# Missing, corrupt and hostile all read as {} and fall back to the default.
	var data: Dictionary = UserStore.section(SAVE_PATH, SECTION)
	shake_enabled = UserStore.get_bool(data, "shake", true)


## READ-MODIFY-WRITE, and that is load-bearing. `Audio` owns the "audio" key of
## this same file and saves on every slider drag; writing a fresh object here
## would drop its volumes on the floor. (Audio's own `_save` had exactly that
## bug in the other direction and was fixed alongside this file — the first
## setting to share the file is what exposed it.) `merge_section` is that rule
## made structural, so the next owner of this file cannot reintroduce it.
func _save() -> void:
	UserStore.merge_section(SAVE_PATH, SECTION, {"shake": shake_enabled})
