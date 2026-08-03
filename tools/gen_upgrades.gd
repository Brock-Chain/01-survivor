extends SceneTree
## Authors every upgrade .tres, tiered by rarity.
##
##   <console.exe> --headless --path . -s res://tools/gen_upgrades.gd
##
## A tier is a DESIGN SLOT, not a multiplier. A Rare damage upgrade is its own
## entry with its own number rather than a Common one scaled up — which is what
## lets Legendary mean a different EFFECT instead of a bigger one.
##
## Pool shape (playtest direction 2026-08-02: "rarity ... not just stat boosts,
## get creative", levels reduced ~30% and options buffed to compensate):
##   COMMON     small bumps, the bread and butter
##   UNCOMMON   the same axes, meaningfully larger
##   RARE       build-shaping: extra projectiles, pierce, crits, orbitals
##   EPIC       semi-unique — changes how a weapon behaves
##   LEGENDARY  unique, run-defining
##
## At least one UNLIMITED-stack entry must exist per low tier or the pool dries
## up and late levels have nothing legal to offer — that shipped once, and at
## level 37 the only legal draw was a heal.

const OUT: String = "res://resources/upgrades"
## The generated manifest main.gd reads. Wholly owned by this tool.
const MANIFEST: String = "res://resources/upgrades/upgrade_list.gd"

## Ids actually saved this run, in save order. Drives the manifest, so the list
## can never disagree with what is on disk.
var _written: Array[String] = []

const C := Rarity.Tier.COMMON
const U := Rarity.Tier.UNCOMMON
const R := Rarity.Tier.RARE
const E := Rarity.Tier.EPIC
const L := Rarity.Tier.LEGENDARY


func _init() -> void:
	var eff := UpgradeResource.Effect
	# id, name, description, effect, magnitude, max_stacks, weight, tier
	var defs: Array = [
		# ---- COMMON ---------------------------------------------------------
		["swift_boots", "Swift Boots", "+8% move speed", eff.MOVE_SPEED, 0.08, 5, 1.0, C],
		["sharp_shots", "Sharp Shots", "+1 damage", eff.DAMAGE, 1.0, 5, 1.0, C],
		["rapid_fire", "Rapid Fire", "8% faster firing", eff.FIRE_RATE, 0.08, 5, 1.0, C],
		["magnetism", "Magnetism", "+24px pickup range", eff.MAGNET, 24.0, 4, 0.7, C],
		["scholar", "Scholar", "+10% XP gained", eff.XP_GAIN, 0.10, 4, 0.8, C],
		["tough_hide", "Tough Hide", "+1 max HP", eff.MAX_HP, 1.0, 5, 0.8, C],
		["velocity", "Velocity", "+15% projectile speed", eff.PROJECTILE_SPEED, 0.15, 4, 0.7, C],
		# Unlimited: the floor that guarantees the pool can always offer something.
		["overdrive", "Overdrive", "+1 damage", eff.DAMAGE, 1.0, 0, 0.5, C],

		# ---- UNCOMMON -------------------------------------------------------
		["momentum", "Momentum", "+14% move speed", eff.MOVE_SPEED, 0.14, 4, 1.0, U],
		["honed_edge", "Honed Edge", "+2 damage", eff.DAMAGE, 2.0, 4, 1.0, U],
		["cadence", "Cadence", "15% faster firing", eff.FIRE_RATE, 0.15, 4, 1.0, U],
		["siphon", "Siphon", "8% chance to recover 1 HP per kill", eff.LIFESTEAL, 0.08, 4, 0.9, U],
		["carapace", "Carapace", "+2 max HP", eff.MAX_HP, 2.0, 4, 0.8, U],
		["lodestone", "Lodestone", "+60px pickup range", eff.MAGNET, 60.0, 2, 0.6, U],
		# A projectile source at Uncommon too: multishot is a signature mechanic and
		# must not be something a player can finish a run without ever seeing.
		# The old text promised "-20% damage" that NOTHING ever applied — the effect
		# only ever added a projectile. The cost is real now and lives in
		# Stats.volley_damage_mult, so it is charged once, globally, and no future
		# projectile source can forget to pay it. Cards state the rule; the pause
		# stats tab shows the player's current number.
		["scatter", "Scatter", "+1 projectile · wider volleys hit softer", eff.PROJECTILE_COUNT, 1.0, 2, 1.2, U],
		["relentless", "Relentless", "+8% move speed", eff.MOVE_SPEED, 0.08, 0, 0.4, U],

		# ---- RARE -----------------------------------------------------------
		["cannonball", "Cannonball", "+4 damage", eff.DAMAGE, 4.0, 3, 1.0, R],
		# Weight was 2.2 — the highest in the entire pool, more than double anything
		# else — so the draw actively steered every run onto the most multiplicative
		# axis in the game. Telemetry: split_shot x3 in a 44-pick run.
		["split_shot", "Split Shot", "+1 projectile · wider volleys hit softer", eff.PROJECTILE_COUNT, 1.0, 3, 1.0, R],
		["pierce", "Piercing Rounds", "Shots punch through +1 enemy", eff.PIERCE, 1.0, 3, 1.0, R],
		["focus", "Focus", "+12% critical chance (2.5x damage)", eff.CRIT_CHANCE, 0.12, 5, 1.0, R],
		["fusillade", "Fusillade", "28% faster firing", eff.FIRE_RATE, 0.28, 2, 0.9, R],
		["reservoir", "Reservoir", "+4 max HP", eff.MAX_HP, 4.0, 2, 0.7, R],

		# ---- EPIC · semi-unique, changes HOW a weapon behaves ----------------
		["ricochet", "Ricochet", "Shots bounce to a second target", eff.RICOCHET, 1.0, 2, 1.0, E],
		["cryo_rounds", "Cryo Rounds", "Hits slow enemies by 40%", eff.CRYO, 0.40, 2, 1.0, E],
		["executioner", "Executioner", "Enemies below 15% HP die instantly", eff.EXECUTE, 0.15, 2, 1.0, E],
		["greed", "Greed", "+50% XP, and gems come to you", eff.GREED, 0.50, 2, 0.9, E],
		["aegis", "Aegis", "A free 2s shield every 20s", eff.AEGIS, 20.0, 2, 0.9, E],

		# ---- LEGENDARY · unique, run-defining --------------------------------
		["prism_core", "Prism Core", "Shots split into a fan on impact", eff.PRISM_CORE, 3.0, 1, 1.0, L],
		["event_horizon", "Event Horizon", "Kills implode, dragging in and hurting neighbours", eff.EVENT_HORIZON, 70.0, 1, 1.0, L],
		["overclock", "Overclock", "Every 8th shot is a piercing mega-bolt", eff.OVERCLOCK, 8.0, 1, 1.0, L],
		["second_wind", "Second Wind", "Survive one lethal hit and blast the screen clear", eff.SECOND_WIND, 1.0, 1, 1.0, L],
		["chain_lightning", "Chain Lightning", "Shots arc to 2 nearby enemies", eff.CHAIN, 2.0, 1, 1.0, L],
		["barrage", "Barrage", "+2 projectiles · wider volleys hit softer", eff.PROJECTILE_COUNT, 2.0, 1, 1.0, E],
	]
	_write(defs, &"")

	# Orbital upgrades exist only once the Prism has been beaten, so they never
	# clutter the offers of a player who has not unlocked the weapon.
	_write([
		["orbit_count", "Split Orbit", "+1 orbiting shard", eff.ORBITAL_COUNT, 1.0, 4, 1.1, R],
		["orbit_speed", "Spin Up", "+25% orbit speed and hit rate", eff.ORBITAL_SPEED, 0.25, 3, 0.9, R],
		["orbit_radius", "Wide Orbit", "+16px orbit radius", eff.ORBITAL_RADIUS, 16.0, 3, 0.7, U],
		["nova_orbit", "Nova Orbit", "Orbitals detonate on kill", eff.NOVA_ORBIT, 60.0, 1, 1.0, E],
	], MetaState.UNLOCK_ORBITAL)

	_write_manifest()
	print("gen_upgrades: %d upgrades + manifest" % _written.size())
	quit(0)


