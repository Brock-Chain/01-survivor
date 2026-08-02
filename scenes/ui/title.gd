extends Control
## Click-to-start title. Exists for game feel AND because web builds
## cannot play audio until the first user gesture — the constraint IS
## the design.


func _ready() -> void:
	%StartButton.pressed.connect(_on_start)
	%StartButton.grab_focus()


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
