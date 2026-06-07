extends Node2D
class_name Terrain

# Static terrain for the Battle of Ulm (stylised). Drawn once, beneath everything.
# Provides gameplay queries: movement cost, cover, and elevation.
#
# Geography (north is -Y):
#   - The Danube runs east-west across the south.
#   - The town of Ulm sits on the north bank.
#   - The Michelsberg heights rise north of the town (the key ground Napoleon
#     seized to cut the Austrians off).
#   - Scattered woods.

var hills: Array = [
	{ "c": Vector2(0, -190), "r": 300.0 },     # Michelsberg
	{ "c": Vector2(-430, -300), "r": 150.0 },
]
var woods: Array = [
	{ "c": Vector2(-470, 60), "r": 110.0 },
	{ "c": Vector2(410, -120), "r": 130.0 },
	{ "c": Vector2(150, 60), "r": 80.0 },
]
var town_rects: Array = [
	Rect2(-110, 250, 220, 70),                 # Ulm
]
var water_rect := Rect2(-1200, 330, 2400, 90) # the Danube

const GRASS := Color(0.30, 0.40, 0.22)
const HILL := Color(0.40, 0.45, 0.26)
const WOOD := Color(0.16, 0.28, 0.15)
const WATER := Color(0.24, 0.34, 0.55)
const ROAD := Color(0.52, 0.46, 0.34)
const BUILDING := Color(0.42, 0.40, 0.40)

# ---------------------------------------------------------------- queries

func terrain_type_at(pos: Vector2) -> String:
	for r in town_rects:
		if (r as Rect2).has_point(pos):
			return "town"
	if water_rect.has_point(pos):
		return "water"
	for w in woods:
		if pos.distance_to(w["c"]) < w["r"]:
			return "woods"
	for h in hills:
		if pos.distance_to(h["c"]) < h["r"]:
			return "hill"
	return "field"

func movement_factor(pos: Vector2) -> float:
	match terrain_type_at(pos):
		"water": return 0.35
		"woods": return 0.6
		"town": return 0.75
		"hill": return 0.9
	return 1.0

func cover_factor(pos: Vector2) -> float:
	# multiplier on casualties TAKEN here (lower = safer)
	match terrain_type_at(pos):
		"woods": return 0.5
		"town": return 0.45
	return 1.0

func elevation_at(pos: Vector2) -> float:
	var best := 0.0
	for h in hills:
		var d: float = pos.distance_to(h["c"])
		if d < h["r"]:
			best = max(best, 1.0 - d / h["r"])
	return best

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(-2000, -2000, 4000, 4000), GRASS)

	# hills (concentric shading for elevation)
	for h in hills:
		var c: Vector2 = h["c"]
		var r: float = h["r"]
		for i in range(4):
			var t := float(i) / 4.0
			draw_circle(c, r * (1.0 - t), HILL.lightened(t * 0.12))

	# woods
	for w in woods:
		draw_circle(w["c"], w["r"], WOOD)

	# Danube
	draw_rect(water_rect, WATER)

	# roads radiating from Ulm
	var hub := Vector2(0, 285)
	for p in [Vector2(-700, -200), Vector2(700, -150), Vector2(0, -400), Vector2(-300, 320)]:
		draw_line(hub, p, ROAD, 5.0)

	# town buildings
	for r in town_rects:
		var rect := r as Rect2
		draw_rect(rect, BUILDING.darkened(0.1))
		var cols := int(rect.size.x / 24.0)
		var rows := int(rect.size.y / 22.0)
		for ix in range(cols):
			for iy in range(rows):
				var bp := rect.position + Vector2(6 + ix * 24, 5 + iy * 22)
				draw_rect(Rect2(bp, Vector2(16, 15)), BUILDING)

	# labels
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-22, 292), "ULM", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.9))
	draw_string(font, Vector2(-60, -190), "Michelsberg", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.85, 0.7))
	draw_string(font, Vector2(-60, 380), "Danube", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.85, 0.95))
