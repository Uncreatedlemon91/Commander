extends Node3D

# 3D FEASIBILITY SPIKE — throwaway, standalone. Renders many battalions of capsule
# "soldiers" in formation using the same formation-slot + eased-animation logic the
# 2D game uses, but via MultiMeshInstance3D (one draw call per team). Two lines
# advance, fight, shed casualties (which drop as lying bodies), and reinforce, so it
# runs forever as a feel + framerate test.
#
# Controls:  WASD pan · Q/E rotate · scroll zoom · [1] toggle shadows
#            [2] add battalions · [3] toggle line/column

const SP := 0.85                 # spacing between men (metres)
const CAP_RADIUS := 0.22
const CAP_HEIGHT := 1.15
const CAP_HALF := CAP_HEIGHT * 0.5
const MEN_PER_FIG := 4
const FIG_LERP := 5.0
const SPEED := 6.0               # battalion march speed (m/s)
const CONTACT := 26.0            # range at which lines start taking casualties
const MAX_PER_TEAM := 5000       # preallocated capsule instances per team
const CORPSE_MAX := 9000
const FIELD := 70.0              # half-width of the deployment line

var ZERO_XF := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)

class Batt:
	var team: int
	var pos: Vector3
	var facing: float = 0.0
	var vis: float = 0.0
	var formation: String = "line"
	var figs: Array = []          # each: { p: Vector2, slot: Vector2, ph: float }
	var fire_cd: float = 0.0
	var spawn: Vector3

var battalions: Array[Batt] = []
var team_mm: Array = [null, null]
var team_prev: Array[int] = [0, 0]
var corpse_mm: MultiMesh
var corpse_idx: int = 0
var corpse_count: int = 0

var cam: Camera3D
var sun: DirectionalLight3D
var hud: Label
var _t: float = 0.0

var smoke_p: GPUParticles3D
var flash_p: GPUParticles3D
const EMIT_FLAGS := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR

# camera orbit rig
var _cam_target := Vector3.ZERO
var _cam_dist := 95.0
var _cam_yaw := 0.0
var _cam_pitch := deg_to_rad(52.0)

func _ready() -> void:
	_build_world()
	for team in [0, 1]:
		for i in range(12):
			_spawn_battalion(team, i, 12)
	_rebuild_corpse_mm()

# ------------------------------------------------------------------ world setup

func _build_world() -> void:
	# environment: sky, ACES tonemap, glow, soft fog for depth
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_horizon_color = Color(0.7, 0.72, 0.78)
	psm.ground_horizon_color = Color(0.6, 0.6, 0.62)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_density = 0.0012
	env.fog_light_color = Color(0.75, 0.78, 0.82)
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	# ground
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 500)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.34, 0.40, 0.26)
	gmat.roughness = 1.0
	ground.material_override = gmat
	add_child(ground)

	# soldier MultiMeshes, one per team (one draw call each)
	for team in [0, 1]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var cap := CapsuleMesh.new()
		cap.radius = CAP_RADIUS
		cap.height = CAP_HEIGHT
		mm.mesh = cap
		mm.instance_count = MAX_PER_TEAM
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.30, 0.38, 0.78) if team == 0 else Color(0.74, 0.30, 0.30)
		mat.roughness = 0.85
		mmi.material_override = mat
		add_child(mmi)
		team_mm[team] = mm
		for i in range(MAX_PER_TEAM):
			mm.set_instance_transform(i, ZERO_XF)

	# corpse MultiMesh (lying capsules)
	var cmi := MultiMeshInstance3D.new()
	corpse_mm = MultiMesh.new()
	corpse_mm.transform_format = MultiMesh.TRANSFORM_3D
	var ccap := CapsuleMesh.new()
	ccap.radius = CAP_RADIUS
	ccap.height = CAP_HEIGHT
	corpse_mm.mesh = ccap
	corpse_mm.instance_count = CORPSE_MAX
	cmi.multimesh = corpse_mm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.26, 0.24, 0.22)
	cmat.roughness = 1.0
	cmi.material_override = cmat
	add_child(cmi)
	for i in range(CORPSE_MAX):
		corpse_mm.set_instance_transform(i, ZERO_XF)

	# musket smoke + muzzle flash (world-space pooled emitters, fired on demand)
	smoke_p = _make_emitter(5.5, 5000, _smoke_material(), Vector2(1.4, 1.4))
	flash_p = _make_emitter(0.14, 2500, _flash_material(), Vector2(0.7, 0.7))
	add_child(smoke_p)
	add_child(flash_p)

	cam = Camera3D.new()
	cam.fov = 55.0
	cam.current = true
	add_child(cam)
	_update_cam()

	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Label.new()
	hud.position = Vector2(12, 10)
	hud.add_theme_font_size_override("font_size", 16)
	hud.add_theme_color_override("font_color", Color(1, 1, 0.85))
	cl.add_child(hud)

