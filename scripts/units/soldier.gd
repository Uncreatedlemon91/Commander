extends Node2D
class_name Soldier

# A VISUAL soldier. These only exist while the battalion is on-screen — the
# battalion's strength is tracked as a number, and these shapes are spawned to
# represent it when near the camera. Shape depends on the unit type.

enum Role { LINE, OFFICER, FLAG, MUSICIAN }
enum State { IDLE, MOVING }

var battalion: Battalion
var role: Role = Role.LINE
var unit_type: String = "infantry"
var formation_offset: Vector2 = Vector2.ZERO
var jitter: Vector2 = Vector2.ZERO
var team_color: Color = Color.WHITE
var move_speed: float = 18.0
var is_skirmisher: bool = false

var state: State = State.IDLE
var flash_timer: float = 0.0
var melee_offset: Vector2 = Vector2.ZERO
var melee_jitter_cd: float = 0.0

const SIZE := 2.4
const ARRIVE := 0.8

func _ready() -> void:
	top_level = true

func _process(delta: float) -> void:
	if not is_instance_valid(battalion):
		return
	if flash_timer > 0.0:
		flash_timer -= delta

	var target := battalion.global_position + formation_offset + jitter

	if battalion.in_melee and not is_skirmisher:
		melee_jitter_cd -= delta
		if melee_jitter_cd <= 0.0:
			melee_jitter_cd = randf_range(0.25, 0.6)
			melee_offset = battalion.facing_dir * randf_range(8.0, 40.0) \
				+ Vector2(randf_range(-16, 16), randf_range(-16, 16))
		target += melee_offset
	else:
		melee_offset = Vector2.ZERO

	var spd := move_speed
	if battalion.in_melee:
		spd *= 1.8
	if global_position.distance_to(target) > ARRIVE:
		global_position = global_position.move_toward(target, spd * delta)
		state = State.MOVING
	else:
		state = State.IDLE

	queue_redraw()

func fire_flash() -> void:
	flash_timer = 0.12

func _draw() -> void:
	var routing := is_instance_valid(battalion) and battalion.is_routing()
	var base := team_color
	if routing:
		base = Color(0.55, 0.55, 0.55)
	elif state == State.MOVING:
		base = team_color.lightened(0.20)

	match role:
		Role.OFFICER:
			draw_circle(Vector2.ZERO, SIZE + 1.6, Color(1.0, 0.84, 0.0))
			draw_arc(Vector2.ZERO, SIZE + 1.6, 0, TAU, 14, Color.BLACK, 0.8)
		Role.FLAG:
			_draw_body(base)
			draw_line(Vector2.ZERO, Vector2(0, -13), Color(0.25, 0.18, 0.1), 1.2)
			var flag := PackedVector2Array([
				Vector2(0, -13), Vector2(9, -11.5), Vector2(9, -7), Vector2(0, -8.5)
			])
			draw_colored_polygon(flag, team_color)
			draw_polyline(flag, Color.BLACK, 0.8)
		Role.MUSICIAN:
			_draw_body(base)
			draw_circle(Vector2.ZERO, SIZE * 0.45, Color.WHITE)
		_:
			_draw_body(base)

	if is_skirmisher:
		draw_arc(Vector2.ZERO, SIZE + 1.8, 0, TAU, 12, Color.WHITE, 0.8)

	if flash_timer > 0.0:
		var f := battalion.facing_dir if is_instance_valid(battalion) else Vector2(0, -1)
		draw_circle(f * (SIZE + 2.5), 1.8, Color(1.0, 0.9, 0.4))

func _draw_body(base: Color) -> void:
	match unit_type:
		"cavalry":
			var s := SIZE * 2.0
			var rot := (battalion.facing_dir.angle() + PI * 0.5) if is_instance_valid(battalion) else 0.0
			var pts := PackedVector2Array([
				Vector2(0, -s).rotated(rot),
				Vector2(s * 0.7, s * 0.7).rotated(rot),
				Vector2(-s * 0.7, s * 0.7).rotated(rot),
			])
			draw_colored_polygon(pts, base)
		"artillery":
			var sq := SIZE * 1.7
			draw_rect(Rect2(-sq * 0.5, -sq * 0.5, sq, sq), base)
		_:
			draw_circle(Vector2.ZERO, SIZE, base)
