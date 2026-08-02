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
const CARD: Vector2 = Vector2(166, 104)
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
		button.text = "%s\n%s\n\n%s" % [upgrade.display_name, upgrade.description,
				Rarity.name_of(upgrade.rarity).to_upper()]
		button.custom_minimum_size = CARD
		button.size_flags_horizontal = Control.SIZE_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
		_apply_rarity(button, upgrade.rarity)
		button.pressed.connect(_on_option_pressed.bind(upgrade))
		options.add_child(button)
		if first == null:
			first = button
	visible = true
	if first != null:
		first.grab_focus()  # keyboard/gamepad picks work too


## Rarity reads as a neon-tech LED frame: the conventional hue vocabulary
## (grey / green / blue / purple / gold) rendered in this game's palette rather
## than fighting it. The ARENA colour law is untouched — that law governs
## entities, where hue must answer "can this hurt me" in a glance. A paused menu
## is a different context, and a convention this strong is cheaper to adopt than
## to retrain. Border WIDTH and glow scale with tier too, so the ladder still
## reads in a screenshot where animation cannot help.
func _apply_rarity(button: Button, tier: Rarity.Tier) -> void:
	var hue: Color = Rarity.color_of(tier)
	var glow: float = Rarity.glow_of(tier)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		var lift: float = 0.0
		if state == "hover" or state == "focus":
			lift = 0.10
		elif state == "pressed":
			lift = 0.18
		box.bg_color = Color(0.05 + lift, 0.07 + lift, 0.15 + lift, 0.94)
		var width: int = 1 + int(round(glow * 2.0))
		box.border_width_left = width
		box.border_width_top = width
		box.border_width_right = width
		box.border_width_bottom = width
		# Higher tiers are brighter AND more saturated, not just a different hue.
		box.border_color = hue.lightened(0.10 * glow).lerp(Color.WHITE, 0.08 * glow)
		box.corner_radius_top_left = 2
		box.corner_radius_top_right = 2
		box.corner_radius_bottom_right = 2
		box.corner_radius_bottom_left = 2
		if glow > 0.0:
			# The LED bloom. shadow_size doubles as the glow channel, so a
			# Legendary is unmistakable even in a still frame.
			box.shadow_color = Color(hue.r, hue.g, hue.b, 0.30 * glow)
			box.shadow_size = int(round(2 + glow * 7))
		box.content_margin_left = 10.0
		box.content_margin_right = 10.0
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override(&"font_color", hue.lightened(0.35))
	button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	button.add_theme_color_override(&"font_focus_color", Color.WHITE)
	if tier == Rarity.Tier.LEGENDARY:
		# Only the top tier animates. If everything pulsed, nothing would.
		var pulse: Tween = create_tween().set_loops()
		pulse.tween_property(button, "modulate", Color(1.15, 1.12, 1.0), 0.55)
		pulse.tween_property(button, "modulate", Color.WHITE, 0.55)


func _on_option_pressed(upgrade: UpgradeResource) -> void:
	Sfx.play(&"click")
	visible = false
	upgrade_chosen.emit(upgrade)
