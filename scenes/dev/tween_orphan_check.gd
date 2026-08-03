extends Node
## Regression check for the 2026-08-03 release freeze: the Legendary card pulse.
##
## `LevelUpPanel._apply_rarity` created its looping pulse with a bare
## `create_tween()` — bound to the PANEL, which lives all run — while animating
## a BUTTON that the next `show_offers` queue_free's. An orphaned looping tween
## completes its whole loop in zero time, and Godot's infinite-loop detector is
## `#ifdef DEBUG_ENABLED`: debug prints "Infinite loop detected" and kills the
## tween; the shipped release locks the main thread inside Tween::step()
## forever. Four freezes on two machines, always ~one card screen after the
## run's first LEGENDARY offer, always with the level-up cue as the last thing
## heard — the cue plays right before the rebuild that orphans the pulse.
##
## The choreography below matters and cost the first version of this harness
## its red: the panel is WHEN_PAUSED, so its tweens only step while the tree is
## paused. Main pauses before show_offers and unpauses on pick; without that
## dance the orphan never steps and the check passes vacuously. (A raw-
## mechanism section — free the target of any bare looping tween — confirmed
## the engine half independently before this file settled on the game path.)
##
## RED = the detector's line in a debug run. GREEN = the two [check] lines and
## silence. verify.ps1 fails on the detector string.

const PANEL_SCENE: PackedScene = preload("res://scenes/ui/level_up_panel.tscn")


func _make_offer() -> Array[UpgradeResource]:
	var legendary := UpgradeResource.new()
	legendary.id = &"check_legendary"
	legendary.display_name = "Check Legendary"
	legendary.description = "tween orphan repro"
	legendary.rarity = Rarity.Tier.LEGENDARY
	var offers: Array[UpgradeResource] = [legendary]
	return offers


func _ready() -> void:
	# The harness itself must keep running while the tree is paused, or the
	# awaits below deadlock the moment the real choreography starts.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel: CanvasLayer = PANEL_SCENE.instantiate()
	add_child(panel)
	var offers: Array[UpgradeResource] = _make_offer()

	# Card screen 1, exactly as Main does it: pause, then show. The panel is
	# WHEN_PAUSED, so this is what lets the Legendary pulse actually run.
	get_tree().paused = true
	panel.show_offers(offers, 1)
	for i: int in 5:
		await get_tree().process_frame
	print("[check] screen 1 up, pulse running")

	# The pick: Main unpauses; the panel and every tween bound to it freeze.
	# The old cards are NOT freed here — that is the next screen's first act.
	get_tree().paused = false
	panel.visible = false
	for i: int in 3:
		await get_tree().process_frame

	# Card screen 2: pause + show. show_offers queue_free's screen 1's cards;
	# the freed button leaves ObjectDB at end of frame; the panel is processing
	# again, so the old pulse steps on a corpse right here.
	get_tree().paused = true
	panel.show_offers(offers, 2)
	for i: int in 8:
		await get_tree().process_frame
	print("[check] screen 2 up, orphan had %d frames to step" % 8)
	get_tree().paused = false
	get_tree().quit(0)
