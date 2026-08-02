extends SceneTree
## Authors the power-up .tres files.
##   <console.exe> --headless --path . -s res://tools/gen_powerups.gd
##
## Loading a Texture2D here is safe — unlike a PackedScene it drags in no
## scripts, so this tool never touches the gameplay autoloads.

const OUT: String = "res://resources/powerups"


func _init() -> void:
	# id, name, kind, duration, sprite, weight
	var defs: Array = [
		["shield", "Shield", PowerUpResource.Kind.SHIELD, 6.0, "pu_shield", 1.0],
		["power", "Overcharge", PowerUpResource.Kind.POWER, 8.0, "pu_power", 1.0],
		["haste", "Haste", PowerUpResource.Kind.HASTE, 8.0, "pu_haste", 1.0],
		["collect", "Collect", PowerUpResource.Kind.COLLECT, 0.0, "pu_collect", 0.8],
	]
	for d: Array in defs:
		var p := PowerUpResource.new()
		p.id = StringName(d[0])
		p.display_name = d[1]
		p.kind = d[2]
		p.duration = d[3]
		p.sprite = load("res://assets/sprites/%s.png" % d[4])
		p.weight = d[5]
		p.tint = Color(0.55, 1.0, 0.95)
		var path: String = "%s/%s.tres" % [OUT, p.id]
		p.resource_path = path
		var err: int = ResourceSaver.save(p, path)
		print("  %s %s" % ["ok  " if err == OK else "FAIL", path])
	print("gen_powerups: %d" % defs.size())
	quit(0)
