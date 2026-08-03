extends Node
## Autoload `Music`: adaptive layered soundtrack.
##
## The four gameplay stems are ALL playing, ALL the time, from the same instant —
## intensity only changes their VOLUME. That is the whole trick, and it is why
## layers can come and go mid-bar without a seam: they were never out of sync,
## because they were never restarted. Each stem is exactly 705,600 samples
## (16.00s), rendered from the same Strudel tempo and key.
##
## Fading rather than starting/stopping also means a layer entering is a
## musical event, not a technical one — the arp does not "begin", it *arrives*.
##
## Source lives in `audio_src/*.strudel`; `tools/build_music.py` renders it.
## Survives scene reloads (autoloads persist), so a restart never restarts the
## music — you keep the groove you had.

## One entry per TRACK; within a track, stem index == the intensity tier that
## switches it on (the Run Director publishes 0..3, tier 3 being a boss).
## Tracks are interchangeable: same tempo, same length, same four-layer shape,
## so rotation costs nothing structurally.
const TRACK_NAMES: Array[String] = ["Neon", "Darksynth", "Outrun", "Lightcycle"]
const TRACKS: Array = [
	["gameplay_0_bass", "gameplay_1_drums", "gameplay_2_arp", "gameplay_3_lead"],
	["track2_0_bass", "track2_1_drums", "track2_2_arp", "track2_3_lead"],
	["track3_0_bass", "track3_1_drums", "track3_2_arp", "track3_3_lead"],
	# LIGHTCYCLE — the neo-racing track. A Phrygian, so it shares the tonic with
	# Neon (Aeolian) and Outrun (Dorian) and stays interchangeable, but the flat
	# 2nd is an interval neither of them can make. Built as an engine rather than
	# a song: three chord changes in sixteen seconds where Outrun has eight.
	["track4_0_bass", "track4_1_drums", "track4_2_arp", "track4_3_lead"],
]
const LAYERS: int = 4

## -1 rotates through the tracks, one per run. 0+ pins one, for testing.
var forced_track: int = -1
var current_track: int = 0

var _rotation: int = -1
const TITLE_TRACK: String = "res://assets/audio/music/title.ogg"
const VICTORY_TRACK: String = "res://assets/audio/music/victory.ogg"

## Per-stem level when audible. The mix was built to peak at 0.96 with all four
## summed, so this trims a little headroom back rather than riding the limiter.
const STEM_DB: float = -3.0
const SILENT_DB: float = -60.0
const FADE_IN: float = 1.1
## Fading out slower than in: a layer vanishing abruptly reads as a bug, while a
## layer arriving quickly reads as intent.
const FADE_OUT: float = 2.2

## One bar at cps 0.5. Used to land the victory stinger ON the beat instead of
## wherever the killing blow happened to fall.
const CYCLE_SECONDS: float = 2.0
## Fast enough to clear the way for the stinger, slow enough not to click.
const VICTORY_DUCK: float = 0.45

var intensity: int = -1

var _stems: Array[AudioStreamPlayer] = []
var _title: AudioStreamPlayer
var _victory: AudioStreamPlayer
var _fades: Array[Tween] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Players are created ONCE and have their stream swapped per track. Creating
	# them per run would restart audio nodes mid-session for no benefit.
	for i: int in LAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = SILENT_DB
		add_child(player)
		_stems.append(player)
		_fades.append(null)
	_title = _make_player(TITLE_TRACK, true)
	_victory = _make_player(VICTORY_TRACK, false)


## Which tracks actually have all four stems built. A track whose .ogg files are
## missing is skipped rather than played as silence.
func available_tracks() -> Array[int]:
	var out: Array[int] = []
	for i: int in TRACKS.size():
		var ok: bool = true
		for stem: String in TRACKS[i]:
			if not ResourceLoader.exists(_stem_path(stem)):
				ok = false
				break
		if ok:
			out.append(i)
	return out


func track_name(index: int) -> String:
	return TRACK_NAMES[index] if index >= 0 and index < TRACK_NAMES.size() else "?"


func _stem_path(stem: String) -> String:
	return "res://assets/audio/music/%s.ogg" % stem


