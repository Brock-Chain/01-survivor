class_name GameOverScreen
extends CanvasLayer
## Shown paused. Restart reloads the whole main scene — the cheapest
## correct way to reset a run.

@onready var stats_label: Label = %StatsLabel
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)


func show_results(time_survived: float, kills: int, level: int) -> void:
	var minutes: int = int(time_survived) / 60
	var seconds: int = int(time_survived) % 60
	stats_label.text = "You survived %02d:%02d\n%d kills — level %d" % [minutes, seconds, kills, level]
	visible = true
	restart_button.grab_focus()


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