# ------------------------------------------------------------------ particles

func _make_emitter(life: float, amount: int, mat: Material, quad: Vector2) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = false
	p.emitting = false              # we inject particles via emit_particle()
	p.local_coords = false          # particles live in world space as they drift
	p.visibility_aabb = AABB(Vector3(-400, -50, -400), Vector3(800, 250, 800))
	var qm := QuadMesh.new()
	qm.size = quad
	qm.material = mat
	p.draw_pass_1 = qm
	p.process_material = _smoke_process() if life > 1.0 else _flash_process()
	return p

func _smoke_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0, 0.5, 0)              # powder smoke rises slowly
	m.damping_min = 0.4
	m.damping_max = 1.0
	m.scale_min = 0.6
	m.scale_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(1.0, 2.2))            # billows out over its life
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	m.color_ramp = _ramp([0.0, 0.12, 0.7, 1.0], [
		Color(0.85, 0.85, 0.85, 0.0), Color(0.85, 0.85, 0.85, 0.55),
		Color(0.8, 0.8, 0.8, 0.3), Color(0.78, 0.78, 0.78, 0.0)])
	return m

func _flash_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3.ZERO
	m.damping_min = 6.0
	m.damping_max = 10.0
	m.scale_min = 0.7
	m.scale_max = 1.1
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(1.0, 0.2))
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	m.color_ramp = _ramp([0.0, 1.0], [Color(1.8, 1.3, 0.6, 1.0), Color(1.4, 0.7, 0.2, 0.0)])
	return m

func _ramp(offs: Array, cols: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _radial_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func _smoke_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = _radial_tex()
	m.vertex_color_use_as_albedo = true
	return m

func _flash_material() -> StandardMaterial3D:
	var m := _smoke_material()
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

func _emit_flash(pos: Vector3) -> void:
	flash_p.emit_particle(Transform3D(Basis(), pos),
		Vector3(randf_range(-0.3, 0.3), randf_range(0.1, 0.4), randf_range(-0.3, 0.3)),
		Color(1.7, 1.2, 0.55), Color.WHITE, EMIT_FLAGS)

func _emit_smoke(pos: Vector3, fwd: Vector3) -> void:
	for i in range(2):
		var jitter := Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.2), randf_range(-0.2, 0.2))
		var vel := fwd * randf_range(0.4, 1.0) + Vector3(0, randf_range(0.2, 0.6), 0)
		smoke_p.emit_particle(Transform3D(Basis(), pos + jitter), vel,
			Color(0.86, 0.86, 0.86), Color.WHITE, EMIT_FLAGS)

# ------------------------------------------------------------------ volley

func _muzzle_points(b: Batt) -> Array:
	var maxy := -1e9
	for f in b.figs:
		maxy = maxf(maxy, (f["p"] as Vector2).y)
	var fwd := Vector3(sin(b.vis), 0, cos(b.vis))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var pts: Array = []
	var k := 0
	for f in b.figs:
		var p: Vector2 = f["p"]
		if p.y >= maxy - SP * 0.6:           # front rank only
			k += 1
			if k % 2 == 0:                   # every other man fires a visible puff
				continue
			var w := b.pos + right * p.x + fwd * (p.y + 0.45)
			pts.append(w + Vector3(0, 0.95, 0))   # muzzle height
	return pts