## THE COMPANION STEP. Review finding 23: main.gd's UPGRADE_LIST carried the
## comment "GENERATED by tools/gen_upgrades.gd's companion step — do not
## hand-edit", and that step did not exist. The list was hand-maintained, its own
## comment said "36 entries" against a list of 38, and the failure it warned
## about — a new .tres silently missing from the pool — was therefore live.
##
## Emitting a separate script rather than rewriting main.gd: a generator that
## edits a hand-written file is a generator that will eventually eat something.
## This file is wholly owned by the tool and safe to clobber.
func _write_manifest() -> void:
	_written.sort()
	var lines: PackedStringArray = [
		"class_name UpgradeList",
		"## GENERATED by tools/gen_upgrades.gd — DO NOT HAND-EDIT.",
		"##",
		"## Explicit preloads rather than a DirAccess scan: directory listings",
		"## misbehave inside an exported .pck (resources gain .remap suffixes), so",
		"## the pool would silently shrink on the web build only.",
		"##",
		"## Regenerate:",
		"##   <console.exe> --headless --path . -s res://tools/gen_upgrades.gd",
		"",
		"const ALL: Array[UpgradeResource] = [",
	]
	for id: String in _written:
		lines.append("\tpreload(\"%s/%s.tres\")," % [OUT, id])
	lines.append("]")
	lines.append("")
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		push_error("gen_upgrades: cannot write %s" % MANIFEST)
		return
	file.store_string("\n".join(lines))


func _write(defs: Array, requires: StringName) -> void:
	for d: Array in defs:
		var u := UpgradeResource.new()
		u.id = StringName(d[0])
		u.display_name = d[1]
		u.description = d[2]
		u.effect = d[3]
		u.magnitude = d[4]
		u.max_stacks = d[5]
		u.weight = d[6]
		u.rarity = d[7]
		u.requires_unlock = requires
		var path: String = "%s/%s.tres" % [OUT, u.id]
		u.resource_path = path
		if ResourceSaver.save(u, path) != OK:
			push_error("gen_upgrades: FAILED %s" % path)
			continue
		_written.append(String(u.id))
