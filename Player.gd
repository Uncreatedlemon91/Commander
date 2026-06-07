extends CharacterBody2D

# The commander avatar. Drive it with WASD. Orders are issued from wherever
# the commander is standing (couriers spawn at this position).

# Mounted commander pace — only a touch quicker than marching infantry (~12),
# so you can't outrun the simulation. This is a sim, not a twitch RTS.
const MAX_SPEED = 18.0
const ACCELERATION = 90.0
const FRICTION = 120.0
const SIZE = 9.0

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("left", "right", "up", "down")

	if direction:
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
		rotation = atan2(direction.x, -direction.y)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move_and_slide()
	queue_redraw()

func _draw() -> void:
	# A gold diamond so the commander stands out from the troop circles.
	var pts := PackedVector2Array([
		Vector2(0, -SIZE),
		Vector2(SIZE * 0.7, 0),
		Vector2(0, SIZE),
		Vector2(-SIZE * 0.7, 0),
	])
	draw_colored_polygon(pts, Color(1.0, 0.84, 0.0))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color.BLACK, 1.5)