func _fire_volley(b: Batt) -> void:
	var fwd := Vector3(sin(b.vis), 0, cos(b.vis))
	for mp in _muzzle_points(b):
		_emit_flash(mp)
		_emit_smoke(mp, fwd)
	var foe := _nearest_enemy_batt(b)
	if foe:
		_kill_some(foe, randi_range(2, 5))

func _nearest_enemy_batt(b: Batt) -> Batt:
	var best: Batt = null
	var bd := 1e9
	for o in battalions:
		if o.team == b.team:
			continue
		var d := b.pos.distance_to(o.pos)
		if d < bd:
			bd = d
			best = o
	return best

# ------------------------------------------------------------------ battalions

func _spawn_battalion(team: int, i: int, n_in_line: int) -> void:
	var b := Batt.new()
	b.team = team
	var x := lerpf(-FIELD, FIELD, float(i) / float(maxi(1, n_in_line - 1)))
	var z := -60.0 if team == 0 else 60.0
	b.pos = Vector3(x, 0, z)
	b.spawn = b.pos
	b.facing = 0.0 if team == 0 else PI
	b.vis = b.facing
	b.fire_cd = randf() * 2.5          # stagger so volleys ripple along the line
	_fill_figs(b, 120)
	battalions.append(b)

func _fill_figs(b: Batt, n: int) -> void:
	b.figs.clear()
	for sl in _slots(n, b.formation):
		b.figs.append({ "p": sl, "slot": sl, "ph": randf() * TAU })

func _slots(n: int, formation: String) -> Array:
	var files: int
	var ranks: int
	if formation == "line":
		ranks = 3
		files = int(ceil(float(n) / float(ranks)))
	else:
		files = int(maxf(6.0, round(sqrt(float(n)) * 0.5)))
		ranks = int(ceil(float(n) / float(files)))
	var out: Array = []
	for i in range(n):
		var fi := i % files
		var ra := i / files
		var x := (float(fi) - (files - 1) * 0.5) * SP + randf_range(-0.12, 0.12)
		var z := (float(ra) - (ranks - 1) * 0.5) * SP + randf_range(-0.12, 0.12)
		out.append(Vector2(x, z))
	return out

func _team_centroid(team: int) -> Vector3:
	var s := Vector3.ZERO
	var c := 0
	for b in battalions:
		if b.team == team:
			s += b.pos
			c += 1
	return s / c if c > 0 else Vector3.ZERO

# ------------------------------------------------------------------ per-frame

func _process(delta: float) -> void:
	_t += delta
	_handle_cam(delta)

	var enemy_c := [_team_centroid(1), _team_centroid(0)]
	for b in battalions:
		var goal: Vector3 = enemy_c[b.team]
		var to := goal - b.pos
		to.y = 0.0
		var d := to.length()
		if d > CONTACT:
			b.pos += to.normalized() * SPEED * delta
			b.facing = atan2(to.x, to.z)
		b.vis = lerp_angle(b.vis, b.facing, clampf(delta * 2.5, 0.0, 1.0))
		var t := clampf(FIG_LERP * delta, 0.0, 1.0)
		for f in b.figs:
			f["p"] = (f["p"] as Vector2).lerp(f["slot"], t)
		if d <= CONTACT:
			b.fire_cd -= delta
			if b.fire_cd <= 0.0:
				b.fire_cd = randf_range(2.0, 3.4)
				_fire_volley(b)
		if b.figs.size() < 12:        # spent — reinforce and fall back to re-engage
			b.pos = b.spawn
			_fill_figs(b, 120)

	_rebuild_soldiers()
	_update_hud()

func _kill_some(b: Batt, k: int) -> void:
	var fwd := Vector3(sin(b.vis), 0, cos(b.vis))
	var right := Vector3(fwd.z, 0, -fwd.x)
	for i in range(k):
		if b.figs.is_empty():
			return
		var idx := randi() % b.figs.size()
		var p: Vector2 = b.figs[idx]["p"]
		var w := b.pos + right * p.x + fwd * p.y
		_add_corpse(w, randf() * TAU)
		b.figs.remove_at(idx)

