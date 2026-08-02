class_name GameCamera
extends Camera2D
## Trauma-based screenshake: hits add trauma, shake = trauma², decays fast.
## Squaring makes small hits subtle and big hits violent — the classic model.

const MAX_OFFSET: float = 6.0
const DECAY: float = 1.8

var _trauma: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_trauma = maxf(_trauma - DECAY * delta, 0.0)
	var shake: float = _trauma * _trauma
	offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * MAX_OFFSET * shake
