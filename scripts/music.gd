extends Node
## Autoload "Music": one looping gameplay track. Survives scene reloads
## (autoloads persist), so restarts don't stutter the music.

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stream: AudioStreamWAV = preload("res://assets/audio/music/loop.wav")
	# The generated WAV carries no loop metadata — set the loop in code.
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.data.size() / 2.0)  # 16-bit mono: 2 bytes per frame
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	_player.stream = stream
	add_child(_player)


func play_gameplay() -> void:
	if not _player.playing:
		_player.play()
