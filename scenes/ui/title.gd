extends Control
## Click-to-start title. Exists for game feel AND because web builds
## cannot play audio until the first user gesture — the constraint IS
## the design.

@onready var track_button: Button = %TrackButton
@onready var lattice_button: Button = %LatticeButton
@onready var mark: TextureRect = %Mark
@onready var record_label: Label = %RecordLabel

## Slow enough to read as "alive" rather than as a loading spinner. Six-fold
## symmetry means it never looks upside-down, so it can just keep turning.
const MARK_SPIN: float = 0.35


func _ready() -> void:
	# Review finding 19: on WEB the browser's audio context stays suspended until
	# the first real user gesture, so a theme started here was silent — and the
	# gesture that would have unblocked it (clicking START) immediately changes
	# scene and stops it. The 64-second title theme was therefore unhearable on
	# the build most players get, while this file's own header comment already
	# named the constraint. On desktop there is no such gate, so it plays at once.
	if OS.has_feature("web"):
		set_process_input(true)
	else:
		Music.play_title()
	%StartButton.pressed.connect(_on_start)
	track_button.pressed.connect(_cycle_track)
	lattice_button.pressed.connect(_on_lattice)
	# The shard balance is on the button itself. A menu entry that says only
	# "THE LATTICE" gives a first-time player no reason to look inside it, and
	# the whole currency is invisible until they do.
	lattice_button.text = "THE LATTICE  ·  %d ◆" % Meta.state.shards
	_refresh_track_button()
	mark.pivot_offset = mark.size * 0.5
	_show_record()
	%StartButton.grab_focus()


func _process(delta: float) -> void:
	mark.rotation += MARK_SPIN * delta


## The title screen never read Meta at all, so a returning player was greeted
## exactly like a stranger — no record, no evidence the game remembered them.
## Part of review finding 10, and the cheapest possible reason to press START.
func _show_record() -> void:
	var best: float = Meta.state.best_time
	if Meta.state.victories > 0:
		record_label.text = "%d win%s · best %02d:%02d" % [
				Meta.state.victories, "" if Meta.state.victories == 1 else "s",
				int(best) / 60, int(best) % 60]
	elif best > 0.0:
		record_label.text = "best %02d:%02d — the Prism is still standing" % [
				int(best) / 60, int(best) % 60]
	else:
		record_label.text = ""


## Web only (see _ready). The first gesture of ANY kind unblocks the audio
## context, so the theme starts then rather than never.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton
			or event is InputEventScreenTouch):
		return
	set_process_input(false)
	Music.play_title()


func _on_start() -> void:
	Sfx.play(&"click")
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_lattice() -> void:
	Sfx.play(&"click")
	get_tree().change_scene_to_file("res://scenes/ui/skill_tree.tscn")


## Testing aid: cycle AUTO / each built track. Session only — a dev affordance,
## not a saved preference. AUTO rotates to a different track each run, which is
## most of what keeps a 16-second loop from wearing out.
func _cycle_track() -> void:
	Sfx.play(&"click")
	var options: Array[int] = Music.available_tracks()
	if options.is_empty():
		return
	if Music.forced_track < 0:
		Music.forced_track = options[0]
	else:
		var at: int = options.find(Music.forced_track)
		Music.forced_track = -1 if at < 0 or at + 1 >= options.size() else options[at + 1]
	_refresh_track_button()


func _refresh_track_button() -> void:
	if Music.forced_track < 0:
		track_button.text = "MUSIC: AUTO (rotates)"
	else:
		track_button.text = "MUSIC: %s" % Music.track_name(Music.forced_track)
