extends Node3D

# ============================================================ THE LIVING WORLD
# Phase 1 of the campaign: one colonial province, persistent and real-time.
# Two factions fight an AI-vs-AI war over the settlements — columns march the
# roads, meet, fight abstract battles (Lanchester attrition from the same stats
# the tactical sim uses), rout, rally and come again. No player unit yet: this
# is the world running by itself, watched with a free camera.
#
# Campaign constraints honoured here:
#  - real time, no time acceleration (dev preview keys 1/2/3 exist ONLY so the
#    war can be verified without waiting hours; they are not a game feature)
#  - colonial North America: large fields, woodlands, scattered settlements
#  - the world is alive: wildlife, civilians, carts on the roads
#
# Phase 2 hook: an engagement near the player INFLATES into the tactical sim by
# authoring a BattleSetup from the tokens involved (see _update_engagements).

const WORLD_SIZE := 12000.0
const MARCH_SPEED := 1.9          # m/s — a column on a road, real time
const ROUT_SPEED := 2.6
const ENGAGE_RANGE := 220.0       # opposing columns this close lock into a fight
const CAPTURE_RANGE := 120.0
const FACTION_NAMES := ["The Crown", "The Continentals"]
const FACTION_COLS := [Color(0.74, 0.28, 0.26), Color(0.30, 0.40, 0.80)]

# ------------------------------------------------------------------ data

class Settlement:
	var name: String
	var pos: Vector3
	var size: int                 # 1 hamlet, 2 village, 3 town
	var owner: int = -1           # -1 neutral
	var cap_t: float = 0.0        # capture progress timer
	var cart_cd: float = 0.0

class Token:                      # one battalion, as the world sees it
	var name: String
	var faction: int
	var men: float = 700.0
	var experience: float = 1.0
	var morale: float = 100.0
	var pos: Vector3
	var dir: Vector3 = Vector3.FORWARD
	var path: Array = []          # settlement indices still to visit
	var state: String = "hold"    # hold | march | fight | rout
	var enemy: Token = null
	var brigade: int = 0
	var smoke_cd: float = 0.0

class Cart:
	var node: Node3D
	var path: Array = []
	var pos: Vector3
	var speed: float = 2.4

var settlements: Array[Settlement] = []
var roads: Array = []             # [i, j] settlement index pairs
var adj: Dictionary = {}          # settlement idx -> Array of neighbour idx
var tokens: Array[Token] = []
var carts: Array[Cart] = []
var civs: Array = []              # { home: int, pos, tgt }
var deer: Array = []              # { pos, tgt, flee }
var fac_goal := [-1, -1]          # current operational objective per faction
var fac_cd := [5.0, 9.0]          # appreciation timers (staggered)

var clock := 7.0                  # hour of day, 1:1 real time
var day := 1
var tscale := 1.0                 # DEV ONLY preview speed (keys 1/2/3)

var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.5
var sun: DirectionalLight3D
var hud: Label
var feed: RichTextLabel
var feed_lines: Array[String] = []

var men_mm: Array = [null, null]  # marching columns per faction
var flag_mm: Array = [null, null]
var deer_mm: MultiMesh
var civ_mm: MultiMesh
var smoke_p: GPUParticles3D

# ------------------------------------------------------------------ build

func _ready() -> void:
	_build_sky()
	_build_ground()
	_build_settlements()
	_build_roads()
	_build_woods_and_fields()
	_build_pools()
	_spawn_armies()
	_spawn_life()
	_build_camera()
	_build_hud()
	_event("The province wakes. %s hold the south, %s the north." % [FACTION_NAMES[0], FACTION_NAMES[1]])

func _build_sky() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.fog_enabled = true
	e.fog_light_color = Color(0.75, 0.80, 0.85)
	e.fog_density = 0.00018
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = false
	add_child(sun)

func _build_ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(WORLD_SIZE, WORLD_SIZE)
	g.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.34, 0.44, 0.26)   # rough meadow green
	m.roughness = 1.0
	g.material_override = m
	add_child(g)

func _add_settlement(n: String, x: float, z: float, size: int, owner: int) -> void:
	var s := Settlement.new()
	s.name = n
	s.pos = Vector3(x, 0, z)
	s.size = size
	s.owner = owner
	settlements.append(s)

