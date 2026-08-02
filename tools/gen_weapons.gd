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
	print("gen_weapons: 2 weapons")
	quit(0)


func _save(res: Resource, path: String) -> void:
	res.resource_path = path
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		push_error("gen_weapons: save failed %s (%d)" % [path, err])
