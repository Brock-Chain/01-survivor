extends CPUParticles2D
## One-shot burst that colors itself like its victim, then self-frees.
## CPUParticles (not GPU) — they behave identically on web export.


## `power` scales the burst for things that deserve more than a Drifter's death.
##
## Review finding 7: a boss died with the SAME 12-particle burst sized for a 12px
## enemy as the smallest chaser in the game — the run's winning moment and its
## most repeated moment were juiced identically. Particle count, spread velocity,
## size and lifetime all scale together, because raising only the count reads as
## "more of the same" rather than "bigger".
func setup(tint: Color, power: float = 1.0) -> void:
	color = tint
	if is_equal_approx(power, 1.0):
		return
	amount = int(round(float(amount) * power * 1.7))
	initial_velocity_min *= power
	initial_velocity_max *= power
	scale_amount_min *= power * 0.9
	scale_amount_max *= power * 0.9
	lifetime *= 1.0 + (power - 1.0) * 0.45


func _ready() -> void:
	emitting = true
	finished.connect(queue_free)