func _build_settlements() -> void:
	_add_settlement("Fairhaven", -3800, 4200, 3, 0)        # Crown capital
	_add_settlement("Bridgewater", -1200, 2400, 2, 0)
	_add_settlement("Cooper's Run", 2600, 3400, 1, 0)
	_add_settlement("Oakford", 4100, 1200, 2, -1)
	_add_settlement("Stonebrook", -3400, 600, 1, -1)
	_add_settlement("Millbrook Crossing", 300, -300, 2, -1)
	_add_settlement("Hartsfield", 3600, -2200, 1, 1)
	_add_settlement("Westwood Farm", -4300, -2000, 1, 1)
	_add_settlement("Redding", -800, -4300, 3, 1)          # Continental capital
	roads = [[0, 1], [1, 2], [1, 5], [2, 3], [3, 6], [0, 4], [4, 5], [4, 7], [5, 8], [7, 8], [6, 8]]
	for r in roads:
		if not adj.has(r[0]):
			adj[r[0]] = []
		if not adj.has(r[1]):
			adj[r[1]] = []
		adj[r[0]].append(r[1])
		adj[r[1]].append(r[0])
	# houses: two MultiMeshes (walls + roofs) for every settlement
	var wall_mm := MultiMesh.new()
	wall_mm.transform_format = MultiMesh.TRANSFORM_3D
	wall_mm.use_colors = true
	var wbox := BoxMesh.new()
	wbox.size = Vector3(7, 4.5, 5.5)
	wall_mm.mesh = wbox
	var roof_mm := MultiMesh.new()
	roof_mm.transform_format = MultiMesh.TRANSFORM_3D
	var rbox := BoxMesh.new()
	rbox.size = Vector3(7.8, 1.6, 6.3)
	roof_mm.mesh = rbox
	var houses: Array = []
	for si in range(settlements.size()):
		var s := settlements[si]
		var hn: int = [0, 5, 9, 15][s.size]
		for h in range(hn):
			var a := randf() * TAU
			var d := randf_range(18.0, 26.0 + s.size * 22.0)
			houses.append([s.pos + Vector3(cos(a) * d, 0, sin(a) * d), randf_range(0, TAU)])
	wall_mm.instance_count = houses.size()
	roof_mm.instance_count = houses.size()
	for i in range(houses.size()):
		var p: Vector3 = houses[i][0]
		var rot: float = houses[i][1]
		wall_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rot), p + Vector3(0, 2.25, 0)))
		wall_mm.set_instance_color(i, [Color(0.82, 0.78, 0.68), Color(0.62, 0.50, 0.38), Color(0.75, 0.70, 0.62)][i % 3])
		roof_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rot), p + Vector3(0, 5.3, 0)))
	var wmi := MultiMeshInstance3D.new()
	wmi.multimesh = wall_mm
	var wmat := StandardMaterial3D.new()
	wmat.vertex_color_use_as_albedo = true
	wmi.material_override = wmat
	add_child(wmi)
	var rmi := MultiMeshInstance3D.new()
	rmi.multimesh = roof_mm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.35, 0.26, 0.20)
	rmi.material_override = rmat
	add_child(rmi)
	# name boards
	for s in settlements:
		var lb := Label3D.new()
		lb.text = s.name
		lb.font_size = 256
		lb.pixel_size = 0.05
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position = s.pos + Vector3(0, 38, 0)
		lb.modulate = Color(1, 0.95, 0.8, 0.9)
		add_child(lb)

func _build_roads() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.40, 0.30)   # packed dirt
	mat.roughness = 1.0
	for r in roads:
		var a: Vector3 = settlements[r[0]].pos
		var b: Vector3 = settlements[r[1]].pos
		var mid := (a + b) * 0.5
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(7.0, 0.12, a.distance_to(b))
		mi.mesh = bm
		mi.material_override = mat
		mi.position = mid + Vector3(0, 0.06, 0)
		mi.rotation.y = atan2(b.x - a.x, b.z - a.z)
		add_child(mi)

