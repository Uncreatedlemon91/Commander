extends Node2D
class_name SmokeField

# All musket smoke in one node. Each shot adds a puff; the field ages, drifts and
# draws them. Far cheaper than thousands of individual smoke nodes, which matters
# now that every soldier emits smoke when firing.

var puffs: Array = []   # each: { pos, vel, age, maxr }

const LIFETIME := 8.0
const PEAK_ALPHA := 0.30
const MAX_PUFFS := 2600   # ring-buffer cap; oldest drop first

func add(pos: Vector2) -> void:
	if puffs.size() >= MAX_PUFFS:
		puffs.pop_front()
	puffs.append({
		"pos": pos,
		"vel": Vector2(randf_range(-4.0, 4.0), randf_range(-7.0, -1.0)),
		"age": 0.0,
		"maxr": randf_range(6.0, 15.0),
	})

func _process(delta: float) -> void:
	if puffs.is_empty():
		return
	var i := 0
	while i < puffs.size():
		var p = puffs[i]
		p["age"] += delta
		if p["age"] >= LIFETIME:
			puffs.remove_at(i)
		else:
			p["pos"] += p["vel"] * delta
			i += 1
	queue_redraw()

func _draw() -> void:
	for p in puffs:
		var t: float = p["age"] / LIFETIME
		var alpha: float
		if t < 0.1:
			alpha = (t / 0.1) * PEAK_ALPHA
		else:
			alpha = (1.0 - (t - 0.1) / 0.9) * PEAK_ALPHA
		var r: float = lerp(3.0, p["maxr"], t)
		draw_circle(p["pos"], r, Color(0.85, 0.85, 0.85, alpha))
