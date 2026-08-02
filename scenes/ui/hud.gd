class_name Hud
extends CanvasLayer
## Read-only view of the run. Main pushes values in (call down);
## the HUD never reaches into gameplay.

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var level_label: Label = %LevelLabel
@onready var time_label: Label = %TimeLabel
@onready var kills_label: Label = %KillsLabel
@onready var buffs_row: HBoxContainer = %BuffsRow

## Buff labels are POOLED, not rebuilt: this updates every frame, and churning
## Controls at 60Hz to show three words is the kind of thing that is invisible
## until it is not.
var _buff_labels: Array[Label] = []


func set_health(hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "%d/%d" % [hp, max_hp]


func set_xp(into_level: int, required: int, level: int) -> void:
	xp_bar.max_value = required
	xp_bar.value = into_level
	level_label.text = "LV %d" % level


## `entries` is [{name: String, left: float}], longest-lived first.
func set_buffs(entries: Array) -> void:
	while _buff_labels.size() < entries.size():
		var label := Label.new()
		label.add_theme_color_override(&"font_color", Color(0.62, 1.0, 0.95))
		buffs_row.add_child(label)
		_buff_labels.append(label)
	for i: int in _buff_labels.size():
		var label: Label = _buff_labels[i]
		if i < entries.size():
			label.text = "%s %.0fs" % [entries[i]["name"], ceilf(float(entries[i]["left"]))]
			label.visible = true
		else:
			label.visible = false


func set_run(time_survived: float, kills: int) -> void:
	var minutes: int = int(time_survived) / 60
	var seconds: int = int(time_survived) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]
	kills_label.text = "%d kills" % kills
