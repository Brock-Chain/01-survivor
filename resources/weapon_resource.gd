class_name WeaponResource
extends Resource
## SYSTEM CONTRACT — Weapons as data
##
## Purpose: describe ONE weapon's numbers and identity, so adding a weapon is a
##   .tres file plus (at most) one behaviour script, never a rewrite of Stats.
##
## Data: this resource. Base values live here; the player's Stats holds global
##   MULTIPLIERS. Final value = base (weapon) x modifier (player). That split is
##   the whole design — it is why "+12% fire rate" can improve two weapons that
##   fire at completely different base rates without either becoming absurd.
##
## Ownership:
##   Owns:      one weapon's base numbers and its kind.
##   Does NOT own: current cooldowns or spawned nodes (the weapon NODE owns
##              those), player-wide modifiers (Stats), whether the player has
##              ever earned it (MetaState), or whether they are holding it right
##              now (Stats.drafted_weapons).
##
## Invariants:
##   1. A weapon that has not been drafted never fires and never spawns
##      anything — resolved on each draft, not per frame.
##   2. Base values are never mutated at runtime. Upgrades change Stats, not
##      this; a Resource shared between runs must stay pristine.
##
## Failure mode: `is_available()` is false until the weapon is drafted, and the
##   weapon node disables itself. A missing weapon is a quiet no-op.
##
## Done when: both weapons read as distinct in a 30-second clip.

enum Kind {
	PROJECTILE,  ## fires at the nearest enemy in range
	ORBITAL,     ## bodies circling the player, damaging on contact
	BEAM,        ## instant piercing line, everything along it hit at once
}

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.PROJECTILE
## Sfx cue played when this weapon fires. Data, not code: the scattergun's boom
## and the blaster's zap differ by .tres field, never by a branch in the script.
@export var fire_sound: StringName = &"shoot"

@export_group("Base numbers")
@export var damage: int = 1
## PROJECTILE: seconds between volleys. ORBITAL: seconds between hits on the
## same enemy.
@export var interval: float = 0.8
## PROJECTILE: shots per volley. ORBITAL: number of orbiting bodies.
@export var count: int = 1
@export var range: float = 260.0

@export_group("Projectile")
@export var projectile_speed: float = 340.0
@export var spread_deg: float = 7.0

@export_group("Orbital")
@export var orbit_radius: float = 46.0
@export var orbit_speed: float = 2.4


## True if this weapon has been drafted in the run currently being played.
##
## There is no separate gate field: a weapon's gate IS its id, so a weapon and
## its requirement cannot drift apart. The list is passed IN rather than read
## from Stats or the Meta autoload — a Resource that reaches for a global
## singleton cannot be compiled outside a running game (tool scripts fail
## outright), and it silently couples content data to run state.
func is_available(drafted: Array[StringName]) -> bool:
	return drafted.has(id)
