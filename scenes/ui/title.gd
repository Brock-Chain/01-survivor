extends Control
## Click-to-start title. Exists for game feel AND because web builds
## cannot play audio until the first user gesture — the constraint IS
## the design.

@onready var track_button: Button = %TrackButton


func _ready() -> void:
	Music.play_title()
	%StartButton.pressed.connect(_on_start)
	track_button.pressed.connect(_cycle_track)
	_refresh_track_button()
	%StartButton.grab_focus()


func _on_start() -> void:
	Sfx.play(&"click")
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


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