func _build_woods_and_fields() -> void:
	# woodland blobs — ambush country between the settlements
	var groves := [
		[Vector3(-2600, 0, 1600), 900.0], [Vector3(1400, 0, 1400), 800.0],
		[Vector3(-1500, 0, -1800), 1000.0], [Vector3(2400, 0, -700), 750.0],
		[Vector3(-4000, 0, -3600), 800.0], [Vector3(4200, 0, 3600), 900.0],
		[Vector3(900, 0, -3200), 850.0], [Vector3(-4400, 0, 2400), 700.0]]
	var tree_mm := MultiMesh.new()
	tree_mm.transform_format = MultiMesh.TRANSFORM_3D
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 3.2
	cone.height = 9.0
	cone.radial_segments = 6
	tree_mm.mesh = cone
	tree_mm.instance_count = 2600
	var ti := 0
	for gr in groves:
		var c: Vector3 = gr[0]
		var rad: float = gr[1]
		var n := int(2600.0 / groves.size())
		for k in range(n):
			if ti >= 2600:
				break
			var a := randf() * TAU
			var d := sqrt(randf()) * rad
			var sc := randf_range(0.7, 1.5)
			var xf := Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(sc, sc, sc)), c + Vector3(cos(a) * d, 4.5 * sc, sin(a) * d))
			tree_mm.set_instance_transform(ti, xf)
			ti += 1
	var tmi := MultiMeshInstance3D.new()
	tmi.multimesh = tree_mm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.16, 0.30, 0.16)
	tmi.material_override = tmat
	add_child(tmi)
	# worked fields near settlements — big pale patches
	var fld_mm := MultiMesh.new()
	fld_mm.transform_format = MultiMesh.TRANSFORM_3D
	fld_mm.use_colors = true
	var q := PlaneMesh.new()
	q.size = Vector2(120, 80)
	fld_mm.mesh = q
	fld_mm.instance_count = settlements.size() * 6
	var fi := 0
	for s in settlements:
		for k in range(6):
			var a := randf() * TAU
			var d := randf_range(80.0, 380.0)
			fld_mm.set_instance_transform(fi, Transform3D(Basis(Vector3.UP, randf() * TAU), s.pos + Vector3(cos(a) * d, 0.04, sin(a) * d)))
			fld_mm.set_instance_color(fi, [Color(0.62, 0.58, 0.30), Color(0.50, 0.55, 0.28), Color(0.66, 0.60, 0.38)][fi % 3])
			fi += 1
	var fmi := MultiMeshInstance3D.new()
	fmi.multimesh = fld_mm
	var fmat := StandardMaterial3D.new()
	fmat.vertex_color_use_as_albedo = true
	fmat.roughness = 1.0
	fmi.material_override = fmat
	add_child(fmi)

func _build_pools() -> void:
	# marching men: 24 figures drawn per battalion token, in column of march
	for f in range(2):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var cap := CapsuleMesh.new()
		cap.radius = 0.34
		cap.height = 1.9
		cap.radial_segments = 6
		cap.rings = 2
		mm.mesh = cap
		mm.instance_count = 24 * 24      # up to 24 tokens a side drawn
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = FACTION_COLS[f]
		mi.material_override = mat
		add_child(mi)
		men_mm[f] = mm
		var fm := MultiMesh.new()
		fm.transform_format = MultiMesh.TRANSFORM_3D
		var fq := PlaneMesh.new()
		fq.size = Vector2(4.0, 2.6)
		fq.orientation = PlaneMesh.FACE_Z
		fm.mesh = fq
		fm.instance_count = 24
		var fmi := MultiMeshInstance3D.new()
		fmi.multimesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = FACTION_COLS[f].lightened(0.25)
		fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		fmi.material_override = fmat
		add_child(fmi)
		flag_mm[f] = fm
	# deer
	deer_mm = MultiMesh.new()
	deer_mm.transform_format = MultiMesh.TRANSFORM_3D
	var dcap := CapsuleMesh.new()
	dcap.radius = 0.30
	dcap.height = 1.25
	dcap.radial_segments = 6
	dcap.rings = 2
	deer_mm.mesh = dcap
	deer_mm.instance_count = 80
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = deer_mm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.45, 0.33, 0.22)
	dmi.material_override = dmat
	add_child(dmi)
	# civilians
	civ_mm = MultiMesh.new()
	civ_mm.transform_format = MultiMesh.TRANSFORM_3D
	var ccap := CapsuleMesh.new()
	ccap.radius = 0.30
	ccap.height = 1.7
	ccap.radial_segments = 6
	ccap.rings = 2
	civ_mm.mesh = ccap
	civ_mm.instance_count = 64
	var cmi := MultiMeshInstance3D.new()
	cmi.multimesh = civ_mm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.55, 0.52, 0.44)
	cmi.material_override = cmat
	add_child(cmi)
	# powder smoke over distant fights
	smoke_p = GPUParticles3D.new()
	smoke_p.amount = 3000
	smoke_p.lifetime = 9.0
	smoke_p.explosiveness = 0.0
	smoke_p.emitting = false
	smoke_p.local_coords = false
	smoke_p.visibility_aabb = AABB(Vector3(-WORLD_SIZE, -10, -WORLD_SIZE) * 0.5, Vector3(WORLD_SIZE, 400, WORLD_SIZE))
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, 0.5, 0)
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.6
	pm.scale_min = 4.0
	pm.scale_max = 11.0
	smoke_p.process_material = pm
	var dp := QuadMesh.new()
	dp.size = Vector2(6, 6)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.82, 0.82, 0.80, 0.5)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dp.material = smat
	smoke_p.draw_pass_1 = dp
	add_child(smoke_p)

