extends Node2D
class_name Courier

# Rides from where it spawned (the commander) to a target battalion, then
# delivers its order and disappears.

var target_battalion: Battalion
var order: Dictionary = {}

# Couriers are mounted ADCs — a bit quicker than the commander, but order delay
# is now genuinely felt at simulator pace.
const SPEED := 26.0
const ARRIVE_DIST := 8.0

func _process(delta: float) -> void:
	if not is_instance_valid(target_battalion):
		queue_free()
		return

	var dest := target_battalion.global_position
	var dir := (dest - global_position)
	if dir.length() > 0.01:
		rotation = atan2(dir.x, -dir.y)   # point the triangle toward the target

	global_position = global_position.move_toward(dest, SPEED * delta)

	if global_position.distance_to(dest) < ARRIVE_DIST:
		target_battalion.receive_order(order)
		queue_free()

	queue_redraw()

func _draw() -> void:
	var s := 6.0
	var pts := PackedVector2Array([
		Vector2(0, -s),
		Vector2(s * 0.7, s),
		Vector2(-s * 0.7, s),
	])
	draw_colored_polygon(pts, Color(1.0, 0.85, 0.2))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color.BLACK, 1.0)
