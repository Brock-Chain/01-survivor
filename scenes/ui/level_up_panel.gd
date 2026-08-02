class_name LevelUpPanel
extends CanvasLayer
## The pick-1-of-3 screen. Runs WHILE the tree is paused (process_mode
## WHEN_PAUSED) — the pause/UI split every roguelite needs.

signal upgrade_chosen(upgrade: UpgradeResource)

@onready var title: Label = %Title
@onready var options: HBoxContainer = %Options


func show_offers(offers: Array[UpgradeResource], level: int) -> void:
	title.text = "LEVEL %d — CHOOSE ONE" % level
	for child: Node in options.get_children():
		child.queue_free()
	var first: Button = null
	for upgrade: UpgradeResource in offers:
		var button := Button.new()
		button.text = "%s\n%s" % [upgrade.display_name, upgrade.description]
		button.custom_minimum_size = Vector2(150, 80)
		button.pressed.connect(_on_option_pressed.bind(upgrade))
		options.add_child(button)
		if first == null:
			first = button
	visible = true
	if first != null:
		first.grab_focus()  # keyboard/gamepad picks work too


func _on_option_pressed(upgrade: UpgradeResource) -> void:
	visible = false
	upgrade_chosen.emit(upgrade)
