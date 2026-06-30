extends Node3D
# ─────────────────────────────────────────────────────────────────────────────
# SOLDIER / ANIMATION TEST BENCH
# A standalone scene for iterating on the soldier mesh + shader animations WITHOUT booting a
# whole battle. It BORROWS the real _soldier_mesh()/_soldier_shader() from a throwaway game.gd
# instance, so it always renders the exact live assets — no divergence, no risk to the game.
#
# Controls:  [M] toggle march   [P] toggle present   [F] fire (recoil pulse)   [K] kill a man
#            (death collapse)   [H] cycle headgear   [R] reset   [Esc] back to menu
#            drag mouse to orbit · mouse-wheel to zoom
# ─────────────────────────────────────────────────────────────────────────────

const ROWS := 3
const COLS := 7
const N := ROWS * COLS
const SP := 1.4               # spacing between men (metres)
const STAND_Y := 0.85         # the soldier mesh's feet sit ~0.84 below its origin, so stand it here

var _mm: MultiMesh            # the living soldiers (real mesh + shader)
var _fall_mm: MultiMesh       # toppling men — the death-collapse, same capsule the game uses
var _cam: Camera3D
var _ui: Label

var _march := false
var _present := false
var _hat := 0                 # 0 shako · 1 round hat · 2 bicorne
var _fire_pulse := 0.0        # decays after a volley → drives the recoil kick
var _phase := PackedFloat32Array()
var _alive := []
var _falls: Array = []        # { pos, yaw, t }

# free-orbit camera
var _yaw := 0.7
var _pitch := 0.3
var _dist := 6.5
var _focus := Vector3(0, 1.0, 0)
var _dragging := false

func _ready() -> void:
	var g = load("res://scripts/game.gd").new()    # asset source — never added to the tree, so no _ready/sim runs
	var mesh: ArrayMesh = g._soldier_mesh()
	var mat: ShaderMaterial = g._soldier_shader(0)
	g.call_deferred("free")                         # free after the scene-swap settles; the mesh+material are independent Resources

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.60, 0.66, 0.74)
	e.ambient_light_color = Color(0.52, 0.55, 0.60)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.15
	add_child(sun)

	var gp := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(50, 50)
	gp.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.33, 0.41, 0.25)
	gmat.roughness = 1.0
	gp.material_override = gmat
	add_child(gp)

	var mmi := MultiMeshInstance3D.new()
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = mesh
	_mm.instance_count = N
	mmi.multimesh = _mm
	mmi.material_override = mat
	add_child(mmi)

	var fmi := MultiMeshInstance3D.new()
	_fall_mm = MultiMesh.new()
	_fall_mm.transform_format = MultiMesh.TRANSFORM_3D
	var cap := CapsuleMesh.new()
	cap.radius = 0.26
	cap.height = 1.7
	cap.radial_segments = 8
	cap.rings = 3
	_fall_mm.mesh = cap
	_fall_mm.instance_count = N
	fmi.multimesh = _fall_mm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.22, 0.30, 0.66)
	fmat.roughness = 1.0
	fmi.material_override = fmat
	add_child(fmi)

	_phase.resize(N)
	_alive.resize(N)
	for i in range(N):
		_phase[i] = randf()
	_reset()

	_cam = Camera3D.new()
	_cam.fov = 55
	add_child(_cam)
	_update_cam()

	var cl := CanvasLayer.new()
	_ui = Label.new()
	_ui.position = Vector2(16, 12)
	_ui.add_theme_font_size_override("font_size", 15)
	cl.add_child(_ui)
	add_child(cl)
	_refresh_ui()

func _reset() -> void:
	_falls.clear()
	for i in range(N):
		_alive[i] = true
	_place_men()

