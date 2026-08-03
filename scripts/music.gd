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

## Track indices in CIRCLE-OF-FIFTHS order of their note collections:
## Darksynth (Bb major) - Lightcycle (F) - Neon (C) - Outrun (G).
## Rotation ping-pongs along this line instead of cycling 0-1-2-3, because the
## numeric order is nearly the worst one available: it steps C->Bb->G->F, and
## Darksynth->Outrun in particular is three accidentals plus a tonic change —
## the harshest pair in the set, back to back on every cycle. Ping-ponging the
## fifths makes EVERY transition a one-accidental move, and puts Darksynth (the
## only non-A tonic) next to Lightcycle alone — D to A, a plain fifth.
const FIFTHS: Array[int] = [1, 3, 0, 2]
var _rot_pos: int = -1
var _rot_dir: int = 1
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
## Full loop length. Every gameplay stem is exactly this long (705,600 samples),
## which is the invariant the migration below depends on.
const LOOP_SECONDS: float = 16.0

## Track switches MIGRATE over 8 bars (one full loop) instead of crossfading.
## A single long crossfade of whole tracks just sounds like two songs at once;
## what reads as one song TRANSFORMING into another is swapping the organs one
## at a time, each on its own schedule:
##
##   bars 0-2   outgoing LEAD exits        (melody clears the stage first)
##   bars 0-3   DRUMS crossfade            (groove morphs under intact harmony)
##   bars 3-5   BASS + ARP pivot TOGETHER  (the key change, as one block chord)
##   bars 5-8   incoming LEAD rises        (new melody over settled ground)
##
## Two rules produced that order. Melodies never overlap across keys — the old
## lead is gone before the harmony pivots, the new one enters after it lands.
## And the harmonic layers move as a unit, so the two keys only ever meet as
## full chord against full chord for two bars — adjacent keys on the circle of
## fifths (see FIFTHS), so that clash is a plagal lean, not a smear.
## Per layer [delay, duration] in seconds from the bar line the switch lands on.
const XF_IN: Array = [[6.0, 4.0], [0.0, 6.0], [6.0, 4.0], [10.0, 6.0]]
const XF_OUT: Array = [[6.0, 4.0], [0.0, 6.0], [6.0, 4.0], [0.0, 4.0]]
const MIGRATE_SECONDS: float = 16.0
## Fast enough to clear the way for the stinger, slow enough not to click.
const VICTORY_DUCK: float = 0.45

var intensity: int = -1

## TWO banks of stem players. `_stems` is always the AUDIBLE track; `_spare` is
## the other bank, which only sounds during a crossfade. A track switch loads
## the incoming track into `_spare`, starts it at the outgoing track's exact
## playback position — every track is the same 16.00s at the same cps, so phase,
## bar lines and position-in-form all carry across — then swaps the references
## and fades. The old way was stop-everything / start-from-zero: a hard cut,
## 1.1s of near-silence, and the new track entering mid-bar at cycle 0.
var _stems: Array[AudioStreamPlayer] = []
var _spare: Array[AudioStreamPlayer] = []
var _title: AudioStreamPlayer
var _victory: AudioStreamPlayer
var _fades: Array[Tween] = []
var _spare_fades: Array[Tween] = []
## A crossfade in flight. Switches arriving during one are dropped rather than
## queued: honouring a second switch mid-fade needs a third bank, and mashing
## the track button is not a use case worth one.
var _switching: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Players are created ONCE and have their stream swapped per track. Creating
	# them per run would restart audio nodes mid-session for no benefit.
	for i: int in LAYERS:
		_stems.append(_make_stem_player())
		_fades.append(null)
		_spare.append(_make_stem_player())
		_spare_fades.append(null)
	_title = _make_player(TITLE_TRACK, true)
	_victory = _make_player(VICTORY_TRACK, false)


func _make_stem_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Music"
	player.volume_db = SILENT_DB
	add_child(player)
	return player


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
	_crossfade_to(_choose_track(), maxi(0, intensity))


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
	_crossfade_to(index, maxi(0, intensity))


