extends Node
## Autoload "Sfx": fire-and-forget one-shots on a round-robin voice pool.
## Pitch jitter keeps repeated sounds from turning into a drill.

const VOICES: int = 12

const STREAMS: Dictionary = {
	&"shoot": preload("res://assets/audio/sfx/shoot.wav"),
	&"hit": preload("res://assets/audio/sfx/hit.wav"),
	&"pop": preload("res://assets/audio/sfx/pop.wav"),
	&"pickup": preload("res://assets/audio/sfx/pickup.wav"),
	&"levelup": preload("res://assets/audio/sfx/levelup.wav"),
	&"hurt": preload("res://assets/audio/sfx/hurt.wav"),
	&"death": preload("res://assets/audio/sfx/death.wav"),
	&"click": preload("res://assets/audio/sfx/click.wav"),
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


func play(sound: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = STREAMS[sound]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()
