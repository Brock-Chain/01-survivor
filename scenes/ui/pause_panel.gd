class_name PausePanel
extends CanvasLayer
## Pause + build sheet. Runs WHILE the tree is paused (process_mode WHEN_PAUSED),
## the same split the level-up screen uses.
##
## Exists because nothing in the run told you what you had taken. By level 30 a
## player has made thirty choices and can see none of them, which makes those
## choices feel less consequential than they were. Showing the build is the
## cheapest way to make a long run read as authored rather than accumulated.
##
## Grouped by RARITY, best first: the Legendary you pulled is the story of the
## run, so it should not sit buried alphabetically between two Commons.

signal resumed

const COLS: int = 3

@onready var stats_label: Label = %StatsLabel
@onready var grid: GridContainer = %Grid
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var mute_button: Button = %MuteButton


func _ready() -> void:
	grid.columns = COLS
	resume_button.pressed.connect(resume)
	restart_button.pressed.connect(_on_restart)
	quit_button.pressed.connect(_on_quit)
	music_slider.value = Audio.music_volume
	sfx_slider.value = Audio.sfx_volume
	music_slider.value_changed.connect(func(v: float) -> void: Audio.set_music_volume(v))
	sfx_slider.value_changed.connect(func(v: float) -> void: Audio.set_sfx_volume(v))
	mute_button.pressed.connect(toggle_mute)
	_refresh_mute()


## Also reachable by the M key while unpaused, so muting never requires stopping.
func toggle_mute() -> void:
	Audio.set_muted(not Audio.muted)
	_refresh_mute()


func _refresh_mute() -> void:
	mute_button.text = "UNMUTE (M)" if Audio.muted else "MUTE (M)"


## `stacks` is id -> times taken. `pool` is every upgrade, so an id resolves back
## to a display name and tier without the caller knowing about either.
func show_build(pool: Array[UpgradeResource], stacks: Dictionary,
		level: int, time_survived: float, kills: int) -> void:
	var minutes: int = int(time_survived) / 60
	var seconds: int = int(time_survived) % 60
	stats_label.text = "LEVEL %d   -   %02d:%02d   -   %d KILLS" % [
			level, minutes, seconds, kills]

	for child: Node in grid.get_children():
		child.queue_free()

	var taken: Array[UpgradeResource] = []
	for u: UpgradeResource in pool:
		if int(stacks.get(u.id, 0)) > 0:
			taken.append(u)
	taken.sort_custom(func(a: UpgradeResource, b: UpgradeResource) -> bool:
		if a.rarity != b.rarity:
			return int(a.rarity) > int(b.rarity)
		return a.display_name < b.display_name)

	if taken.is_empty():
		var empty := Label.new()
		empty.text = "No upgrades yet."
		empty.add_theme_color_override(&"font_color", Color(0.55, 0.66, 0.82))
		grid.add_child(empty)
	else:
		for u: UpgradeResource in taken:
			grid.add_child(_make_chip(u, int(stacks.get(u.id, 0))))

	visible = true
	resume_button.grab_focus()


## One chip per upgrade, framed in its rarity colour, so a build reads as a
## spread of tiers at a glance instead of a list to be read word by word.
func _make_chip(upgrade: UpgradeResource, count: int) -> Control:
	var hue: Color = Rarity.color_of(upgrade.rarity)
	var glow: float = Rarity.glow_of(upgrade.rarity)

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.07, 0.14, 0.9)
	var width: int = 1 + int(round(glow * 1.5))
	box.border_width_left = width
	box.border_width_top = width
	box.border_width_right = width
	box.border_width_bottom = width
	box.border_color = hue.lightened(0.1 * glow)
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_right = 2
	box.corner_radius_bottom_left = 2
	if glow > 0.0:
		box.shadow_color = Color(hue.r, hue.g, hue.b, 0.22 * glow)
		box.shadow_size = int(round(1 + glow * 5))
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", box)
	panel.custom_minimum_size = Vector2(170, 0)

	var label := Label.new()
	# A stack count only earns its space once there IS a stack.
	label.text = upgrade.display_name if count <= 1 else "%s x%d" % [
			upgrade.display_name, count]
	label.add_theme_color_override(&"font_color", hue.lightened(0.35))
	label.add_theme_font_size_override(&"font_size", 12)
	label.clip_text = true
	panel.add_child(label)
	return panel


func resume() -> void:
	Sfx.play(&"click")
	visible = false
	get_tree().paused = false
	resumed.emit()


func _on_quit() -> void:
	Sfx.play(&"click")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
