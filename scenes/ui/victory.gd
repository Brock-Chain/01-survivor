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


func show_results(time_survived: float, kills: int, level: int) -> void:
	var minutes: int = int(time_survived) / 60
	var seconds: int = int(time_survived) % 60
	stats_label.text = "The Prism is down at %02d:%02d\n%d kills — level %d\nRun banked." % [
			minutes, seconds, kills, level]
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