func _spawn_armies() -> void:
	# 3 brigades of 4 battalions a side for the preview war (~8,400 men each)
	for f in range(2):
		var cap_pos: Vector3 = settlements[0 if f == 0 else 8].pos
		for bg in range(3):
			for k in range(4):
				var t := Token.new()
				t.faction = f
				t.brigade = bg
				var n := bg * 4 + k + 1
				t.name = "%d%s %s" % [n, _ord(n), "of Foot" if f == 0 else "Provincials"]
				t.experience = randf_range(0.85, 1.2)
				var a := randf() * TAU
				t.pos = cap_pos + Vector3(cos(a), 0, sin(a)) * randf_range(60.0, 90.0 + bg * 60.0)
				tokens.append(t)

func _spawn_life() -> void:
	for s in settlements:
		for k in range(2 + s.size * 2):
			civs.append({ "home": settlements.find(s), "pos": s.pos + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)), "tgt": s.pos })
	for k in range(80):
		var p := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * WORLD_SIZE * 0.42
		deer.append({ "pos": p, "tgt": p, "flee": 0.0 })

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.far = 16000.0
	cam.position = Vector3(0, 2400, 3800)
	cam_pitch = -0.55
	add_child(cam)
	_apply_cam()

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(14, 10)
	hud.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	hud.add_theme_font_size_override("font_size", 15)
	ui.add_child(hud)
	feed = RichTextLabel.new()
	feed.bbcode_enabled = true
	feed.scroll_active = false
	feed.position = Vector2(14, 0)
	feed.anchor_top = 1.0
	feed.anchor_bottom = 1.0
	feed.offset_top = -190
	feed.offset_bottom = -12
	feed.custom_minimum_size = Vector2(640, 0)
	feed.size = Vector2(640, 178)
	ui.add_child(feed)

# ------------------------------------------------------------------ the war

func _process(delta: float) -> void:
	var dt := delta * tscale
	clock += dt / 3600.0          # REAL TIME: one game hour per real hour
	if clock >= 24.0:
		clock -= 24.0
		day += 1
	_update_sun()
	_update_factions(dt)
	_update_tokens(dt)
	_update_capture(dt)
	_update_life(dt)
	_render_tokens()
	_update_hud()
	_cam_move(delta)

func _update_sun() -> void:
	var elev := sin((clock - 6.0) / 12.0 * PI)
	sun.rotation = Vector3(-maxf(0.05, elev) * 1.3, 0.6, 0)
	sun.light_energy = clampf(elev * 1.3 + 0.18, 0.04, 1.2)

# the operational appreciation: each faction periodically scores the settlements
# (value x feasibility, hysteresis on the standing objective) and points its idle
# brigades — the same evaluator pattern as the battle AI, one level up
func _update_factions(dt: float) -> void:
	for f in range(2):
		fac_cd[f] -= dt
		if fac_cd[f] > 0.0:
			continue
		fac_cd[f] = 45.0
		var best := -1
		var bs := -1.0
		for si in range(settlements.size()):
			var s := settlements[si]
			if s.owner == f:
				continue
			var v := float(s.size) * (1.6 if s.owner == 1 - f else 1.15)
			var d := _fac_center(f).distance_to(s.pos)
			var sc := v / (1.0 + d / 2500.0) + (0.5 if si == fac_goal[f] else 0.0)
			if sc > bs:
				bs = sc
				best = si
		if best != -1 and best != fac_goal[f]:
			fac_goal[f] = best
			_event("%s march on [b]%s[/b]." % [FACTION_NAMES[f], settlements[best].name])
		# point idle battalions at the objective; keep one brigade home as garrison
		for t in tokens:
			if t.faction != f or t.state != "hold":
				continue
			var tgt: int = fac_goal[f] if t.brigade > 0 else (0 if f == 0 else 8)
			if tgt == -1:
				continue
			var from := _nearest_settlement(t.pos)
			var p := _route(from, tgt)
			if p.size() > 0:
				t.path = p
				t.state = "march"

