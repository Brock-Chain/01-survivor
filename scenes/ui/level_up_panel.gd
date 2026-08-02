class_name LevelUpPanel
extends CanvasLayer
## The pick-1-of-3 screen. Runs WHILE the tree is paused (process_mode
## WHEN_PAUSED) — the pause/UI split every roguelite needs.

signal upgrade_chosen(upgrade: UpgradeResource)

## Cards are sized to FIT, not to their text. `custom_minimum_size` is a floor,
## not a ceiling: a long description grows the Button past it, and three grown
## cards overflowed the 640px viewport (found in playtest at level 57 — the
## third card ran off the right edge). Three defences, because any one of them
## alone still lets an unusually long word through: wrap the text, clip what
## still will not fit, and hold the row to a width that provably fits.
const CARD: Vector2 = Vector2(166, 86)
const GAP: int = 10
## 3 * 166 + 2 * 10 = 518, inside 640 with room for the panel's own margins.
const MAX_CARDS: int = 3

@onready var title: Label = %Title
@onready var options: HBoxContainer = %Options


func show_offers(offers: Array[UpgradeResource], level: int) -> void:
	title.text = "LEVEL %d — CHOOSE ONE" % level
	options.add_theme_constant_override(&"separation", GAP)
	for child: Node in options.get_children():
		child.queue_free()
	var first: Button = null
	for upgrade: UpgradeResource in offers:
		var button := Button.new()
		button.text = "%s\n%s" % [upgrade.display_name, upgrade.description]
		button.custom_minimum_size = CARD
		button.size_flags_horizontal = Control.SIZE_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
		button.pressed.connect(_on_option_pressed.bind(upgrade))
		options.add_child(button)
		if first == null:
			first = button
	visible = true
	if first != null:
		first.grab_focus()  # keyboard/gamepad picks work too


func _on_option_pressed(upgrade: UpgradeResource) -> void:
	Sfx.play(&"click")
	visible = false
	upgrade_chosen.emit(upgrade)
