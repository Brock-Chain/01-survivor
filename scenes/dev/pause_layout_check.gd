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

	print("[check] FAILURES=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
