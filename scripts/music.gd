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

## Stem index == the intensity tier that switches it on. The Run Director
## publishes 0..3; tier 3 is a boss.
const STEMS: Array[String] = [
	"res://assets/audio/music/gameplay_0_bass.ogg",
	"res://assets/audio/music/gameplay_1_drums.ogg",
	"res://assets/audio/music/gameplay_2_arp.ogg",
	"res://assets/audio/music/gameplay_3_lead.ogg",
]
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

var intensity: int = -1

var _stems: Array[AudioStreamPlayer] = []
var _title: AudioStreamPlayer
var _victory: AudioStreamPlayer
var _fades: Array[Tween] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path: String in STEMS:
		var player := _make_player(path, true)
		player.volume_db = SILENT_DB
		_stems.append(player)
		_fades.append(null)
	_title = _make_player(TITLE_TRACK, true)
	_victory = _make_player(VICTORY_TRACK, false)


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
		return  # already running — a scene reload must not restart the music
	for player: AudioStreamPlayer in _stems:
		player.volume_db = SILENT_DB
		player.play()
	intensity = -1
	set_intensity(0)


## Called from the Run Director's intensity signal. Stems at or below `level`
## fade in; the rest fade out.
func set_intensity(level: int) -> void:
	if level == intensity:
		return
	intensity = level
	for i: int in _stems.size():
		_fade(i, STEM_DB if i <= level else SILENT_DB)


func _fade(index: int, target_db: float) -> void:
	var player: AudioStreamPlayer = _stems[index]
	if is_equal_approx(player.volume_db, target_db):
		return
	var old: Tween = _fades[index]
	if old != null and old.is_valid():
		old.kill()  # otherwise a fast intensity flip leaves two tweens fighting
	var rising: bool = target_db > player.volume_db
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", target_db,
			FADE_IN if rising else FADE_OUT)
	_fades[index] = tween


func play_victory() -> void:
	_victory.play()


func _stop_gameplay() -> void:
	for i: int in _stems.size():
		var old: Tween = _fades[i]
		if old != null and old.is_valid():
			old.kill()
		_stems[i].stop()
	intensity = -1
