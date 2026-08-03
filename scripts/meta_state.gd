class_name MetaState
extends RefCounted
## Everything that SURVIVES a run: records, totals, and unlocks.
##
## Serialization is JSON, not a .tres and not ConfigFile. The project convention
## is "game data is Resources, never dictionaries" — that governs CONTENT
## authored by us, which ships read-only inside the .pck. A save file is
## user-writable, and BOTH `.tres` and `.cfg` parsers construct objects while
## parsing: a crafted `.cfg` ran an attacker script's `_init()` inside
## `ConfigFile.load()` when it was measured on 4.7.1. `JSON.parse_string()`
## structurally cannot — its grammar cannot name a class. See `UserStore` and
## hub/knowledge/save-files-and-trust.md.
##
## Unlocks are milestones, not a shop. Each is earned by doing a specific thing,
## so the reward for a first victory is a new way to play rather than a number.


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

## SHARDS — the skill tree's currency, and the run tally it is earned from.
##
## Deliberately DEPTH-weighted rather than kill-weighted: time survived plus a
## chunk per boss event cleared. Kills would pay best for farming the easy
## minutes, which is the opposite of what the game wants to teach; this pays for
## getting FURTHER, and it keeps a failed NOGAXEH attempt worth something, which
## matters when that fight is two minutes long and can end in a detonation.
var shards: int = 0
## Skill-tree nodes bought. Ids, not indices, for the same reason unlocks are:
## reordering or removing a node can never silently shift another.
var purchases: Array[StringName] = []

const SHARDS_PER_MINUTE: int = 6
const SHARDS_PER_BOSS_EVENT: int = 25


## What a finished run is worth. Pure and static so the number is assertable and
## so the skill-tree screen can show the player the formula's terms.
static func shards_for(time_survived: float, boss_events: int) -> int:
	return int(time_survived / 60.0 * float(SHARDS_PER_MINUTE)) \
			+ SHARDS_PER_BOSS_EVENT * maxi(0, boss_events)


func has_purchase(id: StringName) -> bool:
	return purchases.has(id)


## Spend, if it can be afforded and has not already been bought. Returns whether
## the purchase happened, so the UI never has to re-derive the rules.
func buy(id: StringName, cost: int) -> bool:
	if id == &"" or has_purchase(id) or cost > shards:
		return false
	shards -= cost
	purchases.append(id)
	return true


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
	shards += shards_for(time, int(result.get("boss_events", 0)))
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
	# Shards are paid on the run's FULL depth, minus what the victory already
	# paid. A run banked at 5:20 that then dies at 11:00 earned the whole eleven
	# minutes and both boss events — anything else would make continuing into
	# endless a currency loss, which is the exact opposite of the intent.
	var earned: int = shards_for(float(result.get("time", 0.0)),
			int(result.get("boss_events", 0)))
	shards += maxi(0, earned - int(result.get("shards_banked", 0)))
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


func to_dict() -> Dictionary:
	# Ids are stored as plain Strings: StringName does not survive a JSON round
	# trip as itself, and a save that silently loses unlocks is the worst bug
	# available here.
	var ids: Array[String] = []
	for id: StringName in unlocks:
		ids.append(String(id))
	var bought: Array[String] = []
	for id: StringName in purchases:
		bought.append(String(id))
	return {
		"runs_played": runs_played,
		"victories": victories,
		"best_time": best_time,
		"best_kills": best_kills,
		"total_kills": total_kills,
		"shards": shards,
		"unlocks": ids,
		"purchases": bought,
	}


## Tolerant by design: any missing or wrong-typed key falls back to its default
## rather than erroring. A corrupt save costs progress; a crash on boot costs
## the whole game. The int narrowing is not cosmetic — JSON hands every number
## back as a float, so without it `runs_played` becomes 12.0 and every integer
## comparison against it quietly starts lying.
static func from_dict(data: Dictionary) -> MetaState:
	var m := MetaState.new()
	m.runs_played = UserStore.get_int(data, "runs_played", 0)
	m.victories = UserStore.get_int(data, "victories", 0)
	m.best_time = UserStore.get_float(data, "best_time", 0.0)
	m.best_kills = UserStore.get_int(data, "best_kills", 0)
	m.total_kills = UserStore.get_int(data, "total_kills", 0)
	m.shards = UserStore.get_int(data, "shards", 0)
	m.unlocks = _ids(data.get("unlocks"))
	m.purchases = _ids(data.get("purchases"))
	return m


## Tolerant id-list read, shared by unlocks and purchases: anything that is not
## an Array reads as empty, and duplicates and blanks are dropped. A save written
## by an older build simply has no `purchases` key and lands here as [].
static func _ids(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is Array:
		for entry: Variant in (raw as Array):
			var id := StringName(str(entry))
			if id != &"" and not out.has(id):
				out.append(id)
	return out
