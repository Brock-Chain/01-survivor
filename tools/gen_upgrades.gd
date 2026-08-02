extends SceneTree
## Authors the NEW upgrade .tres files (playtest response, 2026-08-02).
##
##   <console.exe> --headless --path . -s res://tools/gen_upgrades.gd
##
## Three problems this fixes, all from one playtest:
##   1. "Healing shouldn't be a level reward" — Bandage is gone from the pool.
##      Health is a world drop now, plus Siphon for players who want to build
##      into it. A heal offered at full HP is a wasted pick.
##   2. The pool ran DRY: 10 upgrades x 5 stacks, so by level 37 everything was
##      maxed and the only legal draw was the heal. The three "endless" upgrades
##      below have max_stacks = 0 (unlimited), so there is always something.
##   3. "We need funkier upgrades" — every existing one was a flat stat bump.
##      Pierce, Focus and Siphon change how the weapon behaves, not just by how
##      much.

const OUT: String = "res://resources/upgrades"


func _init() -> void:
	# id, name, description, effect, magnitude, max_stacks, weight
	var defs: Array = [
		# --- funkier: these change behaviour, not just numbers ---
		["pierce", "Piercing Rounds", "Shots punch through +1 enemy",
			UpgradeResource.Effect.PIERCE, 1.0, 3, 1.0],
		["focus", "Focus", "+8% critical chance (2.5x damage)",
			UpgradeResource.Effect.CRIT_CHANCE, 0.08, 6, 1.0],
		["siphon", "Siphon", "5% chance to recover 1 HP per kill",
			UpgradeResource.Effect.LIFESTEAL, 0.05, 5, 0.9],
		# --- endless: unlimited stacks so late levels always have an offer ---
		["overdrive", "Overdrive", "+1 damage",
			UpgradeResource.Effect.DAMAGE, 1.0, 0, 0.35],
		["momentum", "Momentum", "+7% move speed",
			UpgradeResource.Effect.MOVE_SPEED, 0.07, 0, 0.3],
		["cadence", "Cadence", "5% faster firing",
			UpgradeResource.Effect.FIRE_RATE, 0.05, 0, 0.3],
	]

	for d: Array in defs:
		pass
	_write(defs, &"")
	# Orbital upgrades exist only for players who have beaten the Prism, so they
	# never clutter the offers of someone who has not unlocked the weapon.
	_write([
		["orbit_count", "Split Orbit", "+1 orbiting shard",
			UpgradeResource.Effect.ORBITAL_COUNT, 1.0, 4, 1.1],
		["orbit_radius", "Wide Orbit", "+10px orbit radius",
			UpgradeResource.Effect.ORBITAL_RADIUS, 10.0, 4, 0.8],
		["orbit_speed", "Spin Up", "+18% orbit speed",
			UpgradeResource.Effect.ORBITAL_SPEED, 0.18, 4, 0.8],
	], MetaState.UNLOCK_ORBITAL)
	print("gen_upgrades: done")
	quit(0)


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
		u.requires_unlock = requires
		var path: String = "%s/%s.tres" % [OUT, u.id]
		u.resource_path = path
		var err: int = ResourceSaver.save(u, path)
		print("  %s %s" % ["ok  " if err == OK else "FAIL", path])