func _place_men() -> void:
	var ca := _hat_color_a()
	for r in range(ROWS):
		for c in range(COLS):
			var i := r * COLS + c
			if not _alive[i]:
				_mm.set_instance_transform(i, _zero())
				continue
			var x := (float(c) - (COLS - 1) * 0.5) * SP
			var z := (float(r) - (ROWS - 1) * 0.5) * SP
			_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, STAND_Y, z)))
			_mm.set_instance_color(i, Color(0.74, 0.12, 0.12, ca))   # rgb = facings (red), a = packed dress (headgear)
			_set_custom(i, _march, _armp_base())
	for i in range(N):
		_fall_mm.set_instance_transform(i, _zero())

# dress packing the shader decodes: coat + belt*4 + pants*12 + hat*48, as a 0..255 byte / 255.
# coat/belt/pants are 0 here, so only the headgear varies.
func _hat_color_a() -> float:
	return float(_hat * 48) / 255.0

func _armp_base() -> float:
	return 1.0 if _present else 0.0

func _set_custom(i: int, marching: bool, armp: float) -> void:
	_mm.set_instance_custom_data(i, Color(0.95, _phase[i], 1.0 if marching else 0.0, armp))

func _process(delta: float) -> void:
	_fire_pulse = maxf(0.0, _fire_pulse - delta * 2.4)
	for i in range(N):
		if not _alive[i]:
			continue
		var armp := _armp_base()
		if _present and _fire_pulse > 0.02:
			# staggered per-man kick (armp > 1 signals the recoil to the shader)
			armp = 1.0 + _fire_pulse * 0.9 * (0.55 + 0.45 * sin(_phase[i] * 6.2831 + _fire_pulse * 3.0))
		_set_custom(i, _march, armp)
	_update_falls(delta)

func _update_falls(delta: float) -> void:
	var n := 0
	var i := 0
	while i < _falls.size():
		var fa: Dictionary = _falls[i]
		var t := float(fa["t"]) + delta
		if t >= 0.7:
			_falls.remove_at(i)
			continue
		fa["t"] = t
		var prog := clampf(t / 0.7, 0.0, 1.0)
		var fall := prog * prog * (3.0 - 2.0 * prog)
		var basis := Basis(Vector3.UP, float(fa["yaw"])) * Basis(Vector3.RIGHT, fall * PI * 0.5)
		var p: Vector3 = fa["pos"]
		var cy := lerpf(STAND_Y, 0.28, fall)
		_fall_mm.set_instance_transform(n, Transform3D(basis, Vector3(p.x, cy, p.z)))
		n += 1
		i += 1
	for j in range(n, N):
		_fall_mm.set_instance_transform(j, _zero())

func _kill_one() -> void:
	for _try in range(40):
		var i := randi() % N
		if _alive[i]:
			_alive[i] = false
			var p := _mm.get_instance_transform(i).origin
			_mm.set_instance_transform(i, _zero())
			_falls.append({ "pos": Vector3(p.x, 0, p.z), "yaw": randf() * TAU, "t": 0.0 })
			return

func _zero() -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)

func _update_cam() -> void:
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	_cam.position = _focus + dir * _dist
	_cam.look_at(_focus, Vector3.UP)

func _refresh_ui() -> void:
	var hats := ["shako", "round hat", "bicorne"]
	_ui.text = "SOLDIER / ANIMATION TEST BENCH\n" \
		+ "[M] March: %s    [P] Present: %s    [F] Fire (recoil)    [K] Kill (collapse)\n" % \
			["ON" if _march else "off", "ON" if _present else "off"] \
		+ "[H] Headgear: %s    [R] Reset    [Esc] Menu\n" % hats[_hat] \
		+ "drag mouse to orbit · wheel to zoom"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_dist = clampf(_dist - 0.5, 1.5, 22.0); _update_cam()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_dist = clampf(_dist + 0.5, 1.5, 22.0); _update_cam()
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch - event.relative.y * 0.01, -0.25, 1.45)
		_update_cam()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_M:
				_march = not _march; _refresh_ui()
			KEY_P:
				_present = not _present; _refresh_ui()
			KEY_F:
				_fire_pulse = 1.0
			KEY_K:
				_kill_one()
			KEY_H:
				_hat = (_hat + 1) % 3; _place_men(); _refresh_ui()
			KEY_R:
				_reset(); _refresh_ui()
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://menu.tscn")
