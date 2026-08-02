class_name Health
extends RefCounted
## Pure HP logic with an invulnerability window. Time is INJECTED (callers
## pass `now`) so this is unit-testable without the scene tree or real time.

signal changed(hp: int, max_hp: int)
signal died

var max_hp: int
var hp: int
var invuln_duration: float

var _invuln_until: float = -INF


func _init(p_max_hp: int, p_invuln_duration: float = 0.6) -> void:
	max_hp = p_max_hp
	hp = p_max_hp
	invuln_duration = p_invuln_duration


## Returns true if damage was applied (not blocked by i-frames or death).
func take_damage(amount: int, now: float) -> bool:
	if hp <= 0 or now < _invuln_until:
		return false
	hp = maxi(hp - amount, 0)
	_invuln_until = now + invuln_duration
	changed.emit(hp, max_hp)
	if hp == 0:
		died.emit()
	return true


func heal(amount: int) -> void:
	if hp <= 0:
		return
	hp = mini(hp + amount, max_hp)
	changed.emit(hp, max_hp)


func raise_max(amount: int) -> void:
	max_hp += amount
	hp = mini(hp + amount, max_hp)
	changed.emit(hp, max_hp)


func is_invulnerable(now: float) -> bool:
	return now < _invuln_until
