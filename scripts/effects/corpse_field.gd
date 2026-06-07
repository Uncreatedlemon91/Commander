extends Node2D

# Persistent layer of fallen soldiers. Bodies are never removed. One node draws
# them all and only redraws when a body is added. Drawn beneath the troops and
# only slightly transparent so they read clearly but still show terrain later.

var corpses: Array = []   # each: { "pos": Vector2, "color": Color }

const RADIUS := 3.2

func add_corpse(pos: Vector2, color: Color) -> void:
	corpses.append({ "pos": pos, "color": color })
	queue_redraw()

func _draw() -> void:
	for c in corpses:
		var p: Vector2 = c["pos"]
		var col: Color = c["color"]
		draw_circle(p, RADIUS, col)
		# faint dark outline for contrast against grass/dirt
		draw_arc(p, RADIUS, 0, TAU, 10, Color(0, 0, 0, col.a * 0.6), 0.6)
