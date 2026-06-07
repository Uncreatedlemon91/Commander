extends Node2D

# A musket-smoke puff: fades in fast, expands, drifts, and lingers for several
# seconds before dissipating. Many overlapping puffs build into a smoke bank.

var age: float = 0.0
var vel: Vector2 = Vector2.ZERO
var max_radius: float = 18.0

const LIFETIME := 6.0
const PEAK_ALPHA := 0.38

func _ready() -> void:
	# Slow drift (slight upward/wind bias) so the bank rolls instead of sitting.
	vel = Vector2(randf_range(-5.0, 5.0), randf_range(-9.0, -2.0))
	max_radius = randf_range(14.0, 26.0)

func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	position += vel * delta
	queue_redraw()

func _draw() -> void:
	var t := age / LIFETIME
	var alpha: float
	if t < 0.12:
		alpha = (t / 0.12) * PEAK_ALPHA          # fast fade-in
	else:
		alpha = (1.0 - (t - 0.12) / 0.88) * PEAK_ALPHA   # slow fade-out
	var r: float = lerp(5.0, max_radius, t)
	var shade := 0.85
	draw_circle(Vector2.ZERO, r, Color(shade, shade, shade, alpha))
