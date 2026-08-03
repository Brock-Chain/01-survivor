class_name VictoryScreen
extends CanvasLayer
## Shown paused when the first boss event is cleared.
##
## The reward is ALREADY banked before this appears — that is the whole point.
## Continuing into endless is pure upside, so trying it carries no anxiety, and
## a player who then dies at 8:00 still finished a run they won.
##
## Rebuilt 2026-08-03 ("prism shattered ui sucks"). Two separate problems wore
## the same costume, and only one of them was layout:
##
##   1. It OVERFLOWED. Every line lived in one Label — including a heading and a
##      full blurb per unlock — inside a CenterContainer, which centres oversized
##      content by running off BOTH ends. Two unlocks put the buttons under the
##      bottom of the viewport. The true ending hit this at 633px and was fixed
##      by "unlock NAMES only"; this screen never got that fix.
##   2. It had NO HIERARCHY. Title, stats, reassurance and rewards were all the
##      same centred grey text at the same size, so the run's numbers and the
##      thing the player had just earned read as fine print.
##
## Both are structural, so the fix is structural: the numbers are a scoreboard,
## the unlocks are chips, and the layout is bounded by a harness case that did
## not exist before (pause_layout_check covered four screens and not this one).

signal continued

## Unlock chips borrow the pause panel's build-chip construction rather than
## inventing a second framed-pill style. One chip idiom, two screens.
const CHIP_HUE: Color = Color(0.55, 1.0, 0.86)

@onready var time_value: Label = %TimeValue
@onready var kills_value: Label = %KillsValue
@onready var level_value: Label = %LevelValue
@onready var unlock_header: Label = %UnlockHeader
@onready var unlocks_row: HFlowContainer = %Unlocks
@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	restart_button.pressed.connect(_on_restart)


## Review findings 2 and 27. The old screen said "Run banked." — jargon a
## stranger cannot parse — and never mentioned the unlock the player had just
## earned, which is the single strongest reason to press Continue or Restart.
##
## Unlocks are NAMED, never blurbed. That is the true ending's lesson applied
## here: a blurb per unlock is three lines each, it is what overflowed this
## screen, and the HUD already announced each one the moment it was earned.
func show_results(time_survived: float, kills: int, level: int,
		unlocks: Array[StringName] = []) -> void:
	var minutes: int = int(time_survived) / 60
	var seconds: int = int(time_survived) % 60
	time_value.text = "%02d:%02d" % [minutes, seconds]
	kills_value.text = str(kills)
	level_value.text = str(level)

	for child: Node in unlocks_row.get_children():
		child.queue_free()
	# The header earns its line only when there is something under it. An empty
	# "UNLOCKED" heading over nothing reads as a bug, and on a repeat victory
	# (everything already owned) that is exactly what would render.
	unlock_header.visible = not unlocks.is_empty()
	unlocks_row.visible = not unlocks.is_empty()
	for id: StringName in unlocks:
		unlocks_row.add_child(_make_chip(MetaState.unlock_label(id)))

	visible = true
	continue_button.grab_focus()


## One framed pill per unlock, in the screen's own cyan-green. A chip rather than
## a text line because the reward has to look like a reward: at 640x360 a framed
## shape is legible as "you got something" before a single word is read.
func _make_chip(label_text: String) -> Control:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.14, 0.13, 0.92)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = CHIP_HUE
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_right = 2
	box.corner_radius_bottom_left = 2
	box.content_margin_left = 9.0
	box.content_margin_right = 9.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", box)

	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override(&"font_color", CHIP_HUE)
	label.add_theme_font_size_override(&"font_size", 11)
	panel.add_child(label)
	return panel


func _on_continue() -> void:
	Sfx.play(&"click")
	visible = false
	get_tree().paused = false
	continued.emit()


func _on_restart() -> void:
	Sfx.play(&"click")
	get_tree().paused = false
	get_tree().reload_current_scene()
