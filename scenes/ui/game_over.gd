class_name GameOverScreen
extends CanvasLayer
## Shown paused. Restart reloads the whole main scene — the cheapest
## correct way to reset a run.

@onready var stats_label: Label = %StatsLabel
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)


## Names for the thing that killed you. Kept beside the screen that shows them
## rather than on the enemy data, because these are PLAYER-FACING sentences, not
## content — the .tres files stay pure numbers.
const KILLER: Dictionary = {
	&"drifter": "A Drifter caught you.",
	&"dart": "A Dart ran you through.",
	&"bulwark": "A Bulwark crushed you.",
	&"lancer": "A Lancer's bolt found you.",
	&"splitter": "A Splitter got you.",
	&"ram": "A Ram ran you down.",
	&"shard": "A Shard cut you down.",
	&"prism": "The Prism finished it.",
	&"nogaxeh": "NOGAXEH took the arena back.",
}


## Review finding 16 and BRIEF defect #4: this screen used to report time, kills
## and level, and nothing about WHY the run ended. It also never mentioned the
## player's record — the near-miss ("22s short") is the strongest restart
## motivator in the game, and it was sitting unread in MetaState the whole time.
func show_results(time_survived: float, kills: int, level: int,
		killed_by: StringName = &"", source: StringName = &"",
		unlocks: Array[StringName] = [], shards_earned: int = 0) -> void:
	var minutes: int = int(time_survived) / 60
	var seconds: int = int(time_survived) % 60
	var lines: PackedStringArray = []

	# The blast is checked FIRST and by source, not by killer. NOGAXEH dies either
	# way, so the thing that killed you is already gone by the time this screen
	# appears — and "you were 5 seconds too slow" is the single most useful
	# sentence this screen can say, since it is the one death in the game the
	# player can do something specific about next run.
	if source == &"nogaxeh_blast":
		lines.append("NOGAXEH detonated. Five seconds, and you were inside them.")
	elif KILLER.has(killed_by):
		lines.append(String(KILLER[killed_by]))
	elif source == &"bolt":
		lines.append("A bolt found you.")
	elif source == &"contact":
		lines.append("Something ran you down.")
	lines.append("%02d:%02d · %d kills · level %d" % [minutes, seconds, kills, level])

	# The near-miss line. Only shown when there IS a record to miss, and only
	# when this run did not beat it — telling a player they were 0s short of
	# their own new best is nonsense.
	var best: float = Meta.state.best_time
	if best > 0.0 and time_survived < best:
		lines.append("Best %02d:%02d — %ds short." % [
				int(best) / 60, int(best) % 60, int(ceilf(best - time_survived))])
	elif best > 0.0 and time_survived >= best:
		lines.append("NEW BEST.")

	# What the run PAID. A death screen that only reports a failure gives the
	# player nothing to carry forward; shards are the thing every run earns, and
	# saying the number here is what makes the next one feel like it continues
	# this one rather than replacing it.
	if shards_earned > 0:
		lines.append("+%d ◆  ·  %d banked in the Lattice" % [shards_earned, Meta.state.shards])

	for id: StringName in unlocks:
		lines.append("")
		lines.append("UNLOCKED — %s" % MetaState.unlock_label(id))
		lines.append(MetaState.unlock_blurb(id))

	stats_label.text = "\n".join(lines)
	visible = true
	restart_button.grab_focus()


func _on_restart() -> void:
	Sfx.play(&"click")
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	Sfx.play(&"click")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
