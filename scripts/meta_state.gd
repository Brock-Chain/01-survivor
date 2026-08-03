class_name MetaState
extends RefCounted
## Everything that SURVIVES a run: records, totals, and unlocks.
##
## Serialization is ConfigFile, not a .tres. The project convention is
## "game data is Resources, never dictionaries" — that governs CONTENT authored
## by us. A save file is user-writable, and `load()`ing a Resource from a
## user-writable path will happily instantiate whatever script the file names.
## ConfigFile is typed, human-readable, and cannot execute anything.
##
## Unlocks are milestones, not a shop. Each is earned by doing a specific thing,
## so the reward for a first victory is a new way to play rather than a number.

const SECTION: String = "meta"

## Unlock ids. Referenced by content (weapons, upgrades) rather than by index,
## so reordering or removing one can never silently shift another.
const UNLOCK_ORBITAL: StringName = &"orbital"
const UNLOCK_ELITE_HUNTER: StringName = &"elite_hunter"
const UNLOCK_ENDLESS_PROVEN: StringName = &"endless_proven"
## Beating the Prism also hands over a VERB, not just a weapon. The dash is
## deliberately absent from the first five minutes — the run a stranger plays is
## unchanged by it — and arrives exactly when the arena starts turning into
## bullet hell on the way to Nogaxeh at 10:00. Bullet hell without a dodge is
## arbitrary rather than hard.
const UNLOCK_DASH: StringName = &"dash"

var runs_played: int = 0
var victories: int = 0
var best_time: float = 0.0
var best_kills: int = 0
var total_kills: int = 0
var unlocks: Array[StringName] = []


func has_unlock(id: StringName) -> bool:
	return unlocks.has(id)


## Player-facing name for an unlock. Lives here, next to the ids themselves, so
## adding a milestone cannot leave the UI announcing a raw StringName — which is
## the failure mode that made review finding 2 easy to ship in the first place.
static func unlock_label(id: StringName) -> String:
	match id:
		UNLOCK_ORBITAL:
			return "ORBITALS"
		UNLOCK_DASH:
			return "DASH"
		UNLOCK_ELITE_HUNTER:
			return "SCATTERGUN"
		UNLOCK_ENDLESS_PROVEN:
			return "PRISM LANCE"
	return String(id).to_upper()


## One line telling the player what they can now DO. An unlock the player cannot
## act on is the same as no unlock at all.
##
## Since M7.3 the weapon milestones hand over a CARD, not a weapon: the text has
## to say so, or a player who is told "shards now orbit you" and then sees no
## shards has been lied to by their own reward screen.
static func unlock_blurb(id: StringName) -> String:
	match id:
		UNLOCK_ORBITAL:
			return "Orbitals can now be drafted as a level-up card."
		UNLOCK_DASH:
			return "Press SPACE to dash. You cannot be hit mid-dash."
		UNLOCK_ELITE_HUNTER:
			return "The Scattergun can now be drafted as a level-up card."
		UNLOCK_ENDLESS_PROVEN:
			return "The Prism Lance can now be drafted as a level-up card."
	return ""


## Fold one finished run into the persistent record and return the ids unlocked
## BY THIS RUN (empty if none). Takes the flat result Dictionary from
## RunState.to_result() — never the RunState itself, so nothing can alias.
func absorb(result: Dictionary) -> Array[StringName]:
	runs_played += 1
	var kills: int = int(result.get("kills", 0))
	var time: float = float(result.get("time", 0.0))
	var won: bool = bool(result.get("won", false))

	total_kills += kills
	best_kills = maxi(best_kills, kills)
	best_time = maxf(best_time, time)
	if won:
		victories += 1

	var gained: Array[StringName] = []
	for id: StringName in _earned(kills, time, won):
		if not unlocks.has(id):
			unlocks.append(id)
			gained.append(id)
	return gained


## Update for a run that was ALREADY banked at its victory moment. Endless play
## after a win still improves records and still earns MILESTONES — a banked run
## is absorbed at ~5:20, so "survive to the double boss" can only ever be true
## here. Without this, ENDLESS_PROVEN (and the weapon behind it) was
## unobtainable by exactly the players it describes. Only the run tally is
## frozen at the banking point, or endless would count as a second run.
## Returns ids unlocked by the endless stretch (empty if none).
func update_records(result: Dictionary) -> Array[StringName]:
	best_kills = maxi(best_kills, int(result.get("kills", 0)))
	best_time = maxf(best_time, float(result.get("time", 0.0)))
	var gained: Array[StringName] = []
	for id: StringName in _earned(int(result.get("kills", 0)),
			float(result.get("time", 0.0)), bool(result.get("won", false))):
		if not unlocks.has(id):
			unlocks.append(id)
			gained.append(id)
	return gained


## Unlock rules, pure and in one place so "what does this reward?" is answerable
## without reading the run loop.
func _earned(kills: int, time: float, won: bool) -> Array[StringName]:
	var earned: Array[StringName] = []
	if won:
		earned.append(UNLOCK_ORBITAL)          # beating the Prism buys a second weapon
		earned.append(UNLOCK_DASH)             # ...and the verb that endless demands
	if victories >= 1 and time >= 600.0:
		earned.append(UNLOCK_ENDLESS_PROVEN)   # survived to the double-boss event
	if total_kills >= 1000:
		earned.append(UNLOCK_ELITE_HUNTER)
	return earned


func to_config(cfg: ConfigFile) -> void:
	cfg.set_value(SECTION, "runs_played", runs_played)
	cfg.set_value(SECTION, "victories", victories)
	cfg.set_value(SECTION, "best_time", best_time)
	cfg.set_value(SECTION, "best_kills", best_kills)
	cfg.set_value(SECTION, "total_kills", total_kills)
	# Stored as plain Strings: StringName round-trips inconsistently through
	# ConfigFile, and a save that silently loses unlocks is the worst bug here.
	var ids: Array[String] = []
	for id: StringName in unlocks:
		ids.append(String(id))
	cfg.set_value(SECTION, "unlocks", ids)


## Tolerant by design: any missing or wrong-typed key falls back to its default
## rather than erroring. A corrupt save costs progress; a crash on boot costs
## the whole game.
static func from_config(cfg: ConfigFile) -> MetaState:
	var m := MetaState.new()
	m.runs_played = int(cfg.get_value(MetaState.SECTION, "runs_played", 0))
	m.victories = int(cfg.get_value(MetaState.SECTION, "victories", 0))
	m.best_time = float(cfg.get_value(MetaState.SECTION, "best_time", 0.0))
	m.best_kills = int(cfg.get_value(MetaState.SECTION, "best_kills", 0))
	m.total_kills = int(cfg.get_value(MetaState.SECTION, "total_kills", 0))
	var raw: Variant = cfg.get_value(MetaState.SECTION, "unlocks", [])
	if raw is Array:
		for entry: Variant in (raw as Array):
			var id := StringName(str(entry))
			if id != &"" and not m.unlocks.has(id):
				m.unlocks.append(id)
	return m