func _add_corpse(pos: Vector3, yaw: float) -> void:
	# capsule tipped over to lie flat, random heading
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
	var xf := Transform3D(basis, Vector3(pos.x, CAP_RADIUS, pos.z))
	corpse_mm.set_instance_transform(corpse_idx, xf)
	corpse_idx = (corpse_idx + 1) % CORPSE_MAX
	corpse_count = mini(corpse_count + 1, CORPSE_MAX)

func _rebuild_soldiers() -> void:
	var idx: Array[int] = [0, 0]
	for b in battalions:
		var fwd := Vector3(sin(b.vis), 0, cos(b.vis))
		var right := Vector3(fwd.z, 0, -fwd.x)
		var basis := Basis(Vector3.UP, b.vis)
		var mm: MultiMesh = team_mm[b.team]
		var i: int = idx[b.team]
		for f in b.figs:
			if i >= MAX_PER_TEAM:
				break
			var p: Vector2 = f["p"]
			var sway := sin(_t * 3.2 + float(f["ph"])) * 0.06
			var w := b.pos + right * (p.x + sway) + fwd * p.y
			mm.set_instance_transform(i, Transform3D(basis, Vector3(w.x, CAP_HALF, w.z)))
			i += 1
		idx[b.team] = i
	for team in [0, 1]:
		var mm: MultiMesh = team_mm[team]
		var active: int = idx[team]
		for j in range(active, team_prev[team]):
			mm.set_instance_transform(j, ZERO_XF)
		team_prev[team] = active

func _rebuild_corpse_mm() -> void:
	pass

# ------------------------------------------------------------------ camera + input

func _handle_cam(delta: float) -> void:
	var fwd := Vector3(-sin(_cam_yaw), 0, -cos(_cam_yaw))
	var right := Vector3(cos(_cam_yaw), 0, -sin(_cam_yaw))
	var pan := _cam_dist * 0.5 * delta
	if Input.is_key_pressed(KEY_W):
		_cam_target += fwd * pan
	if Input.is_key_pressed(KEY_S):
		_cam_target -= fwd * pan
	if Input.is_key_pressed(KEY_A):
		_cam_target -= right * pan
	if Input.is_key_pressed(KEY_D):
		_cam_target += right * pan
	if Input.is_key_pressed(KEY_Q):
		_cam_yaw -= delta * 1.2
	if Input.is_key_pressed(KEY_E):
		_cam_yaw += delta * 1.2
	_update_cam()

func _update_cam() -> void:
	if not cam:
		return
	var dir := Vector3(sin(_cam_yaw) * cos(_cam_pitch), sin(_cam_pitch), cos(_cam_yaw) * cos(_cam_pitch))
	cam.position = _cam_target + dir * _cam_dist
	cam.look_at(_cam_target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_dist = maxf(20.0, _cam_dist - 6.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_dist = minf(260.0, _cam_dist + 6.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				sun.shadow_enabled = not sun.shadow_enabled
			KEY_2:
				var base: int = battalions.size()
				for team in [0, 1]:
					for i in range(6):
						_spawn_battalion(team, base + i, 6)
			KEY_3:
				for b in battalions:
					b.formation = "column" if b.formation == "line" else "line"
					var keep: Array = []
					for f in b.figs:
						keep.append(f["p"])
					var sl := _slots(keep.size(), b.formation)
					for i in range(keep.size()):
						b.figs[i] = { "p": keep[i], "slot": sl[i], "ph": randf() * TAU }

func _update_hud() -> void:
	var soldiers: int = team_prev[0] + team_prev[1]
	hud.text = "FPS %d   soldiers %d   corpses %d   battalions %d   shadows %s\nWASD pan · Q/E rotate · scroll zoom · [1] shadows · [2] +battalions · [3] line/column" % [
		Engine.get_frames_per_second(), soldiers, corpse_count, battalions.size(),
		"on" if sun.shadow_enabled else "off",
	]
