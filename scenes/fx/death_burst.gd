extends CPUParticles2D
## One-shot burst that colors itself like its victim, then self-frees.
## CPUParticles (not GPU) — they behave identically on web export.


func setup(tint: Color) -> void:
	color = tint


func _ready() -> void:
	emitting = true
	finished.connect(queue_free)
