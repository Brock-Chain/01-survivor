class_name VictoryScreen
extends CanvasLayer
## Shown paused when the first boss event is cleared.
##
## The reward is ALREADY banked before this appears — that is the whole point.
## Continuing into endless is pure upside, so trying it carries no anxiety, and
## a player who then dies at 8:00 still finished a run they won.

signal continued

@onready var stats_label: Label = %StatsLabel
@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	restart_button.pressed.connect(_on_restart)


## Review findings 2 and 27. The old screen said "Run banked." — jargon a
## stranger cannot parse — and never mentioned the unlock the player had just
## earned, which is the single strongest reason to press Continue or Restart.
## BRIEF.md:109 also specifies the button as "Continue (Endless)"; the shipped
## label had quietly drifted to "Continue".
func show_results(time_survived: float, kills: int, level: int,
		unlocks: Array[StringName] = []) -> void:
	var minutes: int = int(time_survived) / 60
	var seconds: int = int(time_survived) % 60
	var lines: PackedStringArray = [
		"THE PRISM IS DOWN — %02d:%02d" % [minutes, seconds],
		"%d kills · level %d" % [kills, level],
		"",
		"This win is already saved. Endless is pure upside:",
		"dying out there cannot take it back.",
	]
	for id: StringName in unlocks:
		lines.append("")
		lines.append("UNLOCKED — %s" % MetaState.unlock_label(id))
		lines.append(MetaState.unlock_blurb(id))
	stats_label.text = "\n".join(lines)
	visible = true
	continue_button.grab_focus()


func _on_continue() -> void:
	Sfx.play(&"click")
	visible = false
	get_tree().paused = false
	continued.emit()


func _on_restart() -> void:
	Sfx.play(&"click")
	get_tree().paused = false
	get_tree().reload_current_scene()
