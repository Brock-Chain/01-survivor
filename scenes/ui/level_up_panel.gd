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
const CARD: Vector2 = Vector2(172, 118)
const GAP: int = 10
## 3 * 172 + 2 * 10 = 536, inside 640 with room for the panel's own margins.
const MAX_CARDS: int = 3
## Seconds between each card arriving. Three at once is a state change; three in
## sequence is a reveal, and the tree is paused anyway so it costs nothing real.
const DEAL_STAGGER: float = 0.07

## Nothing can be picked for this long after the panel opens.
##
## Playtest 2026-08-02: SPACE is both DASH and `ui_accept`, and the panel grabbed
## focus the instant it appeared — so pressing dash as a level landed instantly
## picked card one, before the player could read a single word. A is the same
## button on a controller, so it is not a keyboard-only problem.
##
## Two guards, because either alone leaks. Focus is WITHHELD, so a key already
## down cannot fire `ui_accept` at all; and the handler refuses early presses, so
## a fast mouse click cannot beat the deal-in animation either. Slightly longer
## than the deal-in (3 cards x 0.07 stagger + 0.26 settle) so the last card has
## finished arriving before anything can be chosen.
const PICK_LOCKOUT: float = 0.4

var _opened_ms: int = 0

## The panel used to snap in on the frame the level landed. At a level every few
## seconds that reads as a jolt interrupting the run rather than a moment the run
## earned. Short enough that a player picking fast never waits on it.
const APPEAR_TIME: float = 0.16
## Authored on the Dim ColorRect; held here because the fade zeroes it and a
## second level-up must not read the zero back as the target.
const DIM_ALPHA: float = 0.62

@onready var title: Label = %Title
@onready var options: HBoxContainer = %Options
@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Center/Panel


func show_offers(offers: Array[UpgradeResource], level: int) -> void:
	title.text = "LEVEL %d — CHOOSE ONE" % level
	options.add_theme_constant_override(&"separation", GAP)
	for child: Node in options.get_children():
		child.queue_free()
	var first: Button = null
	for i: int in offers.size():
		var upgrade: UpgradeResource = offers[i]
		var button: Button = _build_card(upgrade)
		button.pressed.connect(_on_option_pressed.bind(upgrade))
		options.add_child(button)
		_deal_in(button, i)
		if first == null:
			first = button
	visible = true
	_opened_ms = Time.get_ticks_msec()
	_play_appear()
	if first != null:
		_focus_when_readable(first)


## Focus arrives late ON PURPOSE — see PICK_LOCKOUT. Real time, not scaled time,
## so the window is the same 0.4s at x3 speed as at x1.
func _focus_when_readable(button: Button) -> void:
	await get_tree().create_timer(PICK_LOCKOUT, true, false, true).timeout
	if visible and is_instance_valid(button):
		button.grab_focus()  # keyboard and gamepad picks work from here on


## Fade the dim in and let the card row settle up into place, rather than both
## arriving on one frame. Deliberately NOT awaited by the caller: the panel is
## already visible and interactive, so a fast player can pick through the motion
## instead of being gated behind it.
##
## The tween runs while the tree is paused because it is bound to this node, and
## this node is WHEN_PAUSED — the same split that lets the buttons work at all.
func _play_appear() -> void:
	dim.color.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.97, 0.97)
	# One frame so the container has actually sized the panel; pivoting off a
	# stale size would scale it from the wrong point. Invisible either way at a = 0.
	await get_tree().process_frame
	if not visible:
		return  # picked (or the run ended) inside that frame
	panel.pivot_offset = panel.size * 0.5
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(dim, "color:a", DIM_ALPHA, APPEAR_TIME)
	tween.tween_property(panel, "modulate:a", 1.0, APPEAR_TIME)
	tween.tween_property(panel, "scale", Vector2.ONE, APPEAR_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A card is COMPOSED, not a Button with newlines in its text.
##
## It used to be `"%s\n%s\n\n%s"` — name, description and rarity crammed into one
## label at one size, which is why the screen had no hierarchy and no pop. Now
## each part is its own Label with its own weight: the name reads first, the
## effect second, and the tier sits in a coloured badge along the bottom edge
## where it functions as a spine you can scan three of at a glance.
##
## Children are mouse-transparent so the Button underneath still owns every
## click, hover and focus — the card looks composed and behaves like one control.
func _build_card(upgrade: UpgradeResource) -> Button:
	var hue: Color = Rarity.color_of(upgrade.rarity)
	var button := Button.new()
	button.custom_minimum_size = CARD
	button.size_flags_horizontal = Control.SIZE_FILL
	_apply_rarity(button, upgrade.rarity)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10.0
	box.offset_top = 9.0
	box.offset_right = -10.0
	box.offset_bottom = -9.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 5)
	button.add_child(box)

	var name_label := Label.new()
	name_label.text = upgrade.display_name
	name_label.add_theme_font_size_override(&"font_size", 14)
	name_label.add_theme_color_override(&"font_color", hue.lightened(0.55))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var desc := Label.new()
	desc.text = upgrade.description
	desc.add_theme_font_size_override(&"font_size", 10)
	desc.add_theme_color_override(&"font_color", Color(0.74, 0.84, 0.96))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(desc)

	# The tier badge. A filled bar rather than a word, so the ladder survives
	# being glanced at rather than read — and so a screen of Common/Common/Epic
	# reads as uneven before the player has processed any text.
	var badge := Label.new()
	badge.text = Rarity.name_of(upgrade.rarity).to_upper()
	badge.add_theme_font_size_override(&"font_size", 9)
	badge.add_theme_color_override(&"font_color", Color(0.04, 0.05, 0.1))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = hue.lightened(0.12)
	badge_box.content_margin_top = 1.0
	badge_box.content_margin_bottom = 1.0
	badge_box.corner_radius_top_left = 2
	badge_box.corner_radius_top_right = 2
	badge_box.corner_radius_bottom_right = 2
	badge_box.corner_radius_bottom_left = 2
	badge.add_theme_stylebox_override(&"normal", badge_box)
	box.add_child(badge)
	return button


## Deal the cards in one at a time. Three cards appearing on the same frame is
## an event that already happened; three arriving 70ms apart is an event you
## WATCH, and it costs a fifth of a second at the moment the game is paused
## anyway. Higher tiers land harder — a Legendary should not slide in politely.
func _deal_in(card: Control, index: int) -> void:
	card.modulate.a = 0.0
	card.pivot_offset = CARD * 0.5
	card.scale = Vector2(0.86, 0.86)
	var tween: Tween = create_tween().set_parallel(true)
	var delay: float = float(index) * DEAL_STAGGER
	tween.tween_property(card, "modulate:a", 1.0, 0.14).set_delay(delay)
	tween.tween_property(card, "scale", Vector2.ONE, 0.26).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
		# A thicker bottom edge under the tier badge: the card gets a visible
		# base, and the ladder reads even in a black-and-white screenshot.
		box.border_width_bottom = width + 1 + int(round(glow * 2.0))
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
	# The second half of the lockout. Focus being withheld stops a held key, this
	# stops a click that lands before the cards have finished dealing in.
	if Time.get_ticks_msec() - _opened_ms < int(PICK_LOCKOUT * 1000.0):
		return
	Sfx.play(&"click")
	visible = false
	upgrade_chosen.emit(upgrade)
