class_name PowerUpResource
extends Resource
## One power-up = one .tres. Content, not code — same rule as upgrades and
## enemies.
##
## Power-ups are the SHORT-TERM counterpart to upgrades: an upgrade changes the
## rest of the run, a power-up changes the next few seconds. That is why they
## are a world drop you have to move to collect rather than a menu choice —
## the decision is "is that worth walking into", not "which do I want".

enum Kind {
	SHIELD,      ## temporary invulnerability
	POWER,       ## damage multiplier
	HASTE,       ## fire-rate multiplier
	COLLECT,     ## INSTANT: pulls every XP gem on the map
}

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.SHIELD
## Seconds. Ignored by instant kinds (COLLECT).
@export var duration: float = 6.0
## Silhouette. Per the colour law, power-ups all share the player's cyan family
## and are told apart by SHAPE — adding four more hues would collide with the
## XP green, the health white-cyan, or the danger band.
@export var sprite: Texture2D
@export var tint: Color = Color(0.55, 1.0, 0.95)
## Relative drop weight among power-ups.
@export var weight: float = 1.0


## The buff this grants, or &"" for an instant effect that grants nothing.
func buff_id() -> StringName:
	match kind:
		Kind.SHIELD:
			return BuffState.SHIELD
		Kind.POWER:
			return BuffState.POWER
		Kind.HASTE:
			return BuffState.HASTE
		_:
			return &""


func is_instant() -> bool:
	return buff_id() == &""
