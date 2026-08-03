class_name RunState
extends RefCounted
## Everything true of ONE run, and nothing that outlives it.
##
## Deliberately a separate object from MetaState rather than a section of it.
## The invariant that matters (RunDirector/Meta contract): run state and meta
## state never share a reference, so a run can never write through into the
## save. Copies cross the boundary, never objects.

## The seed this run was generated from. Same seed + same schedule reproduces
## the run: upgrade draws, enemy choice and spawn placement all pull from the
## single RNG Main seeds with this.
var seed_value: int = 0

var elapsed: float = 0.0
var kills: int = 0
var level: int = 1
var total_xp: int = 0
var won: bool = false
## Boss events fully cleared this run. The skill tree's currency is DEPTH-
## weighted, so this is the half of the formula that rewards getting further
## rather than surviving longer, and it is the only reason a failed NOGAXEH
## attempt is still worth something.
var boss_events: int = 0
## Shards already paid out for this run at its victory banking. Endless pays the
## difference at the real end, so continuing can never be a currency loss.
var shards_banked: int = 0


static func with_seed(p_seed: int) -> RunState:
	var s := RunState.new()
	s.seed_value = p_seed
	return s


## A fresh random seed. Split out so a "replay this seed" entry point is a
## one-line change later rather than a refactor.
static func random_seed_value() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return int(rng.randi())


## Flat, immutable summary handed to MetaState at the end of a run. Returning a
## plain Dictionary here is the boundary: Meta receives VALUES, never this node.
func to_result() -> Dictionary:
	return {
		"seed": seed_value,
		"time": elapsed,
		"kills": kills,
		"level": level,
		"won": won,
		"boss_events": boss_events,
		"shards_banked": shards_banked,
	}