func _fac_center(f: int) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for t in tokens:
		if t.faction == f:
			c += t.pos
			n += 1
	return c / maxf(1.0, float(n))

func _nearest_settlement(p: Vector3) -> int:
	var best := 0
	var bd := 1e18
	for i in range(settlements.size()):
		var d := p.distance_squared_to(settlements[i].pos)
		if d < bd:
			bd = d
			best = i
	return best

func _route(from: int, to: int) -> Array:
	if from == to:
		return []
	var prev := {}
	var q := [from]
	prev[from] = -1
	while not q.is_empty():
		var cur: int = q.pop_front()
		if cur == to:
			break
		for nb in adj.get(cur, []):
			if not prev.has(nb):
				prev[nb] = cur
				q.append(nb)
	if not prev.has(to):
		return []
	var path := []
	var cur2 := to
	while cur2 != -1:
		path.push_front(cur2)
		cur2 = prev[cur2]
	path.pop_front()              # drop the start node
	return path

func _update_tokens(dt: float) -> void:
	# movement and engagement
	for t in tokens:
		match t.state:
			"march", "rout":
				if t.path.is_empty():
					t.state = "hold" if t.state == "march" else "hold"
					continue
				var tgt: Vector3 = settlements[t.path[0]].pos
				var d := t.pos.distance_to(tgt)
				if d < 50.0:
					t.path.pop_front()
					continue
				var sp := ROUT_SPEED if t.state == "rout" else MARCH_SPEED
				t.dir = (tgt - t.pos) / d
				t.pos += t.dir * sp * dt
				if t.state == "rout":
					t.morale = minf(100.0, t.morale + dt * 0.6)
			"fight":
				_resolve_fight(t, dt)
			"hold":
				t.morale = minf(100.0, t.morale + dt * 0.4)
	# lock opposing columns that meet into engagements
	for t in tokens:
		if t.state == "fight" or t.state == "rout":
			continue
		for e in tokens:
			if e.faction == t.faction or e.state == "rout":
				continue
			if t.pos.distance_squared_to(e.pos) < ENGAGE_RANGE * ENGAGE_RANGE:
				if t.state != "fight":
					_event("%s and %s are engaged near %s." % [t.name, e.name, settlements[_nearest_settlement(t.pos)].name])
				t.state = "fight"
				t.enemy = e
				e.state = "fight"
				e.enemy = t
				break
	# the fallen are struck from the rolls
	for i in range(tokens.size() - 1, -1, -1):
		var t2 := tokens[i]
		if t2.men < 60.0:
			_event("[color=#caa]%s is destroyed as a fighting force.[/color]" % t2.name)
			if t2.enemy != null and t2.enemy.enemy == t2:
				t2.enemy.enemy = null
				t2.enemy.state = "hold"
			tokens.remove_at(i)

# Lanchester attrition from the same stats the tactical sim uses — so a distant
# battle and a fought battle agree about how war works. PHASE 2: when the player
# is near, this is replaced by authoring a BattleSetup and inflating to the sim.
func _resolve_fight(t: Token, dt: float) -> void:
	var e := t.enemy
	if e == null or e.men < 60.0 or e.state == "rout":
		t.state = "hold"
		t.enemy = null
		return
	t.men -= e.men * 0.0030 * e.experience * dt
	t.morale -= dt * (2.0 * e.men / maxf(t.men, 1.0)) * 0.55
	t.smoke_cd -= dt
	if t.smoke_cd <= 0.0:
		t.smoke_cd = 0.6
		smoke_p.emit_particle(Transform3D(Basis(), t.pos + Vector3(randf_range(-20, 20), 8, randf_range(-20, 20))), Vector3(0, 1, 0), Color.WHITE, Color.WHITE, 5)
	if t.morale < 35.0:
		t.state = "rout"
		var home := 0 if t.faction == 0 else 8
		t.path = _route(_nearest_settlement(t.pos), home)
		t.enemy = null
		if e.enemy == t:
			e.enemy = null
			e.state = "hold"
		_event("[color=#e9c46a]%s break and stream to the rear![/color]" % t.name)

