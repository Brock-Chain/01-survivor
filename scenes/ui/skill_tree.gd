class_name SkillTreeScreen
extends Control
## The meta progression screen, reached from the title.
##
## A LIST IN A SCROLLER, NOT A NODE GRAPH. The viewport is 640x360 and the
## project's own hardest-won rule is that UI gets MEASURED against that, never
## against the 1280x720 window — two reasoned layout fixes were wrong here before
## a harness produced a number. A literal branching tree with connector lines
## needs roughly 3x this height before a single node is legible, so it would have
## shipped either unreadable or scrolled in two directions at once. Rows grouped
## by cost tier give the same read — "here is the ladder, here is how far up it I
## am" — in a shape that fits.
##
## Two sections, and the second is the point: OWNED shows what the shards bought,
## LOCKED shows what they could buy and what it costs. A catalogue of things the
## player cannot have yet is the reason to play another run.

const NODES: Array[SkillNode] = SkillList.ALL
## Card colour, so a CARD node reads as a card and a STAT node reads as a stat
## before either is read as words.
const CARD_HUE: Color = Color(0.72, 0.45, 1.0)
const STAT_HUE: Color = Color(0.45, 0.85, 1.0)
const OWNED_HUE: Color = Color(0.45, 1.0, 0.62)

@onready var shard_label: Label = %ShardLabel
@onready var rows: VBoxContainer = %Rows
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	_rebuild()
	back_button.grab_focus()


## The whole list is rebuilt after every purchase rather than patched. Nine nodes
## is nothing to rebuild, and a screen that re-reads MetaState from scratch can
## never drift out of step with the save the way an incrementally-updated one can.
func _rebuild() -> void:
	shard_label.text = "%d SHARDS   ·   %d per minute survived, %d per boss event" % [
		Meta.state.shards, MetaState.SHARDS_PER_MINUTE, MetaState.SHARDS_PER_BOSS_EVENT]
	for child: Node in rows.get_children():
		child.queue_free()
	var sorted: Array[SkillNode] = NODES.duplicate()
	sorted.sort_custom(func(a: SkillNode, b: SkillNode) -> bool:
		return a.cost < b.cost if a.tier == b.tier else a.tier < b.tier)
	for node: SkillNode in sorted:
		rows.add_child(_build_row(node))


func _build_row(node: SkillNode) -> Control:
	var owned: bool = Meta.state.has_purchase(node.id)
	var affordable: bool = not owned and Meta.state.shards >= node.cost
	var hue: Color = OWNED_HUE if owned else (
			CARD_HUE if node.kind == SkillNode.Kind.CARD else STAT_HUE)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 0)
	row.add_child(text)

	var title := Label.new()
	title.text = node.display_name
	title.add_theme_font_size_override(&"font_size", 12)
	title.add_theme_color_override(&"font_color", hue)
	text.add_child(title)

	var desc := Label.new()
	# The kind is stated in words as well as in colour. Colour alone fails for
	# roughly one player in twelve, and this screen has no other cue.
	desc.text = "%s — %s" % [
		"CARD" if node.kind == SkillNode.Kind.CARD else "PERMANENT", node.description]
	desc.add_theme_font_size_override(&"font_size", 9)
	desc.add_theme_color_override(&"font_color", Color(0.70, 0.80, 0.92))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)

	var button := Button.new()
	button.custom_minimum_size = Vector2(96, 26)
	if owned:
		button.text = "OWNED"
		button.disabled = true
	else:
		button.text = "%d ◆" % node.cost
		button.disabled = not affordable
		button.pressed.connect(_on_buy.bind(node))
	row.add_child(button)
	return row


func _on_buy(node: SkillNode) -> void:
	if not Meta.state.buy(node.id, node.cost):
		return  # already owned, or the shards went somewhere else first
	Meta.save_state()
	Sfx.play(&"levelup", -6.0)
	_rebuild()


func _on_back() -> void:
	Sfx.play(&"click")
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")


## The screen owns its own dismissal. A CanvasLayer/Control that advertises a key
## must handle it here — `_unhandled_input` elsewhere is gated by process_mode and
## simply never fires for a UI that is up while something else owns the frame.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
