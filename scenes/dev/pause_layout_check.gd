extends Node
## Regression guard for the pause panel's height. Lives in `scenes/dev/` with the
## juice lab, so it is excluded from exports.
##
##   <console.exe> --headless --path . res://scenes/dev/pause_layout_check.tscn
##   exit 0 = every upgrade count keeps its footer on screen
##
## Runs as a SCENE, not a `-s` SceneTree script: the panel's `_ready()` touches
## the Audio autoload, and autoloads are not registered under `-s` (a `-s` version
## of this harness hung with no output at all).
##
## Why this exists rather than a comment saying "should fit": the panel shipped
## as a TRAP — at 22 upgrades the Resume button sat below the viewport and every
## key that could have dismissed it was dead. The first fix guessed a 300 px cap
## and made it worse; the second guessed 150 and still overflowed by 4 px. The
## overhead around the grid is ~222 px and no amount of reading the .tscn
## produced that number. `PausePanel.MAX_GRID_HEIGHT` is only trustworthy while
## this runs green — re-run it after touching the panel's layout or fonts.
##
## Unit tests cannot cover this: GUT here is pure-logic only, by convention.

const COUNTS: Array[int] = [0, 1, 3, 6, 12, 22, 38]


func _ready() -> void:
	var pool: Array[UpgradeResource] = []
	var dir: DirAccess = DirAccess.open("res://resources/upgrades")
	for f: String in dir.get_files():
		if f.ends_with(".tres"):
			pool.append(load("res://resources/upgrades/%s" % f) as UpgradeResource)

	var panel: PausePanel = load("res://scenes/ui/pause_panel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame

	var vw: float = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh: float = float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	print("[check] pool=%d  viewport=%.0fx%.0f  cap=%.0f"
			% [pool.size(), vw, vh, PausePanel.MAX_GRID_HEIGHT])

	var box: Control = panel.get_node("Center/Panel")
	var resume: Button = panel.get_node("Center/Panel/Margin/VBox/Buttons/ResumeButton")
	var hint: Label = panel.get_node("Center/Panel/Margin/VBox/Hint")

	var failures: int = 0
	for n: int in COUNTS:
		var stacks: Dictionary = {}
		for i: int in mini(n, pool.size()):
			stacks[pool[i].id] = 1
		panel.show_build(pool, stacks, 30, 251.0, 713)
		for _i: int in 4:
			await get_tree().process_frame

		var top: float = box.global_position.y
		var foot: float = hint.global_position.y + hint.size.y
		var rbot: float = resume.global_position.y + resume.size.y
		# The WHOLE PANEL must fit, not just its footer. An earlier version only
		# checked the hint label and happily passed a panel 3px taller than the
		# viewport — the buttons were reachable but the frame was clipped, which
		# is exactly the "reads as broken" defect this guards against.
		var ok: bool = top >= 0.0 and foot <= vh and box.size.x <= vw \
				and top + box.size.y <= vh
		if not ok:
			failures += 1
		print("[check] n=%2d panel=%3.0fx%3.0f top=%4.0f resume_bot=%4.0f foot=%4.0f %s"
				% [n, box.size.x, box.size.y, top, rbot, foot,
				"OK" if ok else "*** OFF-SCREEN ***"])

	failures += await _check_level_up(pool, vw, vh)
	failures += await _check_true_ending(vw, vh)
	print("[check] FAILURES=%d" % failures)
	# Hold the last frame long enough for the screenshot autoload to fire when one
	# was asked for. Gated on the flag so the gate itself stays instant.
	if _capturing():
		for _i: int in 40:
			await get_tree().process_frame
	get_tree().quit(1 if failures > 0 else 0)


func _capturing() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			return true
	return false


## The LEVEL-UP panel, measured against its worst case: the three longest
## descriptions in the pool on one screen. This has already shipped broken once —
## at level 57 a long description grew the cards past their minimum and the third
## card ran off the right edge — and M7.3 both widened the cards (172 -> 184, for
## a screen that is now worth three times as much) and added longer text to them.
func _check_level_up(pool: Array[UpgradeResource], vw: float, vh: float) -> int:
	var longest: Array[UpgradeResource] = pool.duplicate()
	longest.sort_custom(func(a: UpgradeResource, b: UpgradeResource) -> bool:
		return a.description.length() > b.description.length())
	var offers: Array[UpgradeResource] = []
	for i: int in mini(3, longest.size()):
		offers.append(longest[i])

	var panel: LevelUpPanel = load("res://scenes/ui/level_up_panel.tscn").instantiate()
	add_child(panel)
	panel.show_offers(offers, 57)
	for _i: int in 6:
		await get_tree().process_frame

	var box: Control = panel.get_node("Center/Panel")
	var top: float = box.global_position.y
	var left: float = box.global_position.x
	var ok: bool = top >= 0.0 and left >= 0.0 and left + box.size.x <= vw \
			and top + box.size.y <= vh
	print("[check] level_up panel=%3.0fx%3.0f at %3.0f,%3.0f %s"
			% [box.size.x, box.size.y, left, top, "OK" if ok else "*** OFF-SCREEN ***"])
	panel.queue_free()
	await get_tree().process_frame
	return 0 if ok else 1


## The TRUE ENDING screen, measured the same way and for the same reason. It is
## the one screen in the game a player reaches once, at the end of a fifteen
## minute run, and it grows with the run: the weapon line and one block of text
## per unlock earned. Worst case is every weapon drafted AND every milestone
## firing on the same kill, which is exactly the run this screen exists for.
func _check_true_ending(vw: float, vh: float) -> int:
	# Clear the pause panel first. It is measured by then, and this makes the
	# harness double as a capture rig: run it windowed with --screenshot and the
	# frame shows the true ending alone, at its worst-case size.
	for child: Node in get_children():
		var ui: CanvasLayer = child as CanvasLayer
		if ui != null:
			ui.visible = false
	var screen: TrueEndingScreen = load("res://scenes/ui/true_ending.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame

	var weapons: Array[StringName] = [&"orbital", &"scattergun", &"lance"]
	var unlocks: Array[StringName] = [MetaState.UNLOCK_ORBITAL, MetaState.UNLOCK_DASH,
			MetaState.UNLOCK_ELITE_HUNTER, MetaState.UNLOCK_ENDLESS_PROVEN]
	screen.show_results(931.0, 4212, 88, weapons, unlocks)
	for _i: int in 4:
		await get_tree().process_frame

	var box: Control = screen.get_node("Center/Panel")
	var top: float = box.global_position.y
	var ok: bool = top >= 0.0 and box.size.x <= vw and top + box.size.y <= vh
	print("[check] true_ending panel=%3.0fx%3.0f top=%4.0f %s"
			% [box.size.x, box.size.y, top, "OK" if ok else "*** OFF-SCREEN ***"])
	# Left on screen deliberately: the harness quits straight after, and freeing it
	# here is what made the first capture attempt come back as an empty grey frame.
	return 0 if ok else 1
