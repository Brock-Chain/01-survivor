class_name GameCamera
extends Camera2D
## Trauma-based screenshake: hits add trauma, shake = trauma², decays fast.
## Squaring makes small hits subtle and big hits violent — the classic model.

## Review finding 6: shake was SUB-PERCEPTUAL for everything except Second Wind.
## MAX_OFFSET 6 with a squared curve turned the kill beat's 0.12 trauma into
## 6 * 0.12^2 = 0.086 viewport px — about a sixth of one pixel, i.e. nothing. The
## squaring is what ate it: it is the right shape for making big hits violent and
## the wrong shape for letting small ones register at all.
##
## Fixed at both ends: a larger ceiling, and an exponent of 1.6 instead of 2.0 so
## the low end survives while the top stays punchy. Budgeted in VIEWPORT pixels
## (640x360) — the canvas_items stretch doubles everything for the 1280x720
## window, so 6 here is 12 physical px at full trauma.
##
## Playtest 2026-08-03: "Camera shake is too much." Was 9.0. Cut at the CEILING
## rather than per call site on purpose — there are nine `add_trauma` callers and
## every one of their values is a deliberate relative weight (a kill is 0.22, a
## hit 0.5, Second Wind 1.0). Scaling the ceiling tones the whole game down by a
## third and leaves all nine of those relationships exactly where they were;
## editing them one at a time would have quietly re-argued each one.
const MAX_OFFSET: float = 6.0
const DECAY: float = 1.8
## Below 2.0 the small beats survive; above 1.0 big hits still dominate.
const CURVE: float = 1.6

var _trauma: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## Kill trauma, capped PER FRAME.
##
## Playtest 2026-08-02: "lower camera shake a bit when killing a ton of enemies,
## makes it a bit hard to see." `add_trauma` SUMS, so five simultaneous kills
## already pin the camera at maximum — and a mass-kill cascade (Second Wind, an
## Event Horizon chain, a wide Lance volley through a crowd) is forty.
##
## The single-kill value is deliberately untouched: 0.22 was the fix for review
## finding 6, where the kill beat produced 0.086px of shake and registered as
## nothing. One kill should still be felt. Forty kills should not be forty times
## as violent — they should be one big hit.
##
## Tightened 0.30 -> 0.20 on 2026-08-03: the same complaint came back a day
## later, and mass-kill is the case that generates the most shake per second in
## normal play. A single kill is 0.22, so the cap now means a cascade reads as
## roughly ONE kill's worth of punch instead of one and a half.
const KILL_TRAUMA_FRAME_CAP: float = 0.20

var _kill_frame: int = -1
var _kill_frame_spent: float = 0.0


func add_kill_trauma(amount: float) -> void:
	var now: int = Engine.get_physics_frames()
	if now != _kill_frame:
		_kill_frame = now
		_kill_frame_spent = 0.0
	var allowed: float = minf(amount, maxf(0.0, KILL_TRAUMA_FRAME_CAP - _kill_frame_spent))
	if allowed <= 0.0:
		return
	_kill_frame_spent += allowed
	add_trauma(allowed)


## What `amount` of trauma is worth in viewport pixels. Pure and public so the
## next person to tune a trauma value can check it against the screen instead of
## guessing — guessing is how 0.086 px shipped.
##
## Describes the DESIGN, so it deliberately ignores the player's shake setting: a
## tuning value has to be checkable against a fixed ruler, not against whatever
## the last person left toggled.
static func shake_pixels(amount: float) -> float:
	return MAX_OFFSET * pow(clampf(amount, 0.0, 1.0), CURVE)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	# Trauma decays whether or not shake is being DRAWN, so switching the setting
	# back on mid-run cannot inherit a stale pile of it and lurch.
	_trauma = maxf(_trauma - DECAY * delta, 0.0)
	var shake: float = pow(_trauma, CURVE) * Settings.shake_scale()
	offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * MAX_OFFSET * shake
