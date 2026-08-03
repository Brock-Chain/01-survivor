class_name PausePanel
extends CanvasLayer
## Pause + build sheet. Runs WHILE the tree is paused (process_mode WHEN_PAUSED),
## the same split the level-up screen uses.
##
## Exists because nothing in the run told you what you had taken. By level 30 a
## player has made thirty choices and can see none of them, which makes those
## choices feel less consequential than they were. Showing the build is the
## cheapest way to make a long run read as authored rather than accumulated.
##
## Grouped by RARITY, best first: the Legendary you pulled is the story of the
## run, so it should not sit buried alphabetically between two Commons.
##
## The build grid lives in a ScrollContainer with a FIXED height. A CenterContainer
## centres a child that is taller than the screen by overflowing it at BOTH ends,
## so at 22 upgrades the Resume/Restart/Menu row left the bottom of the viewport
## entirely — and since the keys that should have saved you were dead too (see
## `_unhandled_input`), the pause screen was a trap. Bounding the scroll area is
## what keeps the buttons on screen at any upgrade count.

signal resumed

const COLS: int = 3
## Tallest the build grid may get before it starts scrolling.
##
## Budgeted against the 640x360 VIEWPORT, not the 1280x720 window — UI lays out in
## viewport space and the canvas_items stretch scales it up afterwards. This is
## the trap the whole fix exists for, so the number is MEASURED, not reasoned:
## `scenes/dev/pause_layout_check.tscn` instantiates the real panel at 0/1/3/6/12/
## 22/38 upgrades and fails if the footer leaves the screen.
##
## Measured overhead for everything that is not the grid is ~244 px (a first pass
## estimated 199 and was wrong by 45 — fonts render taller than their nominal
## size, and the BUILD/STATS tab row later added ~22 more). That leaves ~116;
## 104 holds a margin against font-metric drift.
##
## Raising this REQUIRES re-running the harness. 150 put the footer at 364 in a
## 360 px viewport, and 125 fit the footer but left the panel itself 3px taller
## than the screen — which is why the harness now checks the whole frame.
const MAX_GRID_HEIGHT: float = 104.0

@onready var stats_label: Label = %StatsLabel
@onready var scroll: ScrollContainer = %Scroll
@onready var pages: VBoxContainer = %Pages
@onready var grid: GridContainer = %Grid
@onready var stats_grid: GridContainer = %StatsGrid
@onready var build_tab: Button = %BuildTab
@onready var stats_tab: Button = %StatsTab
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var mute_button: Button = %MuteButton
@onready var track_button: Button = %TrackButton


func _ready() -> void:
	grid.columns = COLS
	resume_button.pressed.connect(resume)
	restart_button.pressed.connect(_on_restart)
	quit_button.pressed.connect(_on_quit)
	music_slider.value = Audio.music_volume
	sfx_slider.value = Audio.sfx_volume
	music_slider.value_changed.connect(func(v: float) -> void: Audio.set_music_volume(v))
	sfx_slider.value_changed.connect(func(v: float) -> void: Audio.set_sfx_volume(v))
	mute_button.pressed.connect(toggle_mute)
	track_button.pressed.connect(_cycle_track)
	_refresh_track()
	build_tab.pressed.connect(_show_page.bind(false))
	stats_tab.pressed.connect(_show_page.bind(true))
	_refresh_mute()


## Two pages inside the SAME bounded scroll area, rather than two columns.
## Columns would have widened the panel and narrowed the build grid; pages keep
## the whole screen inside the height the layout harness verifies.
func _show_page(stats_page: bool) -> void:
	Sfx.play(&"click", -12.0)
	build_tab.button_pressed = not stats_page
	stats_tab.button_pressed = stats_page
	grid.visible = not stats_page
	stats_grid.visible = stats_page
	_fit_grid()


## Main owns these keys while unpaused — but Main is PROCESS_MODE_PAUSABLE, and a
## paused tree runs no input callbacks on a pausable node, so every one of them
## was dead the moment this panel appeared. The Hint label promised
## "ESC / P resume · M mute · R restart" and none of the three worked; the Resume
## button was the only exit, which is why an overflowing build grid could strand
## the player. This panel is WHEN_PAUSED, so it owns the keys while it is up.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		resume()
	elif event.is_action_pressed(&"mute"):
		get_viewport().set_input_as_handled()
		toggle_mute()
	elif event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		_on_restart()


