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
@onready var boss_panel: VBoxContainer = %BossPanel
@onready var boss_name: Label = %BossName
@onready var boss_bar: ProgressBar = %BossBar
@onready var banner: Label = %Banner
@onready var dash_label: Label = %DashLabel
@onready var dash_pip: ProgressBar = %DashPip

## Buff labels are POOLED, not rebuilt: this updates every frame, and churning
## Controls at 60Hz to show three words is the kind of thing that is invisible
## until it is not.
var _buff_labels: Array[Label] = []
## Guards the shield readout so it is not rebuilt every physics frame.
var _shielded: bool = false


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


## Boss progress. Review finding 3: the 5:00 event — the run's WIN CONDITION —
## arrived with no name, no bar, and no readout of any kind. Two Prisms at 900 HP
## each, and the only progress marker in the whole fight was the shard detach at
## 50%. A player could not tell whether they were winning.
##
## One bar for the whole EVENT, not one per boss: at 10:00 there are three bodies
## on screen and three bars would be noise. "How much of this fight is left" is
## the question being answered.
func set_boss(name_text: String, hp: int, max_hp: int) -> void:
	boss_panel.visible = true
	boss_name.text = name_text
	boss_bar.max_value = maxi(1, max_hp)
	boss_bar.value = hp


func hide_boss() -> void:
	boss_panel.visible = false
	_shielded = false


## The third layer of the shield indicator, after the membrane on the boss and
## the dull grey thud on blocked hits.
##
## A locked bar with an instruction, because a player watching a health bar
## refuse to move needs to be told WHY in the place they are already looking.
## Without this, "invulnerable boss" and "the game is broken" are the same
## experience, which is BRIEF defect #4.
func set_boss_shielded(shielded: bool, label: String = "") -> void:
	if shielded == _shielded:
		return
	_shielded = shielded
	if shielded:
		boss_name.text = "SHIELDED — DESTROY THE PRISMS"
		boss_name.add_theme_color_override(&"font_color", Color(0.78, 0.75, 1.0))
		boss_bar.modulate = Color(0.55, 0.5, 0.62)
	else:
		boss_name.text = label
		boss_name.add_theme_color_override(&"font_color", Color(1, 0.6, 0.87))
		boss_bar.modulate = Color.WHITE


## The NOGAXEH reveal. The banner spells HEXAGON and then flips — a mirror boss
## whose name is the word mirrored, so the reveal is typography rather than a
## line of dialogue nobody reads mid-fight.
func flip_boss_name(from_text: String, to_text: String) -> void:
	boss_name.text = from_text
	var tween: Tween = create_tween()
	tween.tween_interval(0.45)
	tween.tween_property(boss_name, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func() -> void: boss_name.text = to_text)
	tween.tween_property(boss_name, "modulate:a", 1.0, 0.18)


## Centre-screen announcement. Exists because `Meta.unlocked` had ZERO listeners
## project-wide (review finding 2): unlocks were earned, saved and applied in
## total silence. The dash in particular MUST be announced — a player who wins
## and continues would otherwise walk into a bullet-hell boss never knowing they
## had been handed the dodge.
func announce(text: String) -> void:
	banner.text = text
	banner.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.22)
	tween.tween_interval(2.1)
	tween.tween_property(banner, "modulate:a", 0.0, 0.5)


## -1 means "not unlocked", which hides the readout entirely rather than showing
## a permanently empty pip a first-time player cannot interpret.
func set_dash(fraction: float) -> void:
	var owned: bool = fraction >= 0.0
	dash_label.visible = owned
	dash_pip.visible = owned
	if owned:
		dash_pip.value = fraction * 100.0