func _make_player(path: String, looping: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Music"
	var stream: AudioStream = load(path)
	# OGG carries no loop flag from the encoder; set it here or every track
	# plays exactly once and the game goes silent 16 seconds in.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = looping
	player.stream = stream
	add_child(player)
	return player


## Title screen: the calm version of the same progression.
func play_title() -> void:
	_stop_gameplay()
	if not _title.playing:
		_title.volume_db = STEM_DB
		_title.play()


## Start the run. Every stem starts together; only tier 0 is audible.
func play_gameplay() -> void:
	if _title.playing:
		_title.stop()
	if _stems[0].playing:
		_rotate_running()
		return
	_start_track(_choose_track(), 0)


## Review finding 9: rotation was DEAD on the restart path — the exact path the
## prime directive exercises five times in a row.
##
## `play_gameplay` used to early-return whenever stems were playing, and rotation
## lives past that guard inside `_choose_track`. `_stop_gameplay` is only ever
## called by `play_title`, so every restart — game over, victory, pause panel,
## the R key — kept the same 16-second loop forever. The anti-fatigue mechanism
## was unreachable from the one place fatigue actually accumulates.
##
## A restart is a NEW RUN and gets the next track. The original guard existed so
## a scene reload would not jar, which is still respected: the intensity tier is
## carried across rather than snapping back to bass-only.
func _rotate_running() -> void:
	if available_tracks().size() <= 1:
		return  # nothing to rotate to — keeping the groove is the better failure
	var previous: int = maxi(0, intensity)
	_stop_gameplay()
	_start_track(_choose_track(), previous)


## Switch tracks WITHOUT restarting the run, for the pause panel's track button.
##
## Carries the current intensity tier across rather than snapping back to
## bass-only: the player is paused mid-fight, and dropping to the opening layer
## on resume would announce the switch far louder than the switch itself. Does
## nothing if no gameplay music is running, so pressing it on a dead run cannot
## start a track over a game-over screen.
func switch_gameplay_track(index: int) -> void:
	if not _stems[0].playing:
		return
	var tier: int = maxi(0, intensity)
	_stop_gameplay()
	_start_track(index, tier)


func _start_track(index: int, tier: int) -> void:
	_load_track(index)
	for player: AudioStreamPlayer in _stems:
		player.volume_db = SILENT_DB
		player.play()
	intensity = -1
	set_intensity(tier)


## Pinned track if one is forced, else the next in rotation. Rotation advances
## per RUN, so consecutive runs are audibly different — which is most of what
## stops a 16-second loop wearing out.
func _choose_track() -> int:
	var options: Array[int] = available_tracks()
	if options.is_empty():
		return 0
	if forced_track >= 0 and options.has(forced_track):
		return forced_track
	_rotation = (_rotation + 1) % options.size()
	return options[_rotation]


func _load_track(index: int) -> void:
	current_track = index
	var stems: Array = TRACKS[index]
	for i: int in _stems.size():
		var stream: AudioStream = load(_stem_path(stems[i]))
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_stems[i].stream = stream


## Called from the Run Director's intensity signal. Stems at or below `level`
## fade in; the rest fade out.
func set_intensity(level: int) -> void:
	if level == intensity:
		return
	intensity = level
	for i: int in _stems.size():
		_fade(i, STEM_DB if i <= level else SILENT_DB)


func _fade(index: int, target_db: float) -> void:
	var rising: bool = target_db > _stems[index].volume_db
	_fade_over(index, target_db, FADE_IN if rising else FADE_OUT)


func _fade_over(index: int, target_db: float, seconds: float) -> void:
	var player: AudioStreamPlayer = _stems[index]
	if is_equal_approx(player.volume_db, target_db):
		return
	var old: Tween = _fades[index]
	if old != null and old.is_valid():
		old.kill()  # otherwise a fast intensity flip leaves two tweens fighting
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, seconds)
	_fades[index] = tween


## Victory has to MERGE with whatever is playing, not collide with it. Two
## problems, two fixes:
##
## 1. Key. The stinger resolves to A major, but the tracks rotate through A
##    Aeolian, D Phrygian and A Dorian — an A-major cadence over D Phrygian is
##    simply wrong. So the gameplay stems duck out rather than playing under it.
##    Three per-track stingers would also solve this; ducking solves it once.
## 2. Phase. A stinger that starts on the frame the boss died lands off the beat
##    and reads as a sound effect. Delaying to the next bar line makes it read as
##    the music arriving.
func play_victory() -> void:
	for i: int in _stems.size():
		_fade_over(i, SILENT_DB, VICTORY_DUCK)
	var wait: float = _time_to_next_bar()
	if wait > 0.02:
		# process_always, because victory pauses the tree.
		await get_tree().create_timer(wait).timeout
	_victory.play()


## Bring the layers back after the player chooses Continue.
func resume_gameplay() -> void:
	for i: int in _stems.size():
		_fade_over(i, STEM_DB if i <= intensity else SILENT_DB, FADE_IN)


## Seconds until the next bar line. The stems all started together and loop at
## exactly 16.00s, so any one of them reports the shared phase.
func _time_to_next_bar() -> float:
	if _stems.is_empty() or not _stems[0].playing:
		return 0.0
	var pos: float = _stems[0].get_playback_position()
	return CYCLE_SECONDS - fposmod(pos, CYCLE_SECONDS)


func _stop_gameplay() -> void:
	for i: int in _stems.size():
		var old: Tween = _fades[i]
		if old != null and old.is_valid():
			old.kill()
		_stems[i].stop()
	intensity = -1
