class_name TrueEndingScreen
extends CanvasLayer
## Shown paused when NOGAXEH dies. THE run's real ending.
##
## This screen exists because of a hole nobody had noticed. `RunDirector.victory`
## is emitted at most once per run, on the FIRST boss event cleared — correct, and
## deliberately so, because continuing into endless must never be able to revoke a
## banked win. The consequence was that killing NOGAXEH produced **nothing**: no
## screen, no stinger, no acknowledgement of the hardest fight in the game,
## because the once-per-run signal had already fired at 5:00.
##
## Deliberately NOT a reskin of the victory screen. Beating the Prism is "you got
## through the tutorial fight, now try endless"; this is the end of the story the
## run was telling. Gold rather than cyan-green, a wider frame, the run's whole
## record rather than a two-line summary, and a different verb on the buttons.
##
## process_mode PROCESS_MODE_WHEN_PAUSED (2) on the scene root, like every other
## modal here: the tree is paused when this appears, and a PAUSABLE node gets no
## input at all — every key a pause-time UI advertises must be handled BY that UI.

signal continued

@onready var stats_label: Label = %StatsLabel
@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	restart_button.pressed.connect(_on_restart)


## FIVE LINES, hard. The first draft gave every unlock its own heading and blurb
## and measured **633 px tall against a 360 px viewport** — nearly double — in
## `scenes/dev/pause_layout_check.tscn`, which is precisely the trap that guard
## exists for and precisely the screen most likely to hit it: it is the only one
## whose height grows with how well the run went, so it is at its tallest in the
## exact run it was written for. Unlocks list their NAMES only; their blurbs were
## already announced on the HUD the moment they were earned.
func show_results(time_survived: float, kills: int, level: int,
		weapons: Array[StringName], unlocks: Array[StringName] = []) -> void:
	var minutes: int = int(time_survived) / 60
	var seconds: int = int(time_survived) % 60
	var lines: PackedStringArray = [
		"The mirror is broken. The arena is yours.",
		"%02d:%02d survived · %d kills · level %d" % [minutes, seconds, kills, level],
		_weapon_line(weapons),
	]
	if not unlocks.is_empty():
		var names: PackedStringArray = []
		for id: StringName in unlocks:
			names.append(MetaState.unlock_label(id))
		lines.append("UNLOCKED — %s" % " · ".join(names))
	lines.append("Endless keeps going. Nothing here can be taken back.")
	stats_label.text = "\n".join(lines)
	visible = true
	continue_button.grab_focus()


## Weapon ids to display names. A tiny map rather than a WeaponResource lookup:
## an end-of-run screen has no business loading gameplay data, and
## `MetaState.unlock_label` answers a different question (it names MILESTONES, so
## it would call the lance "PRISM LANCE" only by coincidence of id).
const WEAPON_NAMES: Dictionary = {
	&"orbital": "Orbitals",
	&"scattergun": "Scattergun",
	&"lance": "Prism Lance",
}


## The run's build, named. A player who finished on the Blaster alone earned a
## different thing from one who drafted all three, and the screen should say so.
func _weapon_line(weapons: Array[StringName]) -> String:
	var names: PackedStringArray = ["Blaster"]
	for id: StringName in weapons:
		names.append(String(WEAPON_NAMES.get(id, String(id).capitalize())))
	return "Drafted: %s" % " · ".join(names)


func _on_continue() -> void:
	Sfx.play(&"click")
	visible = false
	get_tree().paused = false
	continued.emit()


func _on_restart() -> void:
	Sfx.play(&"click")
	get_tree().paused = false
	get_tree().reload_current_scene()
