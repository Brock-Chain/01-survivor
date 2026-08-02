extends Node
## Autoload "Sfx": fire-and-forget one-shots on a round-robin voice pool.
##
## A cue name maps to an ARRAY of streams. Sounds heard hundreds of times per
## run (shoot, hit, pop, pickup) ship as pre-rendered pitch-varied sets — a
## random variant per play, plus a little runtime pitch jitter, keeps repetition
## from turning into a drill. Sources live in audio_src/sfx/*.strudel; the WAVs
## are build artifacts of tools/build_sfx.py.
##
## Explicit preloads, not directory scanning — DirAccess listings misbehave
## inside exported .pck files (resources get .remap suffixes).

const VOICES: int = 12

const STREAMS: Dictionary = {
	&"shoot": [
		preload("res://assets/audio/sfx/shoot_0.wav"),
		preload("res://assets/audio/sfx/shoot_1.wav"),
		preload("res://assets/audio/sfx/shoot_2.wav"),
	],
	&"hit": [
		preload("res://assets/audio/sfx/hit_0.wav"),
		preload("res://assets/audio/sfx/hit_1.wav"),
		preload("res://assets/audio/sfx/hit_2.wav"),
	],
	&"pop": [
		preload("res://assets/audio/sfx/pop_0.wav"),
		preload("res://assets/audio/sfx/pop_1.wav"),
		preload("res://assets/audio/sfx/pop_2.wav"),
	],
	&"pickup": [
		preload("res://assets/audio/sfx/pickup_0.wav"),
		preload("res://assets/audio/sfx/pickup_1.wav"),
	],
	&"levelup": [preload("res://assets/audio/sfx/levelup.wav")],
	&"hurt": [preload("res://assets/audio/sfx/hurt.wav")],
	&"death": [preload("res://assets/audio/sfx/death.wav")],
	&"click": [preload("res://assets/audio/sfx/click.wav")],
	&"bolt": [preload("res://assets/audio/sfx/bolt.wav")],
	&"crit": [preload("res://assets/audio/sfx/crit.wav")],
	&"blast": [preload("res://assets/audio/sfx/blast.wav")],
	&"lance": [preload("res://assets/audio/sfx/lance.wav")],
	&"powerup": [preload("res://assets/audio/sfx/powerup.wav")],
	&"health": [preload("res://assets/audio/sfx/health.wav")],
	&"shield_on": [preload("res://assets/audio/sfx/shield_on.wav")],
	&"shield_off": [preload("res://assets/audio/sfx/shield_off.wav")],
	&"boss_telegraph": [preload("res://assets/audio/sfx/boss_telegraph.wav")],
	&"boss_spawn": [preload("res://assets/audio/sfx/boss_spawn.wav")],
	&"boss_death": [preload("res://assets/audio/sfx/boss_death.wav")],
}

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	# UI clicks must be audible while the tree is paused (level-up screen).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)


## Variant choice and jitter use the global RNG on purpose: cosmetic randomness
## must never consume from the seeded run stream, or sounds would change replays.
func play(sound: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var variants: Array = STREAMS[sound]
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = variants[randi() % variants.size()]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()
