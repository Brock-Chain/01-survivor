extends Node2D
## Entry point. For now: proves the project boots, in editor and headless.


func _ready() -> void:
	print("01-survivor boot OK — Godot %s" % Engine.get_version_info()["string"])