## Also reachable by the M key while unpaused, so muting never requires stopping.
func toggle_mute() -> void:
	Audio.set_muted(not Audio.muted)
	_refresh_mute()


func _refresh_mute() -> void:
	mute_button.text = "UNMUTE (M)" if Audio.muted else "MUTE (M)"


## AUTO, then each built track, and the change lands IMMEDIATELY rather than on
## the next run. Track choice was title-screen only, which put the one control
## for judging whether a 16-second loop wears out in the one place you cannot
## hear it under gameplay.
func _cycle_track() -> void:
	Sfx.play(&"click")
	var options: Array[int] = Music.available_tracks()
	if options.is_empty():
		return
	if Music.forced_track < 0:
		Music.forced_track = options[0]
	else:
		var at: int = options.find(Music.forced_track)
		Music.forced_track = -1 if at < 0 or at + 1 >= options.size() else options[at + 1]
	# AUTO resumes rotation on the NEXT run rather than jumping now — "auto" is a
	# policy, and switching tracks to demonstrate it would be the opposite of one.
	if Music.forced_track >= 0:
		Music.switch_gameplay_track(Music.forced_track)
	_refresh_track()


func _refresh_track() -> void:
	if Music.forced_track < 0:
		track_button.text = "TRACK: AUTO"
	else:
		track_button.text = "TRACK: %s" % Music.track_name(Music.forced_track)


## `stacks` is id -> times taken. `pool` is every upgrade, so an id resolves back
## to a display name and tier without the caller knowing about either.
func show_build(pool: Array[UpgradeResource], stacks: Dictionary,
		level: int, time_survived: float, kills: int, stats: Stats = null) -> void:
	_fill_stats(stats)
	var minutes: int = int(time_survived) / 60
	var seconds: int = int(time_survived) % 60
	stats_label.text = "LEVEL %d   -   %02d:%02d   -   %d KILLS" % [
			level, minutes, seconds, kills]

	for child: Node in grid.get_children():
		child.queue_free()

	var taken: Array[UpgradeResource] = []
	for u: UpgradeResource in pool:
		if int(stacks.get(u.id, 0)) > 0:
			taken.append(u)
	taken.sort_custom(func(a: UpgradeResource, b: UpgradeResource) -> bool:
		if a.rarity != b.rarity:
			return int(a.rarity) > int(b.rarity)
		return a.display_name < b.display_name)

	if taken.is_empty():
		var empty := Label.new()
		empty.text = "No upgrades yet."
		empty.add_theme_color_override(&"font_color", Color(0.55, 0.66, 0.82))
		grid.add_child(empty)
	else:
		for u: UpgradeResource in taken:
			grid.add_child(_make_chip(u, int(stacks.get(u.id, 0))))

	await _fit_grid()
	visible = true
	resume_button.grab_focus()


## The grid must never push the buttons off screen — that is exactly how this
## panel became a trap. A FIXED scroll height does not solve it either: it leaves
## a crater of empty space at one upgrade and is still a guess at forty. So
## measure what the grid actually asks for and cap it. Under the cap the panel
## hugs its content; over it, the grid scrolls and everything below stays put.
##
## The zero-then-measure dance is needed because `custom_minimum_size` is an input
## to the layout, so it has to be cleared before the grid can report an honest
## minimum. ScrollContainer also defaults to EXPAND_FILL on BOTH axes — the scene
## pins both flags to plain FILL, or it eats every spare pixel in the VBox.
func _fit_grid() -> void:
	scroll.custom_minimum_size.y = 0.0
	await get_tree().process_frame
	scroll.custom_minimum_size.y = minf(pages.get_combined_minimum_size().y, MAX_GRID_HEIGHT)