func _update_capture(dt: float) -> void:
	for si in range(settlements.size()):
		var s := settlements[si]
		var present := [false, false]
		for t in tokens:
			if t.state != "rout" and t.pos.distance_to(s.pos) < CAPTURE_RANGE:
				present[t.faction] = true
		for f in range(2):
			if present[f] and not present[1 - f] and s.owner != f:
				s.cap_t += dt
				if s.cap_t > 25.0:
					s.owner = f
					s.cap_t = 0.0
					_event("[color=#9fe0a0]%s falls to %s.[/color]" % [s.name, FACTION_NAMES[f]])
		if not present[0] and not present[1]:
			s.cap_t = 0.0

# ------------------------------------------------------------------ the living world

func _update_life(dt: float) -> void:
	# carts ply the roads between settlements
	for si in range(settlements.size()):
		var s := settlements[si]
		s.cart_cd -= dt
		if s.cart_cd <= 0.0 and carts.size() < 10:
			s.cart_cd = randf_range(60.0, 140.0)
			var nbs: Array = adj.get(si, [])
			if nbs.is_empty():
				continue
			var c := Cart.new()
			c.pos = s.pos
			c.path = [nbs[randi() % nbs.size()]]
			c.node = _make_cart()
			carts.append(c)
	for i in range(carts.size() - 1, -1, -1):
		var c := carts[i]
		var tgt: Vector3 = settlements[c.path[0]].pos
		var d := c.pos.distance_to(tgt)
		if d < 30.0:
			c.node.queue_free()
			carts.remove_at(i)
			continue
		var dir := (tgt - c.pos) / d
		c.pos += dir * c.speed * dt
		c.node.position = c.pos + Vector3(0, 1.0, 0)
		c.node.rotation.y = atan2(dir.x, dir.z)
	# civilians go about their day (and stay indoors after dark)
	var ci := 0
	var daylight := clock > 6.5 and clock < 20.5
	for cv in civs:
		if ci >= civ_mm.instance_count:
			break
		var home: Vector3 = settlements[cv["home"]].pos
		if daylight:
			if cv["pos"].distance_to(cv["tgt"]) < 3.0:
				cv["tgt"] = home + Vector3(randf_range(-70, 70), 0, randf_range(-70, 70))
			cv["pos"] = cv["pos"].move_toward(cv["tgt"], 0.8 * dt)
			civ_mm.set_instance_transform(ci, Transform3D(Basis(), cv["pos"] + Vector3(0, 0.85, 0)))
		else:
			civ_mm.set_instance_transform(ci, Transform3D().scaled(Vector3.ZERO))
		ci += 1
	# deer graze the wood edges and flee from anything human
	var di := 0
	for dr in deer:
		if di >= deer_mm.instance_count:
			break
		var threat := 1e18
		for t in tokens:
			threat = minf(threat, dr["pos"].distance_squared_to(t.pos))
		if threat < 90.0 * 90.0:
			dr["flee"] = 4.0
		if dr["flee"] > 0.0:
			dr["flee"] -= dt
			var away: Vector3 = (dr["pos"] - _nearest_token_pos(dr["pos"])).normalized()
			dr["pos"] += away * 5.0 * dt
		else:
			if dr["pos"].distance_to(dr["tgt"]) < 2.0:
				dr["tgt"] = dr["pos"] + Vector3(randf_range(-60, 60), 0, randf_range(-60, 60))
			dr["pos"] = dr["pos"].move_toward(dr["tgt"], 0.5 * dt)
		deer_mm.set_instance_transform(di, Transform3D(Basis(), dr["pos"] + Vector3(0, 0.6, 0)))
		di += 1

func _nearest_token_pos(p: Vector3) -> Vector3:
	var best := Vector3(1e9, 0, 1e9)
	var bd := 1e18
	for t in tokens:
		var d := p.distance_squared_to(t.pos)
		if d < bd:
			bd = d
			best = t.pos
	return best

