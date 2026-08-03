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
##
## MAGNITUDES REBALANCED 2026-08-02 (M7.3), roughly 2-3x on the stat axes. This
## is not power creep, it is the other half of `Progression.CARD_EVERY`: the spec
## is "3x fewer, 3x more valuable decisions", and only the first half of that is
## a gate. Built without it and soaked blaster-only against the pre-rework build,
## the same run went from 371 kills at 3:00 to 223 with the arena pinned at the
## live-enemy cap — a player with a third of the picks and unchanged cards is
## simply a third as strong. The unique Epic and Legendary effects are untouched:
## they were already build-defining, which is exactly what a scarce pick should
## feel like.

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
		["swift_boots", "Swift Boots", "+14% move speed", eff.MOVE_SPEED, 0.14, 5, 1.0, C],
		["sharp_shots", "Sharp Shots", "+3 damage", eff.DAMAGE, 3.0, 5, 1.0, C],
		["rapid_fire", "Rapid Fire", "15% faster firing", eff.FIRE_RATE, 0.15, 5, 1.0, C],
		# The whole magnet axis, merged into this one card (M7.3). There used to be
		# three: `magnetism` at Common (0/12 taken), `lodestone` at Uncommon
		# (0/16), and `greed`, which grants a full gem magnet as a side effect of
		# an Epic XP card. Two of them were pure noise occupying slots in a pool
		# that now offers 25 screens instead of 78. `greed` keeps its magnet —
		# that is a different card doing a different job.
		["magnetism", "Magnetism", "+45px pickup range", eff.MAGNET, 45.0, 3, 0.7, C],
		["scholar", "Scholar", "+12% XP gained", eff.XP_GAIN, 0.12, 4, 0.8, C],
		["tough_hide", "Tough Hide", "+2 max HP", eff.MAX_HP, 2.0, 5, 0.8, C],
		["velocity", "Velocity", "+25% projectile speed", eff.PROJECTILE_SPEED, 0.25, 4, 0.7, C],
		# Unlimited: the floor that guarantees the pool can always offer something.
		["overdrive", "Overdrive", "+2 damage", eff.DAMAGE, 2.0, 0, 0.5, C],

		# ---- UNCOMMON -------------------------------------------------------
		["momentum", "Momentum", "+22% move speed", eff.MOVE_SPEED, 0.22, 4, 1.0, U],
		["honed_edge", "Honed Edge", "+6 damage", eff.DAMAGE, 6.0, 4, 1.0, U],
		["cadence", "Cadence", "25% faster firing", eff.FIRE_RATE, 0.25, 4, 1.0, U],
		["siphon", "Siphon", "14% chance to recover 1 HP per kill", eff.LIFESTEAL, 0.14, 4, 0.9, U],
		["carapace", "Carapace", "+4 max HP", eff.MAX_HP, 4.0, 4, 0.8, U],
		# A projectile source at Uncommon too: multishot is a signature mechanic and
		# must not be something a player can finish a run without ever seeing.
		# The old text promised "-20% damage" that NOTHING ever applied — the effect
		# only ever added a projectile. The cost is real now and lives in
		# Stats.volley_damage_mult, so it is charged once, globally, and no future
		# projectile source can forget to pay it. Cards state the rule; the pause
		# stats tab shows the player's current number.
		["scatter", "Scatter", "+1 projectile · wider volleys hit softer", eff.PROJECTILE_COUNT, 1.0, 2, 1.2, U],
		["relentless", "Relentless", "+10% move speed", eff.MOVE_SPEED, 0.10, 0, 0.4, U],

		# ---- RARE -----------------------------------------------------------
		["cannonball", "Cannonball", "+12 damage", eff.DAMAGE, 12.0, 3, 1.0, R],
		# Weight was 2.2 — the highest in the entire pool, more than double anything
		# else — so the draw actively steered every run onto the most multiplicative
		# axis in the game. Telemetry: split_shot x3 in a 44-pick run.
		["split_shot", "Split Shot", "+1 projectile · wider volleys hit softer", eff.PROJECTILE_COUNT, 1.0, 3, 1.0, R],
		["pierce", "Piercing Rounds", "Shots punch through +2 enemies", eff.PIERCE, 2.0, 3, 1.0, R],
		["focus", "Focus", "+18% critical chance (2.5x damage)", eff.CRIT_CHANCE, 0.18, 5, 1.0, R],
		["fusillade", "Fusillade", "40% faster firing", eff.FIRE_RATE, 0.40, 2, 0.9, R],
		["reservoir", "Reservoir", "+7 max HP", eff.MAX_HP, 7.0, 2, 0.7, R],

		# ---- EPIC · semi-unique, changes HOW a weapon behaves ----------------
		["ricochet", "Ricochet", "Shots bounce to 2 more targets", eff.RICOCHET, 2.0, 2, 1.0, E],
		["cryo_rounds", "Cryo Rounds", "Hits slow enemies by 40%", eff.CRYO, 0.40, 2, 1.0, E],
		["executioner", "Executioner", "Enemies below 15% HP die instantly", eff.EXECUTE, 0.15, 2, 1.0, E],
		["greed", "Greed", "+50% XP, and gems come to you", eff.GREED, 0.50, 2, 0.9, E],
		["aegis", "Aegis", "A free 2s shield every 20s", eff.AEGIS, 20.0, 2, 0.9, E],

		# ---- LEGENDARY · unique, run-defining --------------------------------
		["prism_core", "Prism Core", "Shots split into a fan on impact", eff.PRISM_CORE, 3.0, 1, 1.0, L],
		["event_horizon", "Event Horizon", "Kills implode, dragging in and hurting neighbours", eff.EVENT_HORIZON, 70.0, 1, 1.0, L],
		["overclock", "Overclock", "Every 8th shot is a piercing mega-bolt", eff.OVERCLOCK, 8.0, 1, 1.0, L],
		["second_wind", "Second Wind", "Survive one lethal hit and blast the screen clear", eff.SECOND_WIND, 1.0, 1, 1.0, L],
		["chain_lightning", "Chain Lightning", "Shots arc to 3 nearby enemies", eff.CHAIN, 3.0, 1, 1.0, L],
		["barrage", "Barrage", "+2 projectiles · wider volleys hit softer", eff.PROJECTILE_COUNT, 2.0, 1, 1.0, E],

		# ---- BLASTER · always in the pool, it is the weapon you start with ----
		["twin_fangs", "Twin Fangs", "The blaster fires a second volley an instant later", eff.TWIN_FANGS, 1.0, 1, 1.0, L],
	]
	_write(defs, &"")

	# ---- WEAPON DRAFTS ------------------------------------------------------
	# M7.3: weapons are DRAFTED, not owned. Beating the Prism no longer hands you
	# the orbital at spawn — it puts this card into the pool, for this run and
	# every future one. A stranger's first run is blaster-only to 5:00, and the
	# orbital becomes something they can be dealt in the back half.
	#
	# RARE, not Epic. A weapon is exactly what "build-shaping" means, and at ~25
	# card screens a run an Epic-tier weapon card would simply fail to appear in
	# most runs — an unlock the player cannot act on is the same as no unlock.
	# Weight 2.0 so it dominates its tier until taken; max_stacks 1 removes it.
	_write([["draft_orbital", "Orbitals", "Shards orbit you, damaging what they touch",
			eff.GRANT_WEAPON, 0.0, 1, 2.0, R]], MetaState.UNLOCK_ORBITAL, &"orbital")
	_write([["draft_scattergun", "Scattergun", "A five-pellet cone at close range",
			eff.GRANT_WEAPON, 0.0, 1, 2.0, R]], MetaState.UNLOCK_ELITE_HUNTER, &"scattergun")
	_write([["draft_lance", "Prism Lance", "An instant beam through everything in line",
			eff.GRANT_WEAPON, 0.0, 1, 2.0, R]], MetaState.UNLOCK_ENDLESS_PROVEN, &"lance")

	# ---- WEAPON BRANCHES ----------------------------------------------------
	# Gated on having DRAFTED the weapon this run, not on the meta unlock. These
	# used to gate on the unlock, which meant a veteran saw orbital cards in
	# every run whether or not the orbital was in it.
	#
	# The radius card is gone: 0 picks in 11 offers. Radius folds into Split
	# Orbit, so the ring grows as it fills instead of asking the player to buy
	# the two halves of one idea separately.
	_write([
		["orbit_count", "Split Orbit", "+1 orbiting shard, and a wider ring", eff.ORBITAL_COUNT, 1.0, 4, 1.1, R],
		["orbit_speed", "Spin Up", "+35% orbit speed and hit rate", eff.ORBITAL_SPEED, 0.35, 3, 0.9, R],
		["nova_orbit", "Nova Orbit", "Orbitals detonate on kill", eff.NOVA_ORBIT, 60.0, 1, 1.0, E],
		["singularity", "Singularity", "The ring drags nearby enemies into itself", eff.SINGULARITY, 108.0, 1, 1.0, L],
	], UpgradeResource.weapon_gate(&"orbital"))

	_write([
		["flechette_storm", "Flechette Storm", "The scattergun fires a full ring instead of a cone",
				eff.FLECHETTE_STORM, 1.0, 1, 1.0, L],
	], UpgradeResource.weapon_gate(&"scattergun"))

	_write([
		["refraction", "Refraction", "The lance splits into three beams", eff.REFRACTION, 2.0, 1, 1.0, L],
	], UpgradeResource.weapon_gate(&"lance"))

	# ---- SHOP CARDS ---------------------------------------------------------
	# Bought in the meta skill tree, and absent from the pool entirely until then.
	# Gated on the NODE's id: the same `requires_unlock` field, the same array,
	# the same question the pool has always asked. A purchase buys the chance to
	# be dealt these, never the effect itself — which is what keeps the tree from
	# handing a returning player power a stranger cannot reach.
	_write([["shop_coils", "Overload Coils", "35% faster firing",
			eff.FIRE_RATE, 0.35, 2, 1.0, R]], &"node_card_coils")
	_write([["shop_hollow", "Hollow Point", "Enemies below 22% HP die instantly",
			eff.EXECUTE, 0.22, 1, 1.0, E]], &"node_card_hollow")
	_write([["shop_mirror", "Mirror Shards", "Shots split into five on impact",
			eff.PRISM_CORE, 5.0, 1, 1.0, L]], &"node_card_mirror")

	_write_manifest()
	_prune_orphans()
	print("gen_upgrades: %d upgrades + manifest" % _written.size())
	quit(0)


## Deletes any .tres in the output directory this run did NOT write. Three
## orphaned upgrades were found in two days by hand (hub/knowledge/content-drift)
## — a retired card kept being offered 62 times because removing its definition
## left its file on disk. The generator owns the directory, so it owns the
## deletions too.
func _prune_orphans() -> void:
	var dir: DirAccess = DirAccess.open(OUT)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		if _written.has(file_name.get_basename()):
			continue
		if dir.remove(file_name) == OK:
			print("gen_upgrades: pruned orphan %s" % file_name)


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


func _write(defs: Array, requires: StringName, grants: StringName = &"") -> void:
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
		u.weapon_id = grants
		var path: String = "%s/%s.tres" % [OUT, u.id]
		u.resource_path = path
		if ResourceSaver.save(u, path) != OK:
			push_error("gen_upgrades: FAILED %s" % path)
			continue
		_written.append(String(u.id))
