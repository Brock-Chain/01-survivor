extends SceneTree
## Authors the weapon .tres files.
##   <console.exe> --headless --path . -s res://tools/gen_weapons.gd


func _init() -> void:
	var orbital := WeaponResource.new()
	orbital.id = &"orbital"
	orbital.display_name = "Orbitals"
	orbital.kind = WeaponResource.Kind.ORBITAL
	orbital.requires_unlock = MetaState.UNLOCK_ORBITAL
	orbital.damage = 2
	orbital.interval = 0.4   # per-enemy hit cooldown
	orbital.count = 2
	orbital.orbit_radius = 48.0
	orbital.orbit_speed = 2.6
	_save(orbital, "res://resources/weapons/orbital.tres")

	var blaster := WeaponResource.new()
	blaster.id = &"blaster"
	blaster.display_name = "Blaster"
	blaster.kind = WeaponResource.Kind.PROJECTILE
	blaster.damage = 1
	blaster.interval = 0.8
	blaster.count = 1
	blaster.range = 260.0
	blaster.projectile_speed = 340.0
	_save(blaster, "res://resources/weapons/blaster.tres")

	# Five pellets in a wide cone, short range: the blaster from across the
	# screen, the scattergun only up close — proximity is the price of burst.
	var scatter := WeaponResource.new()
	scatter.id = &"scattergun"
	scatter.display_name = "Scattergun"
	scatter.kind = WeaponResource.Kind.PROJECTILE
	scatter.requires_unlock = MetaState.UNLOCK_ELITE_HUNTER
	scatter.fire_sound = &"blast"
	scatter.damage = 2
	scatter.interval = 1.5
	scatter.count = 5
	scatter.range = 170.0
	scatter.projectile_speed = 300.0
	scatter.spread_deg = 12.0
	_save(scatter, "res://resources/weapons/scattergun.tres")

	# Instant piercing line. Slow, heavy, rewards lining enemies up.
	var lance := WeaponResource.new()
	lance.id = &"lance"
	lance.display_name = "Prism Lance"
	lance.kind = WeaponResource.Kind.BEAM
	lance.requires_unlock = MetaState.UNLOCK_ENDLESS_PROVEN
	lance.fire_sound = &"lance"
	lance.damage = 3
	lance.interval = 2.4
	lance.count = 1
	lance.range = 320.0
	_save(lance, "res://resources/weapons/lance.tres")
	print("gen_weapons: 4 weapons")
	quit(0)


func _save(res: Resource, path: String) -> void:
	res.resource_path = path
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		push_error("gen_weapons: save failed %s (%d)" % [path, err])
