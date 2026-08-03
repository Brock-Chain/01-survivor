class_name UpgradeIcon
extends Control
## One card's glyph, drawn rather than imported.
##
## The level-up screen is the centrepiece of the game now — M7.2 cut it from ~78
## screens a run to ~25, so each one carries three times the weight and gets
## looked at three times as hard. It read as "better, still not there": dead space
## in the middle of every card and no iconography at all, so three cards were
## three paragraphs and the player had to READ to tell them apart.
##
## Drawn with `_draw` instead of imported PNGs for three reasons that all hold at
## this size: at 28px an icon is a handful of primitives anyway, it inherits the
## card's rarity hue for free (an imported sprite would need one file per tier),
## and it adds nothing to the export or to `tools/gen_assets.py`'s surface.
##
## The glyph answers "what FAMILY is this?" — offence, rate, breadth, movement,
## survival, greed, weapon — not "which upgrade is this?". Seven shapes a player
## can learn are worth more than forty they cannot.

enum Glyph {
	DAMAGE,     ## a blade chevron
	RATE,       ## stacked speed bars
	SPREAD,     ## a three-shot fan
	MOVE,       ## a motion arrow
	VITALITY,   ## a shield hexagon
	FORTUNE,    ## a gem
	ARC,        ## an orbit ring
	WEAPON,     ## the draft cards: a filled hexagon core with a halo
}

var glyph: Glyph = Glyph.DAMAGE
var hue: Color = Color.WHITE


## Effect -> family. Kept here rather than on UpgradeResource because it is a
## PRESENTATION question: the .tres files stay pure data, exactly like the killer
## names on the game-over screen.
static func glyph_for(effect: UpgradeResource.Effect) -> Glyph:
	var eff := UpgradeResource.Effect
	match effect:
		eff.DAMAGE, eff.CRIT_CHANCE, eff.EXECUTE, eff.OVERCLOCK, eff.TWIN_FANGS:
			return Glyph.DAMAGE
		eff.FIRE_RATE, eff.PROJECTILE_SPEED:
			return Glyph.RATE
		eff.PROJECTILE_COUNT, eff.PIERCE, eff.RICOCHET, eff.CHAIN, eff.PRISM_CORE, \
		eff.FLECHETTE_STORM, eff.REFRACTION:
			return Glyph.SPREAD
		eff.MOVE_SPEED:
			return Glyph.MOVE
		eff.MAX_HP, eff.HEAL, eff.LIFESTEAL, eff.AEGIS, eff.SECOND_WIND, eff.CRYO:
			return Glyph.VITALITY
		eff.XP_GAIN, eff.MAGNET, eff.GREED:
			return Glyph.FORTUNE
		eff.ORBITAL_COUNT, eff.ORBITAL_RADIUS, eff.ORBITAL_SPEED, eff.NOVA_ORBIT, \
		eff.EVENT_HORIZON, eff.SINGULARITY:
			return Glyph.ARC
		eff.GRANT_WEAPON:
			return Glyph.WEAPON
	return Glyph.DAMAGE


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	var bright: Color = hue.lightened(0.45)
	var dim: Color = Color(hue.r, hue.g, hue.b, 0.30)
	match glyph:
		Glyph.DAMAGE:
			_chevron(c, r, bright, 0.0)
			_chevron(c + Vector2(0, r * 0.55), r * 0.7, dim, 0.0)
		Glyph.RATE:
			for i: int in 3:
				var y: float = c.y + (float(i) - 1.0) * r * 0.55
				var w: float = r * (1.0 - absf(float(i) - 1.0) * 0.35)
				draw_line(Vector2(c.x - w, y), Vector2(c.x + w, y), bright, 2.0)
		Glyph.SPREAD:
			for i: int in 3:
				var a: float = -PI * 0.5 + (float(i) - 1.0) * 0.5
				draw_line(c + Vector2.RIGHT.rotated(a) * r * 0.25,
						c + Vector2.RIGHT.rotated(a) * r, bright, 2.0)
			draw_circle(c, r * 0.22, bright)
		Glyph.MOVE:
			_chevron(c + Vector2(r * 0.35, 0), r * 0.85, bright, PI * 0.5)
			_chevron(c + Vector2(-r * 0.35, 0), r * 0.7, dim, PI * 0.5)
		Glyph.VITALITY:
			_poly(c, r, 6, bright, 2.0)
			_poly(c, r * 0.45, 6, bright, 0.0)
		Glyph.FORTUNE:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.72, 0),
				c + Vector2(0, r), c + Vector2(-r * 0.72, 0)]), bright)
		Glyph.ARC:
			draw_arc(c, r * 0.8, 0.0, TAU, 24, bright, 2.0)
			draw_circle(c + Vector2.RIGHT.rotated(-0.9) * r * 0.8, r * 0.22, bright)
			draw_circle(c, r * 0.2, dim)
		Glyph.WEAPON:
			# A weapon is not a stat bump, and the icon says so before the badge
			# does: a solid core inside a halo, the only filled hexagon in the set.
			_poly(c, r, 6, dim, 0.0)
			_poly(c, r * 0.62, 6, bright, 0.0)


func _chevron(at: Vector2, radius: float, color: Color, rotation_rad: float) -> void:
	var tip: Vector2 = at + Vector2(0, -radius).rotated(rotation_rad)
	var left: Vector2 = at + Vector2(-radius * 0.8, radius * 0.35).rotated(rotation_rad)
	var right: Vector2 = at + Vector2(radius * 0.8, radius * 0.35).rotated(rotation_rad)
	draw_line(left, tip, color, 2.0)
	draw_line(tip, right, color, 2.0)


## Filled at width 0, outlined otherwise — the same call shape either way so the
## glyph table above stays readable.
func _poly(at: Vector2, radius: float, sides: int, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in sides:
		points.append(at + Vector2.UP.rotated(TAU * float(i) / float(sides)) * radius)
	if width <= 0.0:
		draw_colored_polygon(points, color)
		return
	points.append(points[0])
	draw_polyline(points, color, width)