func _make_cart() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 1.0, 3.2)
	body.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.35, 0.25)
	body.material_override = m
	n.add_child(body)
	var horse := MeshInstance3D.new()
	var hm := CapsuleMesh.new()
	hm.radius = 0.32
	hm.height = 1.8
	hm.radial_segments = 6
	hm.rings = 2
	horse.mesh = hm
	horse.rotation.x = PI * 0.5
	horse.position = Vector3(0, 0.1, 2.4)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.30, 0.22, 0.16)
	horse.material_override = hmat
	n.add_child(horse)
	add_child(n)
	return n

# ------------------------------------------------------------------ rendering

func _render_tokens() -> void:
	for f in range(2):
		var mm: MultiMesh = men_mm[f]
		var fm: MultiMesh = flag_mm[f]
		var i := 0
		var fi := 0
		for t in tokens:
			if t.faction != f:
				continue
			var fwd := t.dir
			var right := Vector3(fwd.z, 0, -fwd.x)
			# a column of march: 12 ranks of 2, strung out behind the head
			for r in range(12):
				for c in range(2):
					if i >= mm.instance_count:
						break
					var p := t.pos - fwd * float(r) * 2.2 + right * (float(c) - 0.5) * 1.6
					mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, atan2(fwd.x, fwd.z)), p + Vector3(0, 0.95, 0)))
					i += 1
			if fi < fm.instance_count:
				fm.set_instance_transform(fi, Transform3D(Basis(Vector3.UP, atan2(fwd.x, fwd.z)), t.pos + Vector3(0, 5.0, 0)))
				fi += 1
		for j in range(i, mm.instance_count):
			mm.set_instance_transform(j, Transform3D().scaled(Vector3.ZERO))
		for j in range(fi, fm.instance_count):
			fm.set_instance_transform(j, Transform3D().scaled(Vector3.ZERO))

func _update_hud() -> void:
	var hold := [0, 0, 0]
	for s in settlements:
		hold[s.owner if s.owner >= 0 else 2] += 1
	var men := [0, 0]
	for t in tokens:
		men[t.faction] += int(t.men)
	hud.text = "Day %d — %02d:%02d      %s: %d towns, %d men      %s: %d towns, %d men      [%s]\nWASD fly · RMB look · Q/E down/up · Shift fast · 1/2/3 preview speed (dev) · Esc menu" % [
		day, int(clock), int(fposmod(clock, 1.0) * 60.0),
		FACTION_NAMES[0], hold[0], men[0], FACTION_NAMES[1], hold[1], men[1],
		("real time" if tscale <= 1.0 else "preview x%d" % int(tscale))]

func _event(msg: String) -> void:
	feed_lines.append("[color=#8a93a6]Day %d %02d:%02d[/color]  %s" % [day, int(clock), int(fposmod(clock, 1.0) * 60.0), msg])
	if feed_lines.size() > 9:
		feed_lines.pop_front()
	if feed != null:
		feed.text = "\n".join(feed_lines)

# ------------------------------------------------------------------ free camera

func _apply_cam() -> void:
	cam.rotation = Vector3(cam_pitch, cam_yaw, 0)

func _cam_move(delta: float) -> void:
	var sp := 900.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 250.0
	var mv := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		mv -= cam.global_transform.basis.z
	if Input.is_physical_key_pressed(KEY_S):
		mv += cam.global_transform.basis.z
	if Input.is_physical_key_pressed(KEY_A):
		mv -= cam.global_transform.basis.x
	if Input.is_physical_key_pressed(KEY_D):
		mv += cam.global_transform.basis.x
	if Input.is_physical_key_pressed(KEY_E):
		mv += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q):
		mv -= Vector3.UP
	cam.position += mv.normalized() * sp * delta if mv.length_squared() > 0.0 else Vector3.ZERO
	cam.position.y = clampf(cam.position.y, 6.0, 6000.0)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if ev.pressed else Input.MOUSE_MODE_VISIBLE)
	elif ev is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= ev.relative.x * 0.0028
		cam_pitch = clampf(cam_pitch - ev.relative.y * 0.0028, -1.5, 1.4)
		_apply_cam()
	elif ev is InputEventKey and ev.pressed:
		match ev.physical_keycode:
			KEY_1:
				tscale = 1.0
			KEY_2:
				tscale = 8.0
			KEY_3:
				tscale = 30.0
			KEY_ESCAPE:
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				else:
					get_tree().change_scene_to_file("res://menu.tscn")

func _ord(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "th"
	match n % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
	return "th"