## The seamless switch. Waits for the next bar line, starts the incoming track
## on the spare bank at the outgoing track's EXACT playback position, swaps the
## banks, and runs the 8-bar stem migration (see XF_IN/XF_OUT). Phase-locking
## is what the identical stem lengths were for: bar 5 of Outrun becomes bar 5
## of Lightcycle, so the switch lands as a remix of the moment, not a cut.
func _crossfade_to(index: int, tier: int) -> void:
	if _switching:
		return
	_switching = true
	var wait: float = _time_to_next_bar()
	if wait > 0.02:
		# process_always: the pause panel's track button fires while paused.
		await get_tree().create_timer(wait).timeout
	# The run can end during the wait; starting a track over the game-over
	# screen would be worse than skipping the switch.
	if not _stems[0].playing:
		_switching = false
		return
	# get_time_since_last_mix compensates for the position only advancing per
	# mix chunk — without it the incoming track starts up to a chunk behind.
	var pos: float = fposmod(
		_stems[0].get_playback_position() + AudioServer.get_time_since_last_mix(),
		LOOP_SECONDS)
	_load_track(index, _spare)
	for player: AudioStreamPlayer in _spare:
		player.volume_db = SILENT_DB
		player.play(pos)
	# Swap the references: from here on, `_stems` IS the incoming track, so
	# set_intensity / victory / resume all route to it mid-migration for free.
	# (A tier change or victory duck landing mid-migration kills that stem's
	# scheduled fade and takes over — gameplay outranks choreography.)
	var bank: Array[AudioStreamPlayer] = _stems
	_stems = _spare
	_spare = bank
	var fades: Array[Tween] = _fades
	_fades = _spare_fades
	_spare_fades = fades
	intensity = tier
	for i: int in _stems.size():
		if i <= tier:
			_bank_fade(_stems, _fades, i, db_to_linear(STEM_DB),
					XF_IN[i][1], XF_IN[i][0], false)
	for i: int in _spare.size():
		_bank_fade(_spare, _spare_fades, i, 0.0,
				XF_OUT[i][1], XF_OUT[i][0], true)
	# Switches stay locked out until the migration lands: honouring one mid-way
	# would need a third bank, and the result would be three songs at once.
	await get_tree().create_timer(MIGRATE_SECONDS).timeout
	_switching = false


## Migration fades run on LINEAR amplitude with an expo-out curve, not on dB.
## A dB-linear crossfade dips to near-silence at its midpoint (-31 dB from
## both sides at once) — the old switch's "abrupt" feel was that dip. Expo-out
## rise and fall are complements, so a stem pair crossing on these curves sums
## to constant power the whole way.
func _bank_fade(bank: Array[AudioStreamPlayer], fades: Array[Tween], index: int,
		target_lin: float, seconds: float, delay: float, stop_when_done: bool) -> void:
	var player: AudioStreamPlayer = bank[index]
	var old: Tween = fades[index]
	if old != null and old.is_valid():
		old.kill()
	if not player.playing:
		return
	var from_lin: float = db_to_linear(player.volume_db)
	var tween: Tween = create_tween()
	tween.tween_method(
			func(v: float) -> void: player.volume_db = linear_to_db(maxf(v, 0.00001)),
			from_lin, target_lin, seconds
		).set_delay(delay).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if stop_when_done:
		tween.tween_callback(player.stop)
	fades[index] = tween


func _start_track(index: int, tier: int) -> void:
	_load_track(index, _stems)
	for player: AudioStreamPlayer in _stems:
		player.volume_db = SILENT_DB
		player.play()
	intensity = -1
	set_intensity(tier)


## Pinned track if one is forced, else the next along the circle of fifths.
## Rotation advances per RUN, so consecutive runs are audibly different — which
## is most of what stops a 16-second loop wearing out. Ping-pong rather than
## wrap: cycling would jump from one end of the fifths line to the other
## (Outrun back to Darksynth), recreating exactly the leap the ordering exists
## to avoid.
func _choose_track() -> int:
	var options: Array[int] = available_tracks()
	if options.is_empty():
		return 0
	if forced_track >= 0 and options.has(forced_track):
		return forced_track
	var order: Array[int] = []
	for t: int in FIFTHS:
		if options.has(t):
			order.append(t)
	for t: int in options:
		if not order.has(t):
			order.append(t)  # a fifth track before FIFTHS learns of it: appended, not lost
	if order.size() == 1:
		return order[0]
	_rot_pos += _rot_dir
	if _rot_pos >= order.size():
		_rot_pos = order.size() - 2
		_rot_dir = -1
	elif _rot_pos < 0:
		_rot_pos = 1
		_rot_dir = 1
	return order[_rot_pos]


func _load_track(index: int, into: Array[AudioStreamPlayer]) -> void:
	current_track = index
	var stems: Array = TRACKS[index]
	for i: int in into.size():
		var stream: AudioStream = load(_stem_path(stems[i]))
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		into[i].stream = stream


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
##    Aeolian, D Phrygian, A Dorian and A Phrygian — an A-major cadence over
##    either Phrygian is simply wrong. So the gameplay stems duck out rather
##    than playing under it. Four per-track stingers would also solve this;
##    ducking solves it once.
## 2. Phase. A stinger that starts on the frame the boss died lands off the beat
##    and reads as a sound effect. Delaying to the next bar line makes it read as
##    the music arriving.
func play_victory() -> void:
	for i: int in _stems.size():
		_fade_over(i, SILENT_DB, VICTORY_DUCK)
		# A victory landing mid-migration must also silence the outgoing bank,
		# or the stinger plays over the tail of the previous track.
		_bank_fade(_spare, _spare_fades, i, 0.0, VICTORY_DUCK, 0.0, true)
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
	# Both banks: a stop landing mid-crossfade must silence the outgoing track
	# too, or it keeps fading toward silence over the title screen.
	for i: int in _stems.size():
		var old: Tween = _fades[i]
		if old != null and old.is_valid():
			old.kill()
		_stems[i].stop()
		var old_spare: Tween = _spare_fades[i]
		if old_spare != null and old_spare.is_valid():
			old_spare.kill()
		_spare[i].stop()
	intensity = -1