## The STATS page. Exists because the run's actual numbers were nowhere in the
## game: a player could take eight projectile upgrades and never learn that wide
## volleys hit softer, which made the cards' own wording unverifiable.
##
## The VOLLEY row is the important one. It is the multiplier from
## Stats.volley_damage_mult made visible, so the tax the cards describe in words
## is a number the player can watch move as they stack multishot.
func _fill_stats(stats: Stats) -> void:
	for child: Node in stats_grid.get_children():
		child.queue_free()
	if stats == null:
		return
	var shots: int = stats.volley_count(1)
	var volley: float = Stats.volley_damage_mult(1, shots)
	# Every row that the level drip touches shows the value the game actually
	# uses, not the card half of it. Two thirds of a player's level-ups now go
	# into the drip alone — a build screen that omitted it would be describing a
	# different character than the one on the arena floor.
	var rows: Array = [
		["DAMAGE", "+%d  (+%d drip)" % [stats.damage_bonus, stats.drip_damage_bonus]],
		["FIRE RATE", "%d%%" % roundi(100.0 / maxf(0.05, stats.cooldown_scale()))],
		["PROJECTILES", "%d" % shots],
		["PER SHOT", "%d%%" % roundi(volley * 100.0)],
		["PIERCE", "%d" % stats.pierce],
		["CRIT", "%d%%" % roundi(stats.crit_chance * 100.0)],
		["MOVE SPEED", "%d" % roundi(stats.speed())],
		["MAX HP", "%d" % stats.max_hp],
	]
	if stats.orbital_bonus_count > 0 or stats.orbital_speed_mult != 1.0:
		rows.append(["ORBITALS", "+%d" % stats.orbital_bonus_count])
		rows.append(["ORBIT SPEED", "%d%%" % roundi(stats.orbital_speed_mult * 100.0)])
	if stats.ricochet > 0:
		rows.append(["RICOCHET", "%d" % stats.ricochet])
	if stats.chain_targets > 0:
		rows.append(["CHAIN", "%d" % stats.chain_targets])
	if stats.lifesteal_chance > 0.0:
		rows.append(["LIFESTEAL", "%d%%" % roundi(stats.lifesteal_chance * 100.0)])
	if stats.execute_below > 0.0:
		rows.append(["EXECUTE", "<%d%%" % roundi(stats.execute_below * 100.0)])
	for row: Array in rows:
		stats_grid.add_child(_stat_label(String(row[0]), Color(0.5, 0.64, 0.82), false))
		stats_grid.add_child(_stat_label(String(row[1]), Color(0.72, 1.0, 0.95), true))


func _stat_label(text: String, colour: Color, value: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", colour)
	label.add_theme_font_size_override(&"font_size", 11)
	if value:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size = Vector2(52, 0)
	else:
		label.custom_minimum_size = Vector2(96, 0)
	return label


## One chip per upgrade, framed in its rarity colour, so a build reads as a
## spread of tiers at a glance instead of a list to be read word by word.
func _make_chip(upgrade: UpgradeResource, count: int) -> Control:
	var hue: Color = Rarity.color_of(upgrade.rarity)
	var glow: float = Rarity.glow_of(upgrade.rarity)

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.07, 0.14, 0.9)
	var width: int = 1 + int(round(glow * 1.5))
	box.border_width_left = width
	box.border_width_top = width
	box.border_width_right = width
	box.border_width_bottom = width
	box.border_color = hue.lightened(0.1 * glow)
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_right = 2
	box.corner_radius_bottom_left = 2
	if glow > 0.0:
		box.shadow_color = Color(hue.r, hue.g, hue.b, 0.22 * glow)
		box.shadow_size = int(round(1 + glow * 5))
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", box)
	panel.custom_minimum_size = Vector2(170, 0)

	var label := Label.new()
	# A stack count only earns its space once there IS a stack.
	label.text = upgrade.display_name if count <= 1 else "%s x%d" % [
			upgrade.display_name, count]
	label.add_theme_color_override(&"font_color", hue.lightened(0.35))
	label.add_theme_font_size_override(&"font_size", 12)
	label.clip_text = true
	panel.add_child(label)
	return panel


func resume() -> void:
	Sfx.play(&"click")
	visible = false
	get_tree().paused = false
	resumed.emit()


func _on_restart() -> void:
	Sfx.play(&"click")
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit() -> void:
	Sfx.play(&"click")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
