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

const WORLD_SIZE := 18000.0
const MARCH_SPEED := 1.9          # m/s — a column on a road, real time
const ROUT_SPEED := 2.6
const ENGAGE_RANGE := 220.0       # opposing columns this close lock into a fight
const CAPTURE_RANGE := 120.0
const FACTION_NAMES := ["The Crown", "The Continentals"]
# Blue vs Red, matching the battle (your side = blue, the enemy = red)
const FACTION_COLS := [Color(0.24, 0.36, 0.74), Color(0.70, 0.20, 0.20)]
# regimental facings, mirrored from the tactical sim so a token's dress carries
# unchanged into its inflated battle
const FACINGS_0 := [Color(0.95, 0.92, 0.85), Color(0.85, 0.15, 0.15), Color(0.92, 0.80, 0.15),
	Color(0.65, 0.10, 0.35), Color(0.95, 0.50, 0.12), Color(0.45, 0.70, 0.90)]
const FACINGS_1 := [Color(0.92, 0.85, 0.30), Color(0.20, 0.45, 0.20), Color(0.10, 0.15, 0.40),
	Color(0.95, 0.95, 0.92), Color(0.55, 0.12, 0.45), Color(0.05, 0.05, 0.06)]

# ------------------------------------------------------------------ data

class Settlement:
	var name: String
	var pos: Vector3
	var size: int                 # 1 hamlet, 2 village, 3 town
	var owner: int = -1           # -1 neutral
	var cap_t: float = 0.0        # capture progress timer
	var cart_cd: float = 0.0

class Token:                      # one battalion, as the world sees it
	var id: int = 0               # stable across the inflation scene-change
	var name: String
	var faction: int
	var men: float = 700.0
	var experience: float = 1.0
	var morale: float = 100.0
	var skills: Dictionary = {}   # {reload,aim,melee,discipline,stamina} 0..100 — carried to battle and back
	var fatigue: float = 0.0      # weariness from the last action, rested down in camp at a town
	var roster: Array = []        # named men by company: {name,rank,coy,focus,reload..stamina}
	var company_names: Array = [] # one name per company (renamable)
	var pos: Vector3
	var dir: Vector3 = Vector3.FORWARD
	var path: Array = []          # (legacy road waypoints — movement is free now)
	var dest: Vector3             # where this battalion is marching, cross-country
	var has_dest: bool = false
	var state: String = "hold"    # hold | march | fight | rout
	var enemy: Token = null
	var division: int = 0
	var brigade: int = 0
	var smoke_cd: float = 0.0
	var is_player: bool = false   # the battalion the player commands
	var facing_col: Color = Color.WHITE
	var coat_idx: int = 0

class HQ:                         # a command post: army / division / brigade
	var faction: int
	var level: int                # 0 army, 1 division, 2 brigade
	var idx: int                  # which division/brigade it commands
	var name: String
	var pos: Vector3
	var node: Node3D
	var label: Label3D
	var courier_cd: float = 0.0

class Courier:                    # a rider carrying orders or news between posts
	var faction: int
	var pos: Vector3
	var target                    # an HQ or Token (we track its live position)
	var msg: String
	var to_player: bool = false
	var node: Node3D

class Cart:
	var node: Node3D
	var path: Array = []
	var pos: Vector3
	var speed: float = 2.4

class Depot:                      # a magazine an army founds behind its lines
	var faction: int
	var si: int = -1              # the settlement it stands at
	var pos: Vector3
	var supply: float = 60.0      # 0..100 — spent by purchases, decays, topped up by convoys
	var node: Node3D
	var label: Label3D

class Convoy:                     # a waggon train carrying supplies from a town to a depot
	var faction: int
	var pos: Vector3
	var depot: Depot
	var node: Node3D

var settlements: Array[Settlement] = []
var roads: Array = []             # [i, j] settlement index pairs
var adj: Dictionary = {}          # settlement idx -> Array of neighbour idx
var tokens: Array[Token] = []
var next_id := 1
var player_tok: Token = null      # the battalion the player commands
var pending: Token = null         # enemy token the player has met, awaiting "give battle"
var follow := false               # camera rides above the player's column
var in_battle := false            # a hosted tactical battle is live on the province
var battle_sim: Node3D = null     # the embedded game.gd instance
var ui_layer: CanvasLayer         # the campaign HUD layer (hidden during a battle)
var ground_mi: MeshInstance3D     # the province ground (kept visible under a battle)
var contact_t := 0.0              # dwell since meeting the enemy; battle forms on its own
const CONTACT_DELAY := 1.3        # seconds in contact before the lines engage (no F needed)
var carts: Array[Cart] = []
var civs: Array = []              # { home: int, pos, tgt }
var deer: Array = []              # { pos, tgt, flee }
var fac_goal := [-1, -1]          # current operational objective per faction
var fac_cd := [5.0, 9.0]          # appreciation timers (staggered)
var _player_order_msg := ""       # the last order despatched to the player (so we don't repeat it)
var fac_aggr := [0.6, 0.6]        # each army commander's temperament: cautious (0) .. bold (1)
var div_dir: Array = []           # per division (f*DIVS+dv): 0 attack the objective, 1 defend a town; sized in _ready
var _war_over := false
var hqs: Array = []               # army/division/brigade command posts
var couriers: Array = []          # riders carrying orders and news
# the supply economy: depots founded by the AI, fed by convoys, drawn on with prestige
var depots: Array = []            # Depot
var convoys: Array = []           # Convoy
var depot_cd := [25.0, 40.0]      # per-faction timer for founding the next magazine
var player_prestige := 0          # renown banked from battles — spent at friendly depots
var hills: Array = []             # { name, pos } hilltops — strategic high ground
var strong_points: Array = []     # { pos, kind, name, holder } woods + hills to hold
const DIVS_PER_SIDE := 4
const BDES_PER_DIV := 3
const BNS_PER_BDE := 4         # 48 battalions a side now (was 12) — a small army apiece
const MARCH_ARRIVE := 60.0        # how close counts as "arrived"
const COURIER_SPEED := 22.0       # a galloper carries faster than a marching column

var clock := 7.0                  # hour of day, 1:1 real time
var day := 1
var tscale := 1.0                 # DEV ONLY preview speed (keys 1/2/3)

var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.5

# --- the mounted officer: how the player actually moves through the province ---
# (third person is the game; the overhead free-fly below is a DEV view only)
var ride_mode := false            # (legacy ride removed; kept false so the map marker shows)
var officer: Node3D
var off_pos := Vector3.ZERO
var off_yaw := 0.0                # the horse's heading
var off_speed := 0.0             # current pace, m/s
var look_yaw := 0.0              # free-look offset around the horse
var look_pitch := -0.05
var gait_t := 0.0
const RIDE_WALK := 4.0
const RIDE_CANTER := 11.0
const RIDE_TURN := 1.9            # rad/s at the canter
var sun: DirectionalLight3D
var hud: RichTextLabel
var feed: RichTextLabel
var feed_lines: Array[String] = []

var men_mm: Array = [null, null]  # unit counters per faction
var flag_mm: Array = [null, null] # counter base plates per faction
var token_labels: Array[Label3D] = []   # name + strength over each counter
var settlement_discs: Array[MeshInstance3D] = []   # owner-coloured disc under each town
var settlement_labels: Array[Label3D] = []
var objective_si := -1            # the settlement the player is directed to take
var anim_t := 0.0                 # real-time accumulator for map pulses
var deer_mm: MultiMesh
var civ_mm: MultiMesh
var smoke_p: GPUParticles3D

# ------------------------------------------------------------------ build

func _ready() -> void:
	div_dir.resize(2 * DIVS_PER_SIDE)   # one slot per division per faction
	div_dir.fill(0)
	_build_sky()
	_build_ground()
	_build_settlements()
	_build_roads()
	_build_hills()
	_build_woods_and_fields()
	_build_strong_points()
	_build_landmarks()
	_build_pools()
	var returning: bool = not GameConfig.world_state.is_empty()
	if returning:
		_restore_world(GameConfig.world_state)
	else:
		_spawn_armies()
	_spawn_hqs()                   # command posts (rebuilt fresh; not serialized)
	_spawn_life()
	_build_camera()
	_build_hud()
	if returning:
		_apply_battle_result()
	else:
		_event("The province wakes. %s hold the south, %s the north." % [FACTION_NAMES[0], FACTION_NAMES[1]])
		_event("You command [b]%s[/b]. Click the map to march. A battle begins when you close on the enemy." % player_tok.name)
	if player_tok != null:
		_center_on(player_tok.pos)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)   # the map is driven by the cursor

func _build_sky() -> void:
	# a clean MAP look: no sky, no fog/haze, flat even light. The whole map uses
	# unshaded materials so it reads like paper regardless of the time of day.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.19, 0.23)      # the table the map lies on
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 1.0
	e.fog_enabled = false
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = false
	sun.light_energy = 1.0
	add_child(sun)

func _build_ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(WORLD_SIZE, WORLD_SIZE)
	g.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.79, 0.76, 0.64)   # parchment / map paper
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g.material_override = m
	add_child(g)
	ground_mi = g                 # kept so it stays visible (under a hosted battle)

func _add_settlement(n: String, x: float, z: float, size: int, owner: int) -> void:
	var s := Settlement.new()
	s.name = n
	s.pos = Vector3(x, 0, z)
	s.size = size
	s.owner = owner
	settlements.append(s)

# The capital of a faction: Crown holds index 0, the Continentals the last settlement.
func _cap_idx(f: int) -> int:
	return 0 if f == 0 else settlements.size() - 1

func _build_settlements() -> void:
	# a whole province of towns, generated on a jittered grid. The Crown capital is index
	# 0 (north-west), the Continental capital the last settlement (south-east); the middle
	# belt is neutral ground to be fought over. Capitals are size 3, the rest 1-2.
	var half := WORLD_SIZE * 0.44
	_add_settlement("Fairhaven", -half * 0.94, half * 0.94, 3, 0)
	var names := ["Bridgewater", "Cooper's Run", "Oakford", "Stonebrook", "Millbrook", "Hartsfield",
		"Westwood", "Ashby", "Greenfield", "Thornbury", "Larkspur", "Marlowe", "Penhallow",
		"Saltmarsh", "Kingsferry", "Duncastle", "Ravenswood", "Crowmere", "Holloway", "Edgewater",
		"Fenwick", "Drayton", "Brackmoor", "Selby", "Whitcombe", "Norcross", "Aldergate", "Wexley"]
	var grid := 6
	var ni := 0
	for gx in range(grid):
		for gz in range(grid):
			if (gx == 0 and gz == 0) or (gx == grid - 1 and gz == grid - 1):
				continue                             # corners reserved for the two capitals
			var x := lerpf(-half, half, float(gx) / float(grid - 1)) + randf_range(-half * 0.07, half * 0.07)
			var z := lerpf(half, -half, float(gz) / float(grid - 1)) + randf_range(-half * 0.07, half * 0.07)
			var owner := -1
			if z > half * 0.34:
				owner = 0
			elif z < -half * 0.34:
				owner = 1
			var size := 1
			var rr := randf()
			if rr > 0.85:
				size = 3
			elif rr > 0.52:
				size = 2
			_add_settlement(names[ni % names.size()], x, z, size, owner)
			ni += 1
	_add_settlement("Redding", half * 0.94, -half * 0.94, 3, 1)
	_build_road_graph()
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
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmi.material_override = wmat
	add_child(wmi)
	var rmi := MultiMeshInstance3D.new()
	rmi.multimesh = roof_mm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.45, 0.32, 0.24)
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmi.material_override = rmat
	add_child(rmi)
	# owner discs + name boards (coloured by who holds the town, updated each frame)
	for si in range(settlements.size()):
		var s := settlements[si]
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 60.0 + s.size * 28.0
		cyl.bottom_radius = cyl.top_radius
		cyl.height = 2.0
		disc.mesh = cyl
		disc.position = s.pos + Vector3(0, 1.0, 0)
		var dmat := StandardMaterial3D.new()
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		disc.material_override = dmat
		add_child(disc)
		settlement_discs.append(disc)
		var lb := Label3D.new()
		lb.text = s.name
		lb.font_size = 256
		lb.pixel_size = 0.05
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position = s.pos + Vector3(0, 38, 0)
		add_child(lb)
		settlement_labels.append(lb)

# Lay a connected road network: a minimum spanning tree guarantees every town is
# reachable, then each town gets a road to its nearest not-yet-linked neighbour for loops.
func _build_road_graph() -> void:
	roads.clear()
	adj.clear()
	var n := settlements.size()
	if n < 2:
		return
	var in_tree: Array = []
	in_tree.resize(n)
	for i in range(n):
		in_tree[i] = false
	in_tree[0] = true
	var added := 1
	while added < n:
		var ba := -1
		var bb := -1
		var bd := 1.0e30
		for a in range(n):
			if not in_tree[a]:
				continue
			for b in range(n):
				if in_tree[b]:
					continue
				var d: float = settlements[a].pos.distance_squared_to(settlements[b].pos)
				if d < bd:
					bd = d; ba = a; bb = b
		if bb < 0:
			break
		in_tree[bb] = true
		added += 1
		_add_road(ba, bb)
	for a in range(n):
		var nb := _nearest_unlinked(a)
		if nb >= 0:
			_add_road(a, nb)

func _add_road(i: int, j: int) -> void:
	if i == j:
		return
	for r in roads:
		if (r[0] == i and r[1] == j) or (r[0] == j and r[1] == i):
			return
	roads.append([i, j])
	if not adj.has(i):
		adj[i] = []
	if not adj.has(j):
		adj[j] = []
	if not (j in adj[i]):
		adj[i].append(j)
	if not (i in adj[j]):
		adj[j].append(i)

func _nearest_unlinked(a: int) -> int:
	var best := -1
	var bd := 1.0e30
	for b in range(settlements.size()):
		if b == a or (adj.has(a) and b in adj[a]):
			continue
		var d: float = settlements[a].pos.distance_squared_to(settlements[b].pos)
		if d < bd:
			bd = d; best = b
	return best

func _build_roads() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.45, 0.32)   # a drawn road line
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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

func _grove_list() -> Array:
	return [
		[Vector3(-2600, 0, 1600), 900.0], [Vector3(1400, 0, 1400), 800.0],
		[Vector3(-1500, 0, -1800), 1000.0], [Vector3(2400, 0, -700), 750.0],
		[Vector3(-4000, 0, -3600), 800.0], [Vector3(4200, 0, 3600), 900.0],
		[Vector3(900, 0, -3200), 850.0], [Vector3(-4400, 0, 2400), 700.0],
		# more woodland, spread across the larger province
		[Vector3(-6200, 0, 600), 950.0], [Vector3(6000, 0, -1400), 880.0],
		[Vector3(3400, 0, 5200), 820.0], [Vector3(-3000, 0, 5400), 760.0],
		[Vector3(-6600, 0, -2600), 900.0], [Vector3(6800, 0, 4200), 840.0],
		[Vector3(2000, 0, -5600), 780.0], [Vector3(-1200, 0, -6200), 820.0]]

func _build_woods_and_fields() -> void:
	# woodland blobs — ambush country between the settlements
	var groves := _grove_list()
	# woods are drawn as flat green map patches (a few overlapping discs per grove),
	# not 3D trees — clean and readable from above
	var tree_mm := MultiMesh.new()
	tree_mm.transform_format = MultiMesh.TRANSFORM_3D
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 1.0
	disc.radial_segments = 16
	tree_mm.mesh = disc
	tree_mm.instance_count = groves.size() * 4
	var ti := 0
	for gr in groves:
		var c: Vector3 = gr[0]
		var rad: float = gr[1]
		for k in range(4):
			var a := randf() * TAU
			var off := randf_range(0.0, rad * 0.45)
			var r2 := rad * randf_range(0.55, 0.95)
			var p := c + Vector3(cos(a) * off, 0.5, sin(a) * off)
			tree_mm.set_instance_transform(ti, Transform3D(Basis().scaled(Vector3(r2, 1.0, r2)), p))
			ti += 1
	var tmi := MultiMeshInstance3D.new()
	tmi.multimesh = tree_mm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.36, 0.48, 0.30)   # muted map green
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmi.material_override = fmat
	add_child(fmi)

# hilltops — strategic high ground, drawn as contour rings with a name
func _build_hills() -> void:
	# real high ground now — each hill has a footprint and a height, and is drawn as a
	# tiered cone (contour steps you can read from above, AND genuine elevation the troops
	# climb up and over rather than passing through). More of them, across the province.
	hills = [
		{ "name": "Vimy Ridge", "pos": Vector3(-1900, 0, 900), "radius": 540.0, "height": 130.0 },
		{ "name": "Telegraph Hill", "pos": Vector3(1600, 0, -400), "radius": 430.0, "height": 160.0 },
		{ "name": "Round Top", "pos": Vector3(-300, 0, -2400), "radius": 380.0, "height": 175.0 },
		{ "name": "Signal Heights", "pos": Vector3(3000, 0, 1700), "radius": 500.0, "height": 145.0 },
		{ "name": "Beacon Hill", "pos": Vector3(-3400, 0, -1100), "radius": 360.0, "height": 120.0 },
		{ "name": "Kettle Down", "pos": Vector3(-5400, 0, 3900), "radius": 470.0, "height": 135.0 },
		{ "name": "Raven Crag", "pos": Vector3(5000, 0, -3700), "radius": 420.0, "height": 185.0 },
		{ "name": "Windmill Hill", "pos": Vector3(1000, 0, 4300), "radius": 360.0, "height": 110.0 },
		{ "name": "Gallows Knoll", "pos": Vector3(-4600, 0, -4400), "radius": 340.0, "height": 105.0 },
		{ "name": "The Saddleback", "pos": Vector3(5800, 0, 2500), "radius": 560.0, "height": 150.0 },
	]
	for h in hills:
		var c: Vector3 = h["pos"]
		var rad: float = float(h["radius"])
		var peak: float = float(h["height"])
		var tiers := 4
		for ti in range(tiers):
			var f0 := float(ti) / float(tiers)
			var f1 := float(ti + 1) / float(tiers)
			var rm := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.bottom_radius = rad * (1.0 - f0 * 0.82)
			cyl.top_radius = rad * (1.0 - f1 * 0.82)
			cyl.height = peak / float(tiers)
			cyl.radial_segments = 30
			rm.mesh = cyl
			rm.position = c + Vector3(0, peak * (f0 + f1) * 0.5, 0)
			var rmat := StandardMaterial3D.new()
			rmat.albedo_color = Color(0.58, 0.50, 0.36).lerp(Color(0.82, 0.74, 0.56), f0)
			rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rm.material_override = rmat
			add_child(rm)
		var lb := Label3D.new()
		lb.text = "△ " + h["name"]
		lb.font_size = 180
		lb.pixel_size = 0.09
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.modulate = Color(0.6, 0.45, 0.32)
		lb.position = c + Vector3(0, peak + 30.0, 0)
		add_child(lb)

# The lie of the land: the height of the ground at a point, summed (max) over the hills,
# falling smoothly to zero at each hill's edge. Troops ride this, and climb it slowly.
func _terrain_height(x: float, z: float) -> float:
	var hgt := 0.0
	for h in hills:
		var c: Vector3 = h["pos"]
		var rad: float = float(h["radius"])
		var d := Vector2(x - c.x, z - c.z).length()
		if d < rad:
			var tt := 1.0 - d / rad
			hgt = maxf(hgt, float(h["height"]) * tt * tt * (3.0 - 2.0 * tt))   # smoothstep dome
	return hgt

var landmarks: Array = []         # ruins, bridges, crossroads, churches, mills, towers, fords

# Scatter named points of interest across the province — some flavour, some defensible
# ground the armies will fight to hold. Each is a small marker with a glyph and a name.
func _build_landmarks() -> void:
	landmarks = [
		{ "name": "Hollow Abbey", "pos": Vector3(-2200, 0, -800), "kind": "church", "glyph": "✝" },
		{ "name": "King's Cross", "pos": Vector3(800, 0, -400), "kind": "crossroads", "glyph": "✕" },
		{ "name": "Greywater Bridge", "pos": Vector3(-600, 0, 1900), "kind": "bridge", "glyph": "≈" },
		{ "name": "Stagg's Mill", "pos": Vector3(2900, 0, 2600), "kind": "mill", "glyph": "✦" },
		{ "name": "Old Fort", "pos": Vector3(-3800, 0, 3000), "kind": "ruin", "glyph": "⌂" },
		{ "name": "The Watchtower", "pos": Vector3(4400, 0, -2200), "kind": "tower", "glyph": "♜" },
		{ "name": "Marsh Ford", "pos": Vector3(-1400, 0, -3600), "kind": "ford", "glyph": "≈" },
		{ "name": "Pilgrim's Cross", "pos": Vector3(3800, 0, 800), "kind": "crossroads", "glyph": "✕" },
		{ "name": "Saintbridge", "pos": Vector3(-5000, 0, -300), "kind": "bridge", "glyph": "≈" },
		{ "name": "Black Chapel", "pos": Vector3(5200, 0, 4800), "kind": "church", "glyph": "✝" },
		{ "name": "Gibbet Ruin", "pos": Vector3(-5800, 0, 5200), "kind": "ruin", "glyph": "⌂" },
		{ "name": "Drover's Cross", "pos": Vector3(200, 0, 5600), "kind": "crossroads", "glyph": "✕" },
		{ "name": "Eastmill", "pos": Vector3(6400, 0, 1200), "kind": "mill", "glyph": "✦" },
		{ "name": "Friar's Ford", "pos": Vector3(-4200, 0, -1800), "kind": "ford", "glyph": "≈" },
	]
	for lm in landmarks:
		var c: Vector3 = lm["pos"]
		var gy := _terrain_height(c.x, c.z)
		var mk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(46, 34, 46)
		mk.mesh = bm
		mk.position = c + Vector3(0, gy + 17, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.58, 0.54, 0.48)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mk.material_override = mat
		add_child(mk)
		var lb := Label3D.new()
		lb.text = "%s %s" % [lm["glyph"], lm["name"]]
		lb.font_size = 150
		lb.pixel_size = 0.085
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.modulate = Color(0.80, 0.74, 0.62)
		lb.position = c + Vector3(0, gy + 38, 0)
		add_child(lb)
		# defensible places become ground the armies will fight to hold
		if String(lm["kind"]) in ["ruin", "bridge", "church", "tower"]:
			strong_points.append({ "pos": c, "kind": String(lm["kind"]), "name": String(lm["name"]), "holder": -1 })

# the points the armies want to HOLD — woods (cover/ambush) and hilltops
# (observation/command of the ground). Settlements are separate (capture goals).
func _build_strong_points() -> void:
	for gr in _grove_list():
		strong_points.append({ "pos": gr[0], "kind": "woods", "name": "the woods", "holder": -1 })
	for h in hills:
		strong_points.append({ "pos": h["pos"], "kind": "hill", "name": h["name"], "holder": -1 })

# command posts — one army, two division, four brigade per side, posted behind
# their formations and sending couriers up and down the chain
func _spawn_hqs() -> void:
	for h in hqs:
		if h.node != null:
			h.node.queue_free()
	hqs.clear()
	for f in range(2):
		_make_hq(f, 0, 0, "%s — Army HQ" % FACTION_NAMES[f])
		for dv in range(DIVS_PER_SIDE):
			_make_hq(f, 1, dv, "%d%s Division HQ" % [dv + 1, _ord(dv + 1)])
		for bd in range(DIVS_PER_SIDE * BDES_PER_DIV):
			_make_hq(f, 2, bd, "%d%s Brigade HQ" % [bd + 1, _ord(bd + 1)])

func _make_hq(f: int, level: int, idx: int, name: String) -> void:
	var hq := HQ.new()
	hq.faction = f
	hq.level = level
	hq.idx = idx
	hq.name = name
	hq.pos = _hq_anchor(hq)
	hq.courier_cd = randf_range(8.0, 22.0)
	# a flat command-post marker: a faction diamond with a lighter inner diamond,
	# bigger for higher command — reads clearly from the top-down map
	var node := Node3D.new()
	var size: float = [230.0, 165.0, 120.0][level]
	var plate := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.orientation = PlaneMesh.FACE_Y
	plate.mesh = pm
	plate.rotation.y = PI * 0.25      # a diamond
	plate.position = Vector3(0, 9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FACTION_COLS[f]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate.material_override = mat
	node.add_child(plate)
	var inner := MeshInstance3D.new()
	var ipm := PlaneMesh.new()
	ipm.size = Vector2(size * 0.58, size * 0.58)
	ipm.orientation = PlaneMesh.FACE_Y
	inner.mesh = ipm
	inner.rotation.y = PI * 0.25
	inner.position = Vector3(0, 10, 0)
	var imat := StandardMaterial3D.new()
	imat.albedo_color = FACTION_COLS[f].lightened(0.45)
	imat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner.material_override = imat
	node.add_child(inner)
	node.position = hq.pos
	add_child(node)
	hq.node = node
	var lb := Label3D.new()
	lb.text = ["★ ", "✦ ", ""][level] + name
	lb.font_size = [200, 150, 120][level]
	lb.pixel_size = 0.11
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.modulate = FACTION_COLS[f].lightened(0.35)
	lb.position = Vector3(0, size * 0.4 + 22.0, 0)
	node.add_child(lb)
	hq.label = lb
	hqs.append(hq)

# where a command post sits: behind the centroid of the units it commands
func _hq_anchor(hq: HQ) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for t in tokens:
		if t.faction != hq.faction:
			continue
		if hq.level == 0 or (hq.level == 1 and t.division == hq.idx) or (hq.level == 2 and t.brigade == hq.idx):
			c += t.pos
			n += 1
	if n == 0:
		return settlements[_cap_idx(hq.faction)].pos
	c /= float(n)
	var rear := 1.0 if hq.faction == 0 else -1.0      # the rear is toward your own base (−/＋z)
	return c + Vector3(0, 0, rear * (180.0 + (2 - hq.level) * 120.0))

# a NATO-style infantry counter: a coloured field framed in ink with the crossed
# diagonals (infantry) and two echelon ticks (II = battalion) along the top
func _nato_infantry_tex(field: Color, ink: Color) -> ImageTexture:
	var w := 200
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(field)
	var b := 9                                   # frame thickness
	img.fill_rect(Rect2i(0, 0, w, b), ink)
	img.fill_rect(Rect2i(0, h - b, w, b), ink)
	img.fill_rect(Rect2i(0, 0, b, h), ink)
	img.fill_rect(Rect2i(w - b, 0, b, h), ink)
	var th := 7                                  # the infantry X
	for x in range(b, w - b):
		var fr := float(x - b) / float(w - 2 * b)
		var y1 := b + int(fr * float(h - 2 * b))
		var y2 := h - 1 - y1
		for dy in range(-th, th + 1):
			_putpx(img, x, y1 + dy, ink)
			_putpx(img, x, y2 + dy, ink)
	# echelon: II (battalion) centred above the frame
	img.fill_rect(Rect2i(w / 2 - 16, 2, 6, b - 2), ink)
	img.fill_rect(Rect2i(w / 2 + 10, 2, 6, b - 2), ink)
	return ImageTexture.create_from_image(img)

func _putpx(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func _build_pools() -> void:
	# units are drawn as NATO MAP COUNTERS, not figures: a faction-coloured infantry
	# symbol on a base plate (the base is gold for your own battalion)
	const MAX_COUNTERS := 60         # up to 48 battalions a side now, with headroom
	for f in range(2):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var plate := PlaneMesh.new()
		plate.size = Vector2(120, 76)          # the NATO counter, lying flat, north-up
		plate.orientation = PlaneMesh.FACE_Y
		mm.mesh = plate
		mm.instance_count = MAX_COUNTERS
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _nato_infantry_tex(FACTION_COLS[f], Color(0.06, 0.06, 0.09))
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # crisp at any light
		mi.material_override = mat
		add_child(mi)
		men_mm[f] = mm
		var fm := MultiMesh.new()
		fm.transform_format = MultiMesh.TRANSFORM_3D
		fm.use_colors = true                   # per-counter base tint (gold = you)
		var bplate := PlaneMesh.new()
		bplate.size = Vector2(140, 92)          # the base plate / affiliation border
		bplate.orientation = PlaneMesh.FACE_Y
		fm.mesh = bplate
		fm.instance_count = MAX_COUNTERS
		var fmi := MultiMeshInstance3D.new()
		fmi.multimesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.vertex_color_use_as_albedo = true
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmi.material_override = fmat
		add_child(fmi)
		flag_mm[f] = fm
	# a label pool — unit name + strength floating over each counter
	for k in range(MAX_COUNTERS * 2):
		var lb := Label3D.new()
		lb.font_size = 110
		lb.pixel_size = 0.16
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.outline_size = 24
		lb.visible = false
		add_child(lb)
		token_labels.append(lb)
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
	dmi.visible = false               # wildlife/civilians/traffic are off the operational map
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
	cmi.visible = false
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
	# each side: an army of DIVS×BDES×BNS battalions, deployed out of its capital toward
	# the centre of the province — divisions in depth, brigades across the frontage
	var nbde_total := DIVS_PER_SIDE * BDES_PER_DIV
	for f in range(2):
		var cap_pos: Vector3 = settlements[_cap_idx(f)].pos
		var towards := (Vector3.ZERO - cap_pos).normalized()
		var rightv := Vector3(towards.z, 0, -towards.x)
		for dv in range(DIVS_PER_SIDE):
			for bd in range(BDES_PER_DIV):
				var bg := dv * BDES_PER_DIV + bd
				for k in range(BNS_PER_BDE):
					var t := Token.new()
					t.id = next_id
					next_id += 1
					t.faction = f
					t.division = dv
					t.brigade = bg
					var n := bg * BNS_PER_BDE + k + 1
					t.name = "%d%s %s" % [n, _ord(n), "of Foot" if f == 0 else "Provincials"]
					t.experience = randf_range(0.85, 1.2)
					t.skills = _roll_token_skills(t.experience)
					t.facing_col = (FACINGS_0 if f == 0 else FACINGS_1)[bg % 6]
					t.coat_idx = 1 if k == BNS_PER_BDE - 1 else 0
					# brigades across the front, battalions clumped, divisions stacked in depth
					var front := (float(bg) - (nbde_total - 1) * 0.5) * 280.0 + (float(k) - (BNS_PER_BDE - 1) * 0.5) * 64.0
					var depth := 240.0 + float(dv) * 240.0
					t.pos = cap_pos + rightv * front + towards * depth + Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
					tokens.append(t)
	fac_aggr = [randf_range(0.4, 0.8), randf_range(0.4, 0.8)]   # the two commanders' temperaments
	# the player takes the lead battalion of the Crown's first brigade
	player_tok = tokens[0]
	player_tok.is_player = true
	player_tok.name = "1st of Foot (yours)"
	# the militia you raised on the intro screen: its name and its facing colour
	if GameConfig.has_militia:
		player_tok.name = "%s (yours)" % GameConfig.militia_name
		player_tok.facing_col = GameConfig.militia_facing
	_build_token_roster(player_tok)

const SKILL_KEYS := ["reload", "aim", "melee", "discipline", "stamina"]
const SKILL_NAMES := { "reload": "Drill", "aim": "Marksmanship", "melee": "Bayonet",
	"discipline": "Discipline", "stamina": "Stamina" }

func _roll_token_skills(exp: float) -> Dictionary:
	var base := clampf(34.0 + (exp - 1.0) * 70.0 + randf_range(-8.0, 8.0), 20.0, 88.0)
	var d := {}
	for key in SKILL_KEYS:
		d[key] = clampf(base + randf_range(-12.0, 12.0), 6.0, 99.0)
	var star: String = SKILL_KEYS[randi() % SKILL_KEYS.size()]
	d[star] = clampf(float(d[star]) + randf_range(8.0, 16.0), 6.0, 99.0)
	return d

func _skill_avg(sk: Dictionary) -> float:
	if sk.is_empty():
		return 50.0
	var s := 0.0
	for key in SKILL_KEYS:
		s += float(sk.get(key, 50.0))
	return s / float(SKILL_KEYS.size())

func _quality_word(sk: Dictionary) -> String:
	var a := _skill_avg(sk)
	if a >= 84.0: return "elite"
	if a >= 70.0: return "veteran"
	if a >= 56.0: return "seasoned"
	if a >= 40.0: return "regular"
	return "green"

# ------------------------------------------------------------------ the roster
const ROSTER_COYS := 6
const RANK_RISE := { "Pte.": "Cpl.", "Cpl.": "Sgt.", "Sgt.": "Lt.", "Lt.": "Capt." }
const RANK_FALL := { "Capt.": "Lt.", "Lt.": "Sgt.", "Sgt.": "Cpl.", "Cpl.": "Pte." }
const RANK_LIFT := { "Capt.": 16.0, "Lt.": 12.0, "Sgt.": 9.0, "Cpl.": 5.0, "Pte.": 0.0 }
const RANK_ORDER := { "Pte.": 0, "Cpl.": 1, "Sgt.": 2, "Lt.": 3, "Capt.": 4 }
const _FORENAMES := ["Richard", "James", "William", "Henry", "George", "Thomas", "Charles", "Edward",
	"Francis", "Samuel", "Daniel", "John", "Hugh", "Robert", "Isaac", "Joseph", "Patrick", "Owen"]
const _SURNAMES := ["Sharpe", "Harper", "Cooper", "Vane", "Frost", "Mercer", "Slade", "Burke", "Hale",
	"Croft", "Brand", "Doyle", "Reed", "Ward", "Pike", "Tanner", "Rourke", "Gale", "Webb", "Holt",
	"Lowe", "Fenn", "Sully", "Bell", "Mason", "Coltrane", "Maguire", "Brand", "Hagman", "Perkins"]

func _rand_person() -> String:
	return "%s %s" % [_FORENAMES[randi() % _FORENAMES.size()], _SURNAMES[randi() % _SURNAMES.size()]]

# Build the player's named roster — the men who lead and stand out, by company. Their
# skills scatter around the battalion's profile; the commissioned captains take their
# companies. (The rank and file beyond these are the company's unnamed strength.)
func _build_token_roster(t: Token) -> void:
	t.roster.clear()
	t.company_names.clear()
	for coy in range(ROSTER_COYS):
		t.company_names.append("%d Coy" % (coy + 1))
		for r in ["Lt.", "Sgt.", "Sgt.", "Cpl.", "Cpl.", "Cpl.", "Pte.", "Pte.", "Pte.", "Pte."]:
			var man := { "name": _rand_person(), "rank": r, "coy": coy, "focus": "" }
			for key in SKILL_KEYS:
				man[key] = clampf(float(t.skills.get(key, 50.0)) + float(RANK_LIFT[r]) + randf_range(-12.0, 12.0), 6.0, 99.0)
			t.roster.append(man)
	if GameConfig.has_militia and not GameConfig.militia_officers.is_empty():
		for coy in range(ROSTER_COYS):
			if coy >= GameConfig.militia_officers.size():
				break
			for m in t.roster:
				if int(m["coy"]) == coy and String(m["rank"]) == "Lt.":
					m["name"] = String(GameConfig.militia_officers[coy]["name"])
					m["discipline"] = clampf(float(GameConfig.militia_officers[coy]["skill"]), 6.0, 99.0)
					break

func _man_avg(m: Dictionary) -> float:
	var s := 0.0
	for key in SKILL_KEYS:
		s += float(m[key])
	return s / float(SKILL_KEYS.size())

func _spawn_life() -> void:
	for s in settlements:
		for k in range(2 + s.size * 2):
			civs.append({ "home": settlements.find(s), "pos": s.pos + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)), "tgt": s.pos })
	for k in range(80):
		var p := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * WORLD_SIZE * 0.42
		deer.append({ "pos": p, "tgt": p, "flee": 0.0 })

var player_marker: Label3D

func _update_marker() -> void:
	if player_marker == null:
		player_marker = Label3D.new()
		player_marker.font_size = 200
		player_marker.pixel_size = 0.06
		player_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		player_marker.modulate = Color(1.0, 0.92, 0.4)
		player_marker.no_depth_test = true
		add_child(player_marker)
	if player_tok == null or ride_mode:    # in third person you ARE the marker
		player_marker.visible = false
		return
	player_marker.visible = true
	player_marker.text = "▼ YOU" + ("   ⚔ CONTACT — the lines are forming" if pending != null else "")
	player_marker.position = player_tok.pos + Vector3(0, _terrain_height(player_tok.pos.x, player_tok.pos.z) + 120, 0)

var cam_height := 2600.0          # how high the map camera floats (wheel zooms)
var cam_focus := Vector3.ZERO      # the ground point the camera looks down at

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.far = 20000.0
	cam_pitch = -1.4                 # near top-down, so the map reads flat
	add_child(cam)
	_place_map_cam()

# keep the camera floating above its focus point at the current height/pitch
func _place_map_cam() -> void:
	var back := cam_height / tan(-cam_pitch)        # ground distance behind the focus
	var offset := Vector3(0, cam_height, back).rotated(Vector3.UP, cam_yaw)
	cam.position = cam_focus + offset
	cam.rotation = Vector3(cam_pitch, cam_yaw, 0)

func _center_on(p: Vector3) -> void:
	cam_focus = Vector3(p.x, 0, p.z)
	_place_map_cam()

# the player's mounted officer — the same dark-bay charger he rides in battle,
# now carrying him across the whole province in third person
func _build_officer() -> void:
	officer = Node3D.new()
	add_child(officer)
	var horse := MeshInstance3D.new()
	var hc := CapsuleMesh.new()
	hc.radius = 0.34
	hc.height = 1.95
	hc.radial_segments = 8
	horse.mesh = hc
	horse.rotation.z = PI * 0.5            # lay the body horizontal
	horse.position = Vector3(0, 0.95, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.20, 0.13, 0.08)
	horse.material_override = hmat
	officer.add_child(horse)
	var neck := MeshInstance3D.new()
	var nc := CapsuleMesh.new()
	nc.radius = 0.16
	nc.height = 1.0
	neck.mesh = nc
	neck.rotation.x = 0.7
	neck.position = Vector3(0, 1.35, 0.85)
	neck.material_override = hmat
	officer.add_child(neck)
	var rider := MeshInstance3D.new()
	var rc := CapsuleMesh.new()
	rc.radius = 0.22
	rc.height = 1.1
	rider.mesh = rc
	rider.position = Vector3(0, 1.85, -0.1)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = FACTION_COLS[0].darkened(0.1)   # your faction's coat
	rider.material_override = rmat
	officer.add_child(rider)
	var hat := MeshInstance3D.new()
	var hatc := CylinderMesh.new()
	hatc.top_radius = 0.0
	hatc.bottom_radius = 0.2
	hatc.height = 0.32
	hat.mesh = hatc
	hat.position = Vector3(0, 2.62, -0.1)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.05, 0.06)
	hat.material_override = black
	officer.add_child(hat)

func _start_ride() -> void:
	if player_tok != null:
		off_pos = player_tok.pos
		off_yaw = 0.0 if player_tok.faction == 0 else PI   # face out into the field
	officer.position = off_pos
	cam.position = off_pos + Vector3(0, 6, -14)

func _update_ride(dt: float) -> void:
	if officer == null:
		return
	if not ride_mode or player_tok == null:
		officer.visible = false
		return
	officer.visible = true
	# rein and spur: A/D steer the horse, W/S the pace, Shift to canter
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		turn += 1.0
	if Input.is_physical_key_pressed(KEY_D):
		turn -= 1.0
	off_yaw += turn * RIDE_TURN * dt
	var top := RIDE_CANTER if Input.is_physical_key_pressed(KEY_SHIFT) else RIDE_WALK
	var want := 0.0
	if Input.is_physical_key_pressed(KEY_W):
		want = top
	elif Input.is_physical_key_pressed(KEY_S):
		want = -RIDE_WALK * 0.5
	off_speed = move_toward(off_speed, want, 9.0 * dt)
	var fwd := Vector3(sin(off_yaw), 0, cos(off_yaw))
	off_pos += fwd * off_speed * dt
	off_pos.x = clampf(off_pos.x, -WORLD_SIZE * 0.5, WORLD_SIZE * 0.5)
	off_pos.z = clampf(off_pos.z, -WORLD_SIZE * 0.5, WORLD_SIZE * 0.5)
	gait_t += dt * (8.0 if off_speed > RIDE_WALK + 0.5 else 4.5) * clampf(absf(off_speed) / RIDE_WALK, 0.0, 1.5)
	var bob := absf(sin(gait_t)) * 0.10 * clampf(absf(off_speed) / RIDE_WALK, 0.0, 1.0)
	officer.position = off_pos + Vector3(0, bob, 0)
	officer.rotation.y = off_yaw
	# you ARE your battalion's location: your 700 men march where you ride
	player_tok.pos = off_pos
	player_tok.dir = fwd
	if player_tok.state == "fight":
		# ride clear of the enemy and the stand-off breaks
		if player_tok.enemy == null or off_pos.distance_to(player_tok.enemy.pos) > ENGAGE_RANGE * 1.4:
			player_tok.state = "hold"
			player_tok.enemy = null
			pending = null
	else:
		player_tok.state = "hold"
		player_tok.path = []
	# free-look eases back to straight ahead while riding hard
	if off_speed > 1.0:
		look_yaw = move_toward(look_yaw, 0.0, dt * 1.5)

func _ride_camera(delta: float) -> void:
	if officer == null:
		return
	var yaw := off_yaw + look_yaw
	var back := Vector3(sin(yaw), 0, cos(yaw))
	var want := off_pos - back * 11.0 + Vector3(0, 4.6 - look_pitch * 6.0, 0)
	cam.position = cam.position.lerp(want, clampf(delta * 6.0, 0, 1))
	cam.look_at(off_pos + Vector3(0, 2.3, 0) + back * 2.0, Vector3.UP)

var orders_lbl: RichTextLabel
var controls_lbl: Label
# the camp & command screen — managed only at a town (the operational rest stop)
var _camp_on := false
var camp_panel: Control
var camp_label: RichTextLabel
var _train_idx := -1
# the deep roster — companies, every named man, with per-soldier and per-company actions
var _roster_on := false
var roster_panel: Control
var _rlist: VBoxContainer
var _rdetail: VBoxContainer
var _rsel_kind := ""              # "soldier" | "company" | ""
var _rsel_coy := -1
var _rsel_man := -1
# the depot shop — spend prestige on supplies when halted at a friendly magazine
var _depot_on := false
var depot_panel: Control
var depot_list: VBoxContainer
var depot_head: RichTextLabel
const CAMP_REST_RATE := 4.0       # fatigue shed per game-hour-scaled second while encamped at a town
const CAMP_TRAIN_RATE := 0.5      # skill gained per scaled second drilling at a town

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	ui_layer = ui
	# top status bar
	var bar := ColorRect.new()
	bar.color = Color(0.06, 0.07, 0.10, 0.72)
	bar.anchor_right = 1.0
	bar.offset_bottom = 80
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bar)
	hud = RichTextLabel.new()
	hud.bbcode_enabled = true
	hud.scroll_active = false
	hud.position = Vector2(16, 8)
	hud.size = Vector2(1400, 28)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	# the orders banner, just under the bar
	orders_lbl = RichTextLabel.new()
	orders_lbl.bbcode_enabled = true
	orders_lbl.scroll_active = false
	orders_lbl.fit_content = true
	orders_lbl.position = Vector2(16, 48)
	orders_lbl.size = Vector2(900, 28)
	orders_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(orders_lbl)
	# the war diary, bottom-left
	feed = RichTextLabel.new()
	feed.bbcode_enabled = true
	feed.scroll_active = false
	feed.position = Vector2(14, 0)
	feed.anchor_top = 1.0
	feed.anchor_bottom = 1.0
	feed.offset_top = -184
	feed.offset_bottom = -12
	feed.custom_minimum_size = Vector2(640, 0)
	feed.size = Vector2(640, 172)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(feed)
	# controls hint, bottom-right, dim
	controls_lbl = Label.new()
	controls_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	controls_lbl.add_theme_font_size_override("font_size", 12)
	controls_lbl.anchor_top = 1.0
	controls_lbl.anchor_bottom = 1.0
	controls_lbl.anchor_left = 1.0
	controls_lbl.anchor_right = 1.0
	controls_lbl.offset_left = -520
	controls_lbl.offset_top = -26
	controls_lbl.offset_right = -12
	controls_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls_lbl.text = "click: march · WASD: pan · wheel: zoom · Space: centre · C: camp · R: roster · B: depot · 1/2/3: speed · Esc: menu"
	ui.add_child(controls_lbl)
	_build_camp_ui(ui)
	_build_roster_ui(ui)
	_build_depot_ui(ui)

# The camp & command screen — a big overview of your battalion, opened only at a town.
func _build_camp_ui(ui: CanvasLayer) -> void:
	camp_panel = Control.new()
	camp_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	camp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camp_panel.visible = false
	ui.add_child(camp_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.06, 0.9)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camp_panel.add_child(dim)
	var pc := PanelContainer.new()
	pc.anchor_left = 0.5
	pc.anchor_right = 0.5
	pc.anchor_top = 0.5
	pc.anchor_bottom = 0.5
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10, 0.97)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(24)
	pc.add_theme_stylebox_override("panel", sb)
	camp_panel.add_child(pc)
	camp_label = RichTextLabel.new()
	camp_label.bbcode_enabled = true
	camp_label.fit_content = true
	camp_label.scroll_active = false
	camp_label.custom_minimum_size = Vector2(620, 0)
	camp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camp_label.add_theme_font_size_override("normal_font_size", 15)
	camp_label.add_theme_font_size_override("bold_font_size", 19)
	pc.add_child(camp_label)

# The settlement you can encamp at: one of your own (or a neutral) towns you are standing
# in, not on the march or in a fight. -1 if you must move to a town first.
func _at_town() -> int:
	if player_tok == null or player_tok.state != "hold":
		return -1
	for i in range(settlements.size()):
		if settlements[i].owner == 1 - player_tok.faction:
			continue                         # not the enemy's
		if player_tok.pos.distance_to(settlements[i].pos) < CAPTURE_RANGE + 60.0:
			return i
	return -1

func _drill_key() -> String:
	if _train_idx < 0 or _train_idx >= SKILL_KEYS.size():
		return ""
	return SKILL_KEYS[_train_idx]

# While you hold at a town, the men rest (fatigue falls) and drill (the chosen skill
# climbs) — passively, whether or not the camp screen is open.
func _update_camp(dt: float) -> void:
	if player_tok == null:
		return
	if _at_town() >= 0:
		player_tok.fatigue = maxf(0.0, player_tok.fatigue - CAMP_REST_RATE * dt)
		var key := _drill_key()
		if key != "" and player_tok.skills.has(key):
			player_tok.skills[key] = minf(95.0, float(player_tok.skills[key]) + CAMP_TRAIN_RATE * dt)
		# per-soldier focus training (set in the roster): each focused man hones his own
		# skill, and collectively the company's drill lifts the battalion's profile
		for m in player_tok.roster:
			var fk := String(m["focus"])
			if fk != "" and fk in SKILL_KEYS:
				m[fk] = minf(99.0, float(m[fk]) + CAMP_TRAIN_RATE * dt * 0.9)
				player_tok.skills[fk] = minf(95.0, float(player_tok.skills.get(fk, 50.0)) + CAMP_TRAIN_RATE * dt * 0.05)
	if _camp_on:
		_refresh_camp()

func _toggle_camp() -> void:
	if player_tok == null:
		return
	# the overview opens anywhere on the campaign map; resting and drill only progress
	# once you HALT at one of your towns (the camp itself)
	_camp_on = not _camp_on
	if camp_panel != null:
		camp_panel.visible = _camp_on
	if _camp_on:
		if _at_town() < 0:
			_event("[color=#ffcf6e]Reviewing the battalion — halt at a town to rest and drill the men.[/color]")
		_refresh_camp()

func _cbar(v: float, width: int) -> String:
	var filled := clampi(int(round(v / 100.0 * float(width))), 0, width)
	var col := "9fe0a0" if v >= 66.0 else ("ffcf6e" if v >= 40.0 else "ff9a8a")
	return "[color=#%s]%s[/color][color=#33394a]%s[/color]" % [col, "█".repeat(filled), "█".repeat(width - filled)]

func _fat_word(f: float) -> String:
	if f < 20.0: return "[color=#9fe0a0]fresh[/color]"
	if f < 45.0: return "[color=#cfe08a]winded[/color]"
	if f < 70.0: return "[color=#ffcf6e]weary[/color]"
	if f < 90.0: return "[color=#ff9a8a]flagging[/color]"
	return "[color=#ff5a4a]blown[/color]"

func _refresh_camp() -> void:
	if camp_label == null or player_tok == null:
		return
	var t := player_tok
	var dash := "[color=#3f4658]————————————————————————————[/color]\n"
	var town := _at_town()
	var townname: String = settlements[town].name if town >= 0 else "—"
	var s := "[center][b][color=#ffd773]CAMP & COMMAND[/color][/b]   [color=#9fb0c8]at %s[/color][/center]\n" % townname
	s += "[b][color=#ffe9a8]%s[/color][/b]   [color=#9fb0c8](%s)[/color]\n" % [t.name, _quality_word(t.skills)]
	s += "[color=#cdd6e6]%d men · nerve %d · experience ×%.2f[/color]\n" % [int(t.men), int(round(t.morale)), t.experience]
	s += dash
	s += "[b][color=#bcd6ff]SKILLS[/color][/b]\n"
	for key in SKILL_KEYS:
		var v := float(t.skills.get(key, 50.0))
		var drill: String = "   [color=#ffe08a]‹ drilling[/color]" if _drill_key() == key else ""
		s += "[color=#cdd6e6]%s[/color]  %s  [color=#e8ecf5]%d[/color]%s\n" % [SKILL_NAMES[key], _cbar(v, 14), int(round(v)), drill]
	s += dash
	s += "[color=#cdd6e6]Fatigue[/color]  %s  %s\n" % [_cbar(t.fatigue, 14), _fat_word(t.fatigue)]
	if town >= 0:
		s += "[color=#9fe0a0]● Encamped — the men rest%s.[/color]\n" % ("" if _drill_key() == "" else " and drill " + str(SKILL_NAMES[_drill_key()]))
	else:
		s += "[color=#ff9a8a]● On the march — halt at a town to rest and drill.[/color]\n"
	s += dash
	var tw: String = str(SKILL_NAMES[_drill_key()]) if _drill_key() != "" else "none"
	s += "[color=#ffe9a8][T][/color] drill: %s   [color=#ffe9a8][P][/color] promote   [color=#ffe9a8][R][/color] full roster   [color=#ffe9a8][C][/color] close" % tw
	camp_label.text = s

func _camp_train() -> void:
	_train_idx = (_train_idx + 1) % (SKILL_KEYS.size() + 1)
	_refresh_camp()

func _camp_promote() -> void:
	if player_tok == null:
		return
	var d := float(player_tok.skills.get("discipline", 50.0))
	if d >= 90.0:
		_event("[color=#9fb0c8]Your NCOs are already first-rate.[/color]")
		return
	player_tok.skills["discipline"] = minf(90.0, d + 2.5)
	player_tok.experience = minf(1.6, player_tok.experience + 0.015)
	_event("[color=#9fe0a0]You commission steady men from the ranks — discipline improves.[/color]")
	_refresh_camp()

# ===================================================== THE ROSTER (companies & men)
func _build_roster_ui(ui: CanvasLayer) -> void:
	roster_panel = Control.new()
	roster_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	roster_panel.visible = false
	ui.add_child(roster_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.06, 0.93)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP    # the roster eats clicks (no marching behind)
	roster_panel.add_child(dim)
	var pc := PanelContainer.new()
	pc.anchor_left = 0.5; pc.anchor_right = 0.5; pc.anchor_top = 0.5; pc.anchor_bottom = 0.5
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10, 0.99)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20)
	pc.add_theme_stylebox_override("panel", sb)
	roster_panel.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pc.add_child(vb)
	var title := Label.new()
	title.text = "THE ROSTER"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	vb.add_child(title)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	vb.add_child(hb)
	var lsc := ScrollContainer.new()
	lsc.custom_minimum_size = Vector2(430, 520)
	hb.add_child(lsc)
	_rlist = VBoxContainer.new()
	_rlist.custom_minimum_size = Vector2(410, 0)
	lsc.add_child(_rlist)
	_rdetail = VBoxContainer.new()
	_rdetail.custom_minimum_size = Vector2(360, 520)
	_rdetail.add_theme_constant_override("separation", 7)
	hb.add_child(_rdetail)
	var foot := Label.new()
	foot.text = "click a company or a man   ·   Esc / R — close"
	foot.add_theme_color_override("font_color", Color(0.6, 0.64, 0.72))
	vb.add_child(foot)

func _open_roster() -> void:
	if player_tok == null:
		return
	if player_tok.roster.is_empty():
		_build_token_roster(player_tok)
	_roster_on = not _roster_on
	roster_panel.visible = _roster_on
	if _roster_on:
		_refresh_roster()

func _rbar(v: float, w: int) -> String:
	var fill := clampi(int(round(v / 100.0 * float(w))), 0, w)
	var col := "9fe0a0" if v >= 66.0 else ("ffcf6e" if v >= 40.0 else "ff9a8a")
	return "[color=#%s]%s[/color][color=#33394a]%s[/color]" % [col, "█".repeat(fill), "█".repeat(w - fill)]

func _r_select(kind: String, coy: int, man: int) -> void:
	_rsel_kind = kind; _rsel_coy = coy; _rsel_man = man
	_refresh_roster()

func _refresh_roster() -> void:
	if _rlist == null or player_tok == null:
		return
	for c in _rlist.get_children():
		c.queue_free()
	for coy in range(player_tok.company_names.size()):
		var men: Array = []
		for mi in range(player_tok.roster.size()):
			if int(player_tok.roster[mi]["coy"]) == coy:
				men.append(mi)
		var ch := Button.new()
		ch.text = "▸  %s   [%d named]" % [player_tok.company_names[coy], men.size()]
		ch.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ch.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
		if _rsel_kind == "company" and _rsel_coy == coy:
			ch.modulate = Color(1.0, 0.96, 0.7)
		var cc := coy
		ch.pressed.connect(func(): _r_select("company", cc, -1))
		_rlist.add_child(ch)
		men.sort_custom(func(a, b): return int(RANK_ORDER[player_tok.roster[a]["rank"]]) > int(RANK_ORDER[player_tok.roster[b]["rank"]]))
		for mi in men:
			var m: Dictionary = player_tok.roster[mi]
			var b := Button.new()
			var foc: String = "  ◎" if String(m["focus"]) != "" else ""
			b.text = "      %s %s   ·   %d%s" % [m["rank"], m["name"], int(_man_avg(m)), foc]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if _rsel_kind == "soldier" and _rsel_man == mi:
				b.modulate = Color(1.0, 0.96, 0.7)
			var mm: int = mi
			var mcoy: int = coy
			b.pressed.connect(func(): _r_select("soldier", mcoy, mm))
			_rlist.add_child(b)
	_refresh_detail()

func _refresh_detail() -> void:
	for c in _rdetail.get_children():
		c.queue_free()
	if _rsel_kind == "soldier" and _rsel_man >= 0 and _rsel_man < player_tok.roster.size():
		_build_soldier_detail()
	elif _rsel_kind == "company" and _rsel_coy >= 0:
		_build_company_detail()
	else:
		var l := Label.new()
		l.text = "Select a company or a soldier."
		l.add_theme_color_override("font_color", Color(0.6, 0.64, 0.72))
		_rdetail.add_child(l)

func _r_btn(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	_rdetail.add_child(b)

func _build_soldier_detail() -> void:
	var m: Dictionary = player_tok.roster[_rsel_man]
	var hdr := Label.new()
	hdr.text = "%s %s" % [m["rank"], m["name"]]
	hdr.add_theme_font_size_override("font_size", 18)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_rdetail.add_child(hdr)
	var ne := LineEdit.new()
	ne.text = String(m["name"])
	ne.placeholder_text = "rename…"
	ne.text_submitted.connect(func(s: String):
		var nm: String = s.strip_edges()
		if nm != "":
			m["name"] = nm
			_event("[color=#bcd]%s is now known to the regiment.[/color]" % nm)
		_refresh_roster())
	_rdetail.add_child(ne)
	var sk := RichTextLabel.new()
	sk.bbcode_enabled = true
	sk.fit_content = true
	sk.custom_minimum_size = Vector2(350, 0)
	var tx := ""
	for key in SKILL_KEYS:
		var v := float(m[key])
		var foc: String = "  [color=#ffe08a]‹ focus[/color]" if String(m["focus"]) == key else ""
		tx += "[color=#cdd6e6]%s[/color]  %s  [color=#e8ecf5]%d[/color]%s\n" % [SKILL_NAMES[key], _rbar(v, 12), int(v), foc]
	sk.text = tx
	_rdetail.add_child(sk)
	var ff: String = SKILL_NAMES[m["focus"]] if String(m["focus"]) != "" else "none"
	_r_btn("⬆  Promote", _r_promote)
	_r_btn("⬇  Demote", _r_demote)
	_r_btn("◎  Focus training: %s" % ff, _r_focus)

func _build_company_detail() -> void:
	var coy := _rsel_coy
	var hdr := Label.new()
	hdr.text = String(player_tok.company_names[coy])
	hdr.add_theme_font_size_override("font_size", 18)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_rdetail.add_child(hdr)
	var ne := LineEdit.new()
	ne.text = String(player_tok.company_names[coy])
	ne.placeholder_text = "rename the company…"
	ne.text_submitted.connect(func(s: String):
		var nm: String = s.strip_edges()
		if nm != "":
			player_tok.company_names[coy] = nm
		_refresh_roster())
	_rdetail.add_child(ne)
	# company averages + current drill
	var sums := {}
	for key in SKILL_KEYS:
		sums[key] = 0.0
	var cnt := 0
	var curfoc := ""
	for m in player_tok.roster:
		if int(m["coy"]) == coy:
			cnt += 1
			if String(m["focus"]) != "":
				curfoc = String(m["focus"])
			for key in SKILL_KEYS:
				sums[key] += float(m[key])
	var sk := RichTextLabel.new()
	sk.bbcode_enabled = true
	sk.fit_content = true
	sk.custom_minimum_size = Vector2(350, 0)
	var tx := ""
	for key in SKILL_KEYS:
		var v: float = sums[key] / float(maxi(1, cnt))
		tx += "[color=#cdd6e6]%s[/color]  %s  [color=#e8ecf5]%d[/color]\n" % [SKILL_NAMES[key], _rbar(v, 12), int(v)]
	sk.text = tx
	_rdetail.add_child(sk)
	var df: String = SKILL_NAMES[curfoc] if curfoc != "" else "stood down"
	_r_btn("◎  Assign drill: %s" % df, _r_coy_train)
	_r_btn("💬  Speak to the officers", _r_speak)

func _r_promote() -> void:
	if _rsel_kind != "soldier":
		return
	var m: Dictionary = player_tok.roster[_rsel_man]
	var nr: String = RANK_RISE.get(m["rank"], "")
	if nr == "":
		_event("[color=#9fb0c8]He can rise no higher in this battalion.[/color]")
		return
	m["rank"] = nr
	m["discipline"] = clampf(float(m["discipline"]) + 4.0, 6.0, 99.0)
	player_tok.skills["discipline"] = minf(95.0, float(player_tok.skills.get("discipline", 50.0)) + 0.5)
	_event("[color=#9fe0a0]%s raised to %s.[/color]" % [m["name"], nr])
	_refresh_roster()

func _r_demote() -> void:
	if _rsel_kind != "soldier":
		return
	var m: Dictionary = player_tok.roster[_rsel_man]
	var nr: String = RANK_FALL.get(m["rank"], "")
	if nr == "":
		_event("[color=#9fb0c8]He is already in the ranks.[/color]")
		return
	m["rank"] = nr
	m["discipline"] = clampf(float(m["discipline"]) - 3.0, 6.0, 99.0)
	player_tok.skills["discipline"] = maxf(10.0, float(player_tok.skills.get("discipline", 50.0)) - 0.4)
	_event("[color=#ffcf6e]%s reduced to %s.[/color]" % [m["name"], nr])
	_refresh_roster()

func _r_focus() -> void:
	if _rsel_kind != "soldier":
		return
	var m: Dictionary = player_tok.roster[_rsel_man]
	var idx := SKILL_KEYS.find(String(m["focus"]))
	idx = (idx + 1) % (SKILL_KEYS.size() + 1)
	m["focus"] = "" if idx >= SKILL_KEYS.size() else SKILL_KEYS[idx]
	_refresh_roster()

func _r_coy_train() -> void:
	var coy := _rsel_coy
	var cur := ""
	for m in player_tok.roster:
		if int(m["coy"]) == coy and String(m["focus"]) != "":
			cur = String(m["focus"]); break
	var idx := SKILL_KEYS.find(cur)
	idx = (idx + 1) % (SKILL_KEYS.size() + 1)
	var nf: String = "" if idx >= SKILL_KEYS.size() else SKILL_KEYS[idx]
	for m in player_tok.roster:
		if int(m["coy"]) == coy:
			m["focus"] = nf
	_event("[color=#bcd]%s set to drill %s.[/color]" % [player_tok.company_names[coy], (SKILL_NAMES[nf] if nf != "" else "nothing — stood down")])
	_refresh_roster()

func _r_speak() -> void:
	var coy := _rsel_coy
	var lt := "the captain"
	for m in player_tok.roster:
		if int(m["coy"]) == coy and (String(m["rank"]) == "Lt." or String(m["rank"]) == "Capt."):
			lt = String(m["name"]); break
	var remarks := ["reports the men in good heart.", "asks for more powder and shot.",
		"complains the marching has worn the boots through.", "vouches for his sergeants.",
		"begs leave to drill the recruits harder.", "says the company will not yield an inch."]
	_event("[color=#bcd]Lt. %s of %s %s[/color]" % [lt, player_tok.company_names[coy], remarks[randi() % remarks.size()]])

# ===================================================== THE DEPOT SHOP (prestige)
const DEPOT_ITEMS := [
	{ "name": "Draft of recruits", "note": "+90 men (greener, dilutes the regiment)", "cost": 25, "sup": 25 },
	{ "name": "Powder & shot", "note": "the drill tightens — Drill +", "cost": 12, "sup": 12 },
	{ "name": "New muskets from the armoury", "note": "Marksmanship +", "cost": 35, "sup": 20 },
	{ "name": "Full rations", "note": "the men fed and rested", "cost": 10, "sup": 10 },
	{ "name": "A draft of veterans", "note": "experience and every skill +", "cost": 45, "sup": 28 },
	{ "name": "A new stand of colours", "note": "Discipline and nerve +", "cost": 30, "sup": 14 },
]

func _build_depot_ui(ui: CanvasLayer) -> void:
	depot_panel = Control.new()
	depot_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	depot_panel.visible = false
	ui.add_child(depot_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.06, 0.93)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	depot_panel.add_child(dim)
	var pc := PanelContainer.new()
	pc.anchor_left = 0.5; pc.anchor_right = 0.5; pc.anchor_top = 0.5; pc.anchor_bottom = 0.5
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10, 0.99)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(22)
	pc.add_theme_stylebox_override("panel", sb)
	depot_panel.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(520, 0)
	pc.add_child(vb)
	var title := Label.new()
	title.text = "THE MAGAZINE"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	vb.add_child(title)
	depot_head = RichTextLabel.new()
	depot_head.bbcode_enabled = true
	depot_head.fit_content = true
	depot_head.custom_minimum_size = Vector2(500, 0)
	vb.add_child(depot_head)
	depot_list = VBoxContainer.new()
	depot_list.add_theme_constant_override("separation", 5)
	vb.add_child(depot_list)
	var foot := Label.new()
	foot.text = "Esc / B — leave the magazine"
	foot.add_theme_color_override("font_color", Color(0.6, 0.64, 0.72))
	vb.add_child(foot)

func _open_depot() -> void:
	if player_tok == null:
		return
	var dep = _nearest_friendly_depot(player_tok.pos, player_tok.faction)
	if dep == null and not _depot_on:
		_event("[color=#ffcf6e]Halt within reach of one of your magazines to draw supplies.[/color]")
		return
	_depot_on = not _depot_on
	depot_panel.visible = _depot_on
	if _depot_on:
		_refresh_depot()

func _refresh_depot() -> void:
	if depot_list == null or player_tok == null:
		return
	var dep = _nearest_friendly_depot(player_tok.pos, player_tok.faction)
	depot_head.text = "[color=#cdd6e6]%s[/color]\n[color=#ffd24a]Prestige: %d[/color]   ·   [color=#bcd]Depot stores: %d%%[/color]" % [
		player_tok.name, player_prestige, int(dep.supply) if dep != null else 0]
	for c in depot_list.get_children():
		c.queue_free()
	for i in range(DEPOT_ITEMS.size()):
		var it: Dictionary = DEPOT_ITEMS[i]
		var afford: bool = player_prestige >= int(it["cost"]) and dep != null and dep.supply >= float(it["sup"])
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s   —   %d ★ / %d stores\n      %s" % [it["name"], int(it["cost"]), int(it["sup"]), it["note"]]
		b.disabled = not afford
		var ii := i
		b.pressed.connect(func(): _buy_item(ii))
		depot_list.add_child(b)

func _buy_item(i: int) -> void:
	var dep = _nearest_friendly_depot(player_tok.pos, player_tok.faction)
	if dep == null:
		return
	var it: Dictionary = DEPOT_ITEMS[i]
	if player_prestige < int(it["cost"]) or dep.supply < float(it["sup"]):
		return
	player_prestige -= int(it["cost"])
	dep.supply -= float(it["sup"])
	_apply_item(i)
	_event("[color=#9fe0a0]Drawn from the magazine:[/color] %s." % it["name"])
	_refresh_depot()

func _apply_item(i: int) -> void:
	var t := player_tok
	match i:
		0:  # recruits — strength up, the regiment a touch greener
			t.men = minf(800.0, t.men + 90.0)
			for key in SKILL_KEYS:
				t.skills[key] = lerpf(float(t.skills.get(key, 50.0)), 40.0, 0.07)
		1:  # powder & shot
			t.skills["reload"] = minf(95.0, float(t.skills.get("reload", 50.0)) + 5.0)
		2:  # new muskets
			t.skills["aim"] = minf(95.0, float(t.skills.get("aim", 50.0)) + 8.0)
		3:  # rations
			t.fatigue = 0.0
			t.skills["stamina"] = minf(95.0, float(t.skills.get("stamina", 50.0)) + 3.0)
		4:  # veterans
			t.experience = minf(1.7, t.experience + 0.05)
			for key in SKILL_KEYS:
				t.skills[key] = minf(95.0, float(t.skills.get(key, 50.0)) + 4.0)
		5:  # colours
			t.skills["discipline"] = minf(95.0, float(t.skills.get("discipline", 50.0)) + 6.0)
			t.morale = minf(100.0, t.morale + 10.0)

# ------------------------------------------------------------------ the war

func _process(delta: float) -> void:
	anim_t += delta
	var dt := delta * tscale
	clock += dt / 3600.0          # REAL TIME: one game hour per real hour
	if clock >= 24.0:
		clock -= 24.0
		day += 1
	_update_sun()
	_update_factions(dt)
	_update_tokens(dt)
	_update_capture(dt)
	_update_strong_points()
	_update_hqs(dt)
	_update_couriers(dt)
	_update_depots(dt)
	# (wildlife/civilians/road traffic are disabled on the operational map)
	if player_tok != null:
		objective_si = fac_goal[player_tok.faction]   # your army's main effort = your orders
	# meeting the enemy forms a battle on its own — no keypress. March clear before the
	# dwell elapses to slip the engagement; hold contact and the lines lock and zoom in.
	if player_tok == null or player_tok.state != "fight":
		pending = null
		contact_t = 0.0
	elif pending != null:
		contact_t += delta
		if contact_t > CONTACT_DELAY:
			_inflate(pending)
			return
	_render_tokens()
	_render_settlements()
	_update_marker()
	_update_hud()
	_update_camp(dt)
	_cam_move(delta)

func _update_sun() -> void:
	pass   # the map is flat-lit (unshaded); the clock still turns but the paper never dims

# the operational appreciation: each faction periodically scores the settlements
# (value x feasibility, hysteresis on the standing objective) and points its idle
# brigades — the same evaluator pattern as the battle AI, one level up
# How many men of a faction stand within a radius of a point (an estimate of force there).
func _strength_near(pos: Vector3, f: int, radius: float) -> float:
	var s := 0.0
	for t in tokens:
		if t.faction == f and t.state != "rout" and t.pos.distance_to(pos) < radius:
			s += t.men
	return s

# THE OPERATIONAL APPRECIATION (refined). Each commander, on his own clock:
#  1. picks an OBJECTIVE town weighing value, nearness, and how WEAKLY it is held;
#  2. checks whether any of his OWN towns is being rushed and needs covering;
#  3. tasks his two divisions — the first carries the main effort onto the objective,
#     the second exploits alongside if he is bold, or peels off to DEFEND if a town is
#     in real danger. Temperament (cautious..bold) colours every weighing.
func _update_factions(dt: float) -> void:
	for f in range(2):
		fac_cd[f] -= dt
		if fac_cd[f] > 0.0:
			continue
		fac_cd[f] = 36.0
		var enemy := 1 - f
		var aggr: float = fac_aggr[f]
		# (1) the main objective: value × weakness ÷ distance, biased by temperament
		var best := -1
		var bs := -1.0
		for si in range(settlements.size()):
			var s := settlements[si]
			if s.owner == f:
				continue
			var v := float(s.size) * (1.7 if s.owner == enemy else 1.05)
			var d := _fac_center(f).distance_to(s.pos)
			var def := _strength_near(s.pos, enemy, 700.0)
			var weak := 1.0 / (1.0 + def / 1300.0)          # a weakly-held town is the prize
			var sc := v * weak / (1.0 + d / 2600.0)
			sc *= lerpf(0.82, 1.25, aggr)                    # bold armies prize the offensive
			if si == fac_goal[f]:
				sc += 0.45                                   # hysteresis: commit, don't dither
			if sc > bs:
				bs = sc
				best = si
		if best != -1 and best != fac_goal[f]:
			fac_goal[f] = best
			_event("%s make their main effort against [b]%s[/b]." % [FACTION_NAMES[f], settlements[best].name])
		var goal_pos: Vector3 = settlements[fac_goal[f]].pos if fac_goal[f] >= 0 else settlements[_cap_idx(f)].pos
		# (2) the threat: our most endangered town (enemy strength bearing on it, ours short)
		var threat_si := -1
		var worst := 0.0
		for si in range(settlements.size()):
			if settlements[si].owner != f:
				continue
			var en := _strength_near(settlements[si].pos, enemy, 2400.0)
			var ours := _strength_near(settlements[si].pos, f, 1300.0)
			var danger := en - ours * lerpf(0.7, 1.3, aggr)
			if en > 350.0 and danger > worst:
				worst = danger
				threat_si = si
		# (3) task the divisions: lead attacks; the second defends a threatened town when the
		# danger is real (or the commander is cautious), else it presses alongside the lead
		var nbde := DIVS_PER_SIDE * BDES_PER_DIV
		for bg in range(nbde):
			var dv := bg / BDES_PER_DIV
			var aim_town := goal_pos
			var directive := 0
			if dv == 1 and threat_si >= 0 and (worst > 650.0 or aggr < 0.5):
				aim_town = settlements[threat_si].pos        # the second division covers home
				directive = 1
			div_dir[f * DIVS_PER_SIDE + dv] = directive
			var bts: Array = []
			for t in tokens:
				if t.faction == f and t.brigade == bg and not t.is_player and t.state in ["hold", "march"]:
					bts.append(t)
			if bts.is_empty():
				continue
			var bc := Vector3.ZERO
			for t in bts:
				bc += t.pos
			bc /= float(bts.size())
			var lateral := (float(bg % BDES_PER_DIV) - (BDES_PER_DIV - 1) * 0.5) * 720.0
			var aim := aim_town + Vector3(lateral, 0, 0)
			# attacking brigades peel onto nearby high ground/woods; defenders sit on the town
			if directive == 0:
				var sp = _nearest_strong_point(bc, f)
				if sp != null and bc.distance_to(sp["pos"]) < 1500.0:
					aim = sp["pos"]
			for i in range(bts.size()):
				var t: Token = bts[i]
				var off := Vector3((float(i) - (bts.size() - 1) * 0.5) * 170.0, 0, 0)
				t.dest = aim + off
				t.has_dest = true
				if t.state == "hold":
					t.state = "march"
		_check_war_end()

# The campaign is decided when a side is swept from the field or loses every town.
func _check_war_end() -> void:
	if _war_over:
		return
	for f in range(2):
		var live := 0
		var towns := 0
		for t in tokens:
			if t.faction == f and t.state != "rout":
				live += 1
		for s in settlements:
			if s.owner == f:
				towns += 1
		if live == 0 or towns == 0:
			_war_over = true
			var winner := 1 - f
			_event("[color=#ffd24a][b]THE CAMPAIGN IS DECIDED[/b] — %s have broken the enemy and hold the province.[/color]" % FACTION_NAMES[winner])
			return

# ===================================================== THE SUPPLY ECONOMY (depots)
const DEPOT_TARGET := 3            # magazines a side aims to hold
const DEPOT_DECAY := 0.22         # supply drawn down per game-second (the army eats)
const DEPOT_CONVOY_AT := 50.0     # send a waggon train when a depot falls below this
const DEPOT_REFILL := 55.0        # supply a convoy delivers
const CONVOY_SPEED := 26.0
const DEPOT_USE_RANGE := 300.0    # how near you must halt to trade at a depot

func _depot_at(si: int):
	for d in depots:
		if d.si == si:
			return d
	return null

func _convoy_enroute(dep) -> bool:
	for c in convoys:
		if c.depot == dep:
			return true
	return false

func _nearest_friendly_depot(pos: Vector3, f: int):
	var best = null
	var bd := DEPOT_USE_RANGE
	for d in depots:
		if d.faction != f:
			continue
		var dist := pos.distance_to(d.pos)
		if dist < bd:
			bd = dist; best = d
	return best

# The AI founds magazines behind its lines, decays their stock, and runs waggon trains
# up from the capital to keep them filled — the supplies the player draws on.
func _update_depots(dt: float) -> void:
	for f in range(2):
		depot_cd[f] -= dt
		if depot_cd[f] <= 0.0:
			depot_cd[f] = randf_range(70.0, 150.0)
			_maybe_found_depot(f)
	for i in range(depots.size() - 1, -1, -1):
		var d = depots[i]
		if d.si >= 0 and settlements[d.si].owner != d.faction:
			_event("[color=#caa]A magazine at %s falls to the enemy.[/color]" % settlements[d.si].name)
			if d.node != null: d.node.queue_free()
			if d.label != null: d.label.queue_free()
			depots.remove_at(i)
			continue
		d.supply = maxf(0.0, d.supply - DEPOT_DECAY * dt)
		if d.label != null:
			d.label.text = "▮ Depot — %s\n%d%% stocked" % [settlements[d.si].name, int(d.supply)]
	# run convoys to the neediest depot of each side
	for f in range(2):
		for d in depots:
			if d.faction == f and d.supply < DEPOT_CONVOY_AT and not _convoy_enroute(d):
				_spawn_convoy(f, d)
				break
	for i in range(convoys.size() - 1, -1, -1):
		var c = convoys[i]
		if c.depot == null or not (c.depot in depots):
			if c.node != null: c.node.queue_free()
			convoys.remove_at(i)
			continue
		var to: Vector3 = c.depot.pos - c.pos
		var dist := to.length()
		if dist < 70.0:
			c.depot.supply = minf(100.0, c.depot.supply + DEPOT_REFILL)
			if c.node != null: c.node.queue_free()
			convoys.remove_at(i)
			continue
		c.pos += to / dist * CONVOY_SPEED * dt
		if c.node != null:
			c.node.position = c.pos + Vector3(0, 18, 0)

func _maybe_found_depot(f: int) -> void:
	var have := 0
	for d in depots:
		if d.faction == f:
			have += 1
	if have >= DEPOT_TARGET:
		return
	# the largest, least-threatened owned town that has no depot yet
	var best := -1
	var bs := -1.0e30
	for si in range(settlements.size()):
		var s := settlements[si]
		if s.owner != f or _depot_at(si) != null:
			continue
		var threat := _strength_near(s.pos, 1 - f, 2200.0)
		var sc := float(s.size) * 130.0 - threat * 0.08
		if sc > bs:
			bs = sc; best = si
	if best < 0:
		return
	var dep := Depot.new()
	dep.faction = f
	dep.si = best
	dep.pos = settlements[best].pos + Vector3(60, 0, 60)
	dep.supply = 65.0
	dep.node = _make_depot_node(f)
	dep.node.position = dep.pos
	add_child(dep.node)
	dep.label = Label3D.new()
	dep.label.font_size = 120
	dep.label.pixel_size = 0.12
	dep.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dep.label.modulate = FACTION_COLS[f].lightened(0.4)
	dep.label.position = dep.pos + Vector3(0, 46, 0)
	add_child(dep.label)
	depots.append(dep)
	_event("[color=#bcd]%s establish a magazine at [b]%s[/b].[/color]" % [FACTION_NAMES[f], settlements[best].name])

func _make_depot_node(f: int) -> Node3D:
	var n := Node3D.new()
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(70, 40, 70)
	box.mesh = bm
	box.position = Vector3(0, 20, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = FACTION_COLS[f].lerp(Color(0.4, 0.34, 0.2), 0.5)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material_override = m
	n.add_child(box)
	return n

func _spawn_convoy(f: int, dep) -> void:
	var c := Convoy.new()
	c.faction = f
	c.depot = dep
	c.pos = settlements[_cap_idx(f)].pos
	var n := Node3D.new()
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(26, 16, 40)
	box.mesh = bm
	box.position = Vector3(0, 8, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.42, 0.28)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material_override = m
	n.add_child(box)
	n.position = c.pos + Vector3(0, 18, 0)
	add_child(n)
	c.node = n
	convoys.append(c)

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

# marching is faster on a road: how much, by proximity to the nearest road
func _road_factor(pos: Vector3) -> float:
	var best := 1e18
	for r in roads:
		best = minf(best, _pt_seg_dist(pos, settlements[r[0]].pos, settlements[r[1]].pos))
		if best < 60.0:
			break
	if best < 90.0:
		return 1.8
	if best < 240.0:
		return 1.3
	return 1.0

func _pt_seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
	var proj := a + ab * tt
	return Vector2(p.x - proj.x, p.z - proj.z).length()

# the nearest strong point this faction does not already hold
func _nearest_strong_point(pos: Vector3, f: int):
	var best = null
	var bd := 1e18
	for sp in strong_points:
		if sp["holder"] == f:
			continue
		var d: float = pos.distance_squared_to(sp["pos"])
		if d < bd:
			bd = d
			best = sp
	return best

# a strong point is held by whoever has a battalion sitting on it
func _update_strong_points() -> void:
	for sp in strong_points:
		var here := [false, false]
		for t in tokens:
			if t.state != "rout" and t.pos.distance_to(sp["pos"]) < 420.0:
				here[t.faction] = true
		if here[0] != here[1]:
			sp["holder"] = 0 if here[0] else 1

func _place_name(pos: Vector3) -> String:
	var best := "the open ground"
	var bd := 1e18
	for s in settlements:
		var d: float = pos.distance_squared_to(s.pos)
		if d < bd:
			bd = d
			best = s.name
	for sp in strong_points:
		var d2: float = pos.distance_squared_to(sp["pos"])
		if d2 < bd:
			bd = d2
			best = sp["name"]
	return best

# ----------------------------------------------------- command posts & couriers

func _update_hqs(dt: float) -> void:
	for hq in hqs:
		hq.pos = hq.pos.lerp(_hq_anchor(hq), clampf(dt * 0.4, 0, 1))
		if hq.node != null:
			hq.node.position = hq.pos
		hq.courier_cd -= dt
		if hq.courier_cd <= 0.0:
			hq.courier_cd = randf_range(14.0, 30.0)
			_dispatch_courier(hq)

func _dispatch_courier(hq: HQ) -> void:
	var f := hq.faction
	var obj: String = settlements[fac_goal[f]].name if fac_goal[f] >= 0 else "the front"
	if hq.level == 0:                         # army -> a division
		var subs := _hq_subs(f, 1, -1)
		if not subs.is_empty():
			_spawn_courier(hq, subs[randi() % subs.size()], "Army HQ: press the advance — objective %s." % obj, false)
	elif hq.level == 1:                       # division -> one of its brigades
		var dsubs := _hq_subs(f, 2, hq.idx)
		if not dsubs.is_empty():
			_spawn_courier(hq, dsubs[randi() % dsubs.size()], "%s: carry your sector forward." % hq.name, false)
	else:                                     # brigade -> a battalion (often the player)
		var bns: Array = []
		var pl = null
		for t in tokens:
			if t.faction == f and t.brigade == hq.idx:
				bns.append(t)
				if t.is_player:
					pl = t
		if bns.is_empty():
			return
		var tgt = bns[randi() % bns.size()]
		if pl != null and randf() < 0.6:
			tgt = pl
		var to_player: bool = tgt.is_player
		var msg := ""
		if to_player:
			msg = "Brigade HQ to the %s — advance in support of the attack on %s." % [tgt.name, obj]
			# do NOT pester the player with an order he already holds — only send when it changes
			if msg == _player_order_msg:
				return
			_player_order_msg = msg
		_spawn_courier(hq, tgt, msg, to_player)

func _hq_subs(f: int, level: int, div: int) -> Array:
	var out: Array = []
	for h in hqs:
		if h.faction == f and h.level == level and (div < 0 or (h.idx / BDES_PER_DIV) == div):
			out.append(h)
	return out

func _spawn_courier(from_hq: HQ, target, msg: String, to_player: bool) -> void:
	var c := Courier.new()
	c.faction = from_hq.faction
	c.pos = from_hq.pos
	c.target = target
	c.msg = msg
	c.to_player = to_player
	var node := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 16.0
	sph.height = 32.0
	node.mesh = sph
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.3) if to_player else FACTION_COLS[from_hq.faction].lightened(0.25)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = m
	node.position = c.pos + Vector3(0, 30, 0)
	add_child(node)
	c.node = node
	couriers.append(c)

func _update_couriers(dt: float) -> void:
	for i in range(couriers.size() - 1, -1, -1):
		var c: Courier = couriers[i]
		if c.target == null or not (c.target in hqs or c.target in tokens):
			c.node.queue_free()
			couriers.remove_at(i)
			continue
		var tp: Vector3 = c.target.pos
		var d := c.pos.distance_to(tp)
		if d < 90.0:
			if c.to_player and c.msg != "":
				_event("[color=#ffd24a]✉ Despatch:[/color] %s" % c.msg)
			c.node.queue_free()
			couriers.remove_at(i)
			continue
		c.pos += (tp - c.pos) / d * COURIER_SPEED * dt
		c.node.position = c.pos + Vector3(0, 30, 0)

func _update_tokens(dt: float) -> void:
	# movement and engagement — units march cross-country to a point, faster on roads
	for t in tokens:
		match t.state:
			"march", "rout":
				if not t.has_dest:
					t.state = "hold"
					continue
				var d := t.pos.distance_to(t.dest)
				if d < MARCH_ARRIVE:
					t.has_dest = false
					t.state = "hold"
					continue
				var base_sp := ROUT_SPEED if t.state == "rout" else MARCH_SPEED
				var sp := base_sp * (1.0 if t.state == "rout" else _road_factor(t.pos))
				t.dir = (t.dest - t.pos) / d
				# climbing high ground is slow going — the column toils up, then crests it
				var ahead := t.pos + t.dir * 45.0
				var climb := _terrain_height(ahead.x, ahead.z) - _terrain_height(t.pos.x, t.pos.z)
				if climb > 0.0:
					sp *= clampf(1.0 - climb * 0.022, 0.45, 1.0)
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
	# the player's own fights are NOT abstracted away — they hold, lines drawn up,
	# until he gives battle (F, which inflates to the full tactical sim) or marches off
	if t.is_player or e.is_player:
		if player_tok != null and player_tok.state == "fight":
			pending = player_tok.enemy
		return
	t.men -= e.men * 0.0030 * e.experience * dt
	t.morale -= dt * (2.0 * e.men / maxf(t.men, 1.0)) * 0.55
	t.smoke_cd -= dt
	if t.smoke_cd <= 0.0:
		t.smoke_cd = 0.6
		smoke_p.emit_particle(Transform3D(Basis(), t.pos + Vector3(randf_range(-20, 20), 8, randf_range(-20, 20))), Vector3(0, 1, 0), Color.WHITE, Color.WHITE, 5)
	if t.morale < 35.0:
		_rout_token(t)
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

# colour each town by who holds it; pulse the one you're ordered to take
func _render_settlements() -> void:
	for si in range(settlements.size()):
		var s := settlements[si]
		var col := Color(0.55, 0.55, 0.58)        # neutral
		if s.owner == 0:
			col = FACTION_COLS[0]
		elif s.owner == 1:
			col = FACTION_COLS[1]
		var disc := settlement_discs[si]
		var mat: StandardMaterial3D = disc.material_override
		if si == objective_si:
			var pulse := 0.5 + 0.5 * sin(anim_t * 4.0)
			mat.albedo_color = col.lerp(Color(1.0, 0.85, 0.2), 0.55)
			disc.scale = Vector3.ONE * (1.0 + 0.14 * pulse)
		else:
			mat.albedo_color = col
			disc.scale = Vector3.ONE
		settlement_labels[si].modulate = (Color(0.95, 0.95, 0.85) if s.owner < 0 else col.lightened(0.45))

# draw each battalion as a map counter (NATO symbol + base plate) with a label
func _render_tokens() -> void:
	var li := 0
	for f in range(2):
		var mm: MultiMesh = men_mm[f]
		var fm: MultiMesh = flag_mm[f]
		var i := 0
		for t in tokens:
			if t.faction != f:
				continue
			if i >= mm.instance_count:
				break
			# NATO counters stand north-up (not rotated to facing); a routing unit's
			# counter tilts to read as broken
			var basis := Basis()
			if t.state == "rout":
				basis = Basis(Vector3(0, 0, 1), 0.5)
			var gy := _terrain_height(t.pos.x, t.pos.z)   # ride up and over the high ground
			mm.set_instance_transform(i, Transform3D(basis, t.pos + Vector3(0, gy + 7, 0)))
			fm.set_instance_transform(i, Transform3D(Basis(), t.pos + Vector3(0, gy + 4, 0)))
			var base_col := Color(0.95, 0.8, 0.25) if t.is_player else (
				Color(0.85, 0.78, 0.66) if t.faction == 0 else Color(0.7, 0.74, 0.85))
			fm.set_instance_color(i, base_col)
			if li < token_labels.size():
				var lb := token_labels[li]
				lb.visible = true
				lb.text = "%s\n%d" % [t.name, int(t.men)]
				lb.modulate = Color(1, 0.95, 0.6) if t.is_player else Color(0.92, 0.92, 0.96)
				lb.position = t.pos + Vector3(0, gy + 60, 0)
				li += 1
			i += 1
		for j in range(i, mm.instance_count):
			mm.set_instance_transform(j, Transform3D().scaled(Vector3.ZERO))
			fm.set_instance_transform(j, Transform3D().scaled(Vector3.ZERO))
	for j in range(li, token_labels.size()):
		token_labels[j].visible = false

func _update_hud() -> void:
	var hold := [0, 0, 0]
	for s in settlements:
		hold[s.owner if s.owner >= 0 else 2] += 1
	var men := [0, 0]
	for t in tokens:
		men[t.faction] += int(t.men)
	var spd := "real time" if tscale <= 1.0 else "preview ×%d" % int(tscale)
	hud.text = "[b]Day %d[/b]   %02d:%02d   ·   [color=#7a93ea]%s[/color]  %d towns · %d men      [color=#d07068]%s[/color]  %d towns · %d men      [color=#8f98a8]· %s ·[/color]" % [
		day, int(clock), int(fposmod(clock, 1.0) * 60.0),
		FACTION_NAMES[0], hold[0], men[0], FACTION_NAMES[1], hold[1], men[1], spd]
	# the orders banner — the player's direction
	var ot := ""
	if pending != null:
		ot = "[color=#ff7a6a][b]⚔ ENEMY MET[/b] — the lines are forming.  March clear to slip away.[/color]"
	elif player_tok == null:
		ot = "[color=#caa6a0]Your battalion is no more — you observe the war.[/color]"
	elif objective_si >= 0:
		ot = "[color=#ffd24a][b]ORDERS:[/b][/color] the army's main effort is [b]%s[/b] — bring the %s up in support.    [color=#8f98a8]You: %d men[/color]" % [
			settlements[objective_si].name, player_tok.name, int(player_tok.men)]
	else:
		ot = "[color=#8f98a8]Awaiting orders from headquarters…    You: %s, %d men[/color]" % [player_tok.name, int(player_tok.men)]
	if player_tok != null and _at_town() >= 0 and pending == null:
		ot += "   [color=#9fe0a0][b]⛺ Encamped[/b] — [C] manage · [R] roster[/color]"
	if player_tok != null and pending == null and _nearest_friendly_depot(player_tok.pos, player_tok.faction) != null:
		ot += "   [color=#ffd24a][b]▮ Magazine in reach[/b] — press [B] to draw supplies[/color]"
	if player_tok != null:
		ot += "   [color=#ffd24a]· %d prestige[/color]" % player_prestige
	orders_lbl.text = ot

func _event(msg: String) -> void:
	feed_lines.append("[color=#8a93a6]Day %d %02d:%02d[/color]  %s" % [day, int(clock), int(fposmod(clock, 1.0) * 60.0), msg])
	if feed_lines.size() > 9:
		feed_lines.pop_front()
	if feed != null:
		feed.text = "\n".join(feed_lines)

# ------------------------------------------------------------------ free camera

# click the ground to march your battalion to the nearest settlement there
func _order_march(screen_pos: Vector2) -> void:
	if player_tok == null:
		return
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 1e-5:
		return
	var d := -from.y / dir.y
	if d <= 0.0:
		return
	var hit := from + dir * d
	player_tok.dest = Vector3(hit.x, 0, hit.z)   # march cross-country to the chosen ground
	player_tok.has_dest = true
	player_tok.state = "march"
	pending = null
	if player_tok.enemy != null:        # break off any stand-off
		player_tok.enemy = null
	_event("[color=#cfe]You march for %s.[/color]" % _place_name(player_tok.dest))

func _apply_cam() -> void:
	cam.rotation = Vector3(cam_pitch, cam_yaw, 0)

# pan and zoom the operational map
func _cam_move(delta: float) -> void:
	if follow and player_tok != null:        # keep your battalion centred
		cam_focus = cam_focus.lerp(Vector3(player_tok.pos.x, 0, player_tok.pos.z), clampf(delta * 3.0, 0, 1))
		_place_map_cam()
		return
	var sp := (cam_height / 2600.0) * (2200.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 950.0)
	var fwd := -Vector3(sin(cam_yaw), 0, cos(cam_yaw))   # screen-up across the ground
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var pan := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		pan += fwd
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		pan -= fwd
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		pan += right
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		pan -= right
	if pan.length_squared() > 0.0:
		cam_focus += pan.normalized() * sp * delta
		var lim := WORLD_SIZE * 0.5
		cam_focus.x = clampf(cam_focus.x, -lim, lim)
		cam_focus.z = clampf(cam_focus.z, -lim, lim)
		_place_map_cam()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				_order_march(ev.position)
			MOUSE_BUTTON_WHEEL_UP:
				cam_height = clampf(cam_height - 450.0, 600.0, 12000.0)
				_place_map_cam()
			MOUSE_BUTTON_WHEEL_DOWN:
				cam_height = clampf(cam_height + 450.0, 600.0, 12000.0)
				_place_map_cam()
	elif ev is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cam_yaw -= ev.relative.x * 0.005       # drag right-mouse to rotate the map
		_place_map_cam()
	elif ev is InputEventKey and ev.pressed:
		# the roster screen captures Esc/R while open (its buttons handle the mouse)
		if _roster_on:
			if ev.physical_keycode == KEY_R or ev.physical_keycode == KEY_ESCAPE:
				_roster_on = false
				roster_panel.visible = false
			return
		if _depot_on:
			if ev.physical_keycode == KEY_B or ev.physical_keycode == KEY_ESCAPE:
				_depot_on = false
				depot_panel.visible = false
			return
		# the camp screen captures its own keys while it is open
		if _camp_on:
			match ev.physical_keycode:
				KEY_C, KEY_ESCAPE:
					_camp_on = false
					if camp_panel != null:
						camp_panel.visible = false
				KEY_T:
					_camp_train()
				KEY_P:
					_camp_promote()
				KEY_R:
					_camp_on = false
					if camp_panel != null:
						camp_panel.visible = false
					_open_roster()             # straight from camp into the deep roster
			return
		match ev.physical_keycode:
			KEY_SPACE:                         # centre on your battalion
				follow = not follow
				if follow and player_tok != null:
					_center_on(player_tok.pos)
			KEY_C:
				_toggle_camp()                 # camp & command — only at a town
			KEY_R:
				_open_roster()                 # the roster — companies and men
			KEY_B:
				_open_depot()                  # buy supplies at a friendly magazine
			KEY_1:
				tscale = 1.0
			KEY_2:
				tscale = 8.0
			KEY_3:
				tscale = 30.0
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://menu.tscn")

# ------------------------------------------------------------ inflation (Phase 2)

# Give battle: the nearby tokens on both sides are authored into a BattleSetup and
# the full tactical sim is summoned from them. The world is frozen and stowed in
# the autoload so it survives the scene change and resumes when the day is decided.
func _inflate(foe: Token) -> void:
	var R := 1400.0                      # gather a wider clash — whole brigades meet now
	var friends: Array = []
	var foes: Array = []
	for t in tokens:
		if t.state == "rout":
			continue
		if t.faction == player_tok.faction and t.pos.distance_to(player_tok.pos) < R:
			friends.append(t)
		elif t.faction == foe.faction and t.pos.distance_to(foe.pos) < R:
			foes.append(t)
	friends.erase(player_tok)            # the player always leads, never sliced out
	friends.push_front(player_tok)
	foes.erase(foe)
	foes.push_front(foe)
	friends = friends.slice(0, 30)       # up to 30 battalions a side — the sim-LOD gate keeps
	foes = foes.slice(0, 30)             # the distant wings cheap while the near fight runs full
	var s := BattleSetup.new()
	s.seed_value = randi() | 1
	s.weather = "clear"
	s.time_of_day = clock
	GameConfig.battle_tokens = []
	var idx := 0
	var player_idx := 0
	var player_local := Vector3.ZERO   # the player batt's authored spot, so we can land it under you
	for side in [[friends, 0, 0.0, -200.0], [foes, 1, PI, 200.0]]:
		var lst: Array = side[0]
		var team: int = side[1]
		var face: float = side[2]
		var zline: float = side[3]
		for i in range(lst.size()):
			var t: Token = lst[i]
			var u := BattleSetup.BattUnit.new()
			u.name = t.name
			u.team = team
			u.men = int(t.men)
			u.experience = t.experience
			u.morale = t.morale
			u.skills = t.skills.duplicate()
			u.fatigue = t.fatigue
			u.facing_col = t.facing_col
			u.coat_idx = t.coat_idx
			u.brigade = t.brigade
			u.facing = face
			# deploy in a block — rows of battalions stacked in depth — not one vast line
			var per_row := 10
			var col := i % per_row
			var row := i / per_row
			var fx := (float(col) - (per_row - 1) * 0.5) * 120.0
			var fz := zline + float(row) * (-150.0 if team == 0 else 150.0)
			u.pos = Vector3(fx, 0, fz)
			if t == player_tok:
				u.human_slot = idx
				player_idx = idx
				player_local = u.pos
			s.units.append(u)
			GameConfig.battle_tokens.append(t.id)
			idx += 1
	GameConfig.setup = s
	GameConfig.local_slot = player_idx
	GameConfig.return_to_world = true              # the battle returns here when decided
	GameConfig.world_state = _serialize_world()    # the province survives the battle
	_event("You give battle! %d battalions against %d. Zooming to the field…" % [friends.size(), foes.size()])
	# ZOOM INTO THE BATTLE: the campaign map's natural transition is a scene change to
	# the full third-person tactical sim, which writes results back into world_state.
	get_tree().change_scene_to_file("res://game.tscn")

# hide the province's props (houses, woods, fields, roads, marching figures, deer,
# civilians) so they don't poke through a hosted battle — but KEEP the ground, since
# the battle is gated to render on the world's terrain. Restored when the battle ends.
func _hide_props(hidden: bool) -> void:
	for ch in get_children():
		if ch == ground_mi or ch == battle_sim:
			continue
		if ch is MeshInstance3D or ch is MultiMeshInstance3D:
			ch.visible = not hidden
	for c in carts:
		if c.node != null:
			c.node.visible = not hidden

# the embedded battle has resolved and been dismissed: fold the result into the
# province, tear the battle down, and hand control back to the saddle
func _end_hosted_battle() -> void:
	_apply_battle_result()        # casualties / rout / destruction back into the tokens
	if battle_sim != null and is_instance_valid(battle_sim):
		battle_sim.queue_free()
	battle_sim = null
	in_battle = false
	pending = null
	contact_t = 0.0
	_hide_props(false)            # the province's props return
	if officer != null:
		officer.visible = true
	if ui_layer != null:
		ui_layer.visible = true
	if cam != null:
		cam.current = true        # take the camera back from the battle
	if player_tok != null:
		off_pos = player_tok.pos
		off_speed = 0.0
		ride_mode = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		ride_mode = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_event("You return to the saddle.")

func _serialize_world() -> Dictionary:
	var ts: Array = []
	for t in tokens:
		ts.append({ "id": t.id, "name": t.name, "fac": t.faction, "men": t.men,
			"exp": t.experience, "mor": t.morale, "px": t.pos.x, "pz": t.pos.z,
			"brig": t.brigade, "div": t.division, "state": t.state,
			"fr": t.facing_col.r, "fg": t.facing_col.g, "fb": t.facing_col.b,
			"coat": t.coat_idx, "pl": t.is_player, "sk": t.skills, "ft": t.fatigue,
			"ros": t.roster, "coyn": t.company_names })
	var ss: Array = []
	for s in settlements:
		ss.append({ "owner": s.owner, "cap": s.cap_t })
	var ds: Array = []
	for d in depots:
		ds.append({ "f": d.faction, "si": d.si, "sup": d.supply })
	return { "tokens": ts, "sett": ss, "clock": clock, "day": day,
		"goal": fac_goal.duplicate(), "next_id": next_id,
		"prestige": player_prestige, "depots": ds }

func _restore_world(d: Dictionary) -> void:
	tokens.clear()
	for td in d.get("tokens", []):
		var t := Token.new()
		t.id = int(td["id"])
		t.name = td["name"]
		t.faction = int(td["fac"])
		t.men = float(td["men"])
		t.experience = float(td["exp"])
		t.morale = float(td["mor"])
		t.pos = Vector3(td["px"], 0, td["pz"])
		t.brigade = int(td["brig"])
		t.division = int(td.get("div", 0))
		t.state = "hold"              # re-tasked by the AI on the next appreciation
		t.facing_col = Color(td["fr"], td["fg"], td["fb"])
		t.coat_idx = int(td["coat"])
		t.is_player = bool(td["pl"])
		t.skills = td.get("sk", {})
		if (t.skills as Dictionary).is_empty():
			t.skills = _roll_token_skills(t.experience)
		t.fatigue = float(td.get("ft", 0.0))
		t.roster = td.get("ros", [])
		t.company_names = td.get("coyn", [])
		if t.is_player:
			player_tok = t
			if (t.roster as Array).is_empty():
				_build_token_roster(t)
		tokens.append(t)
	var ss: Array = d.get("sett", [])
	for i in range(mini(ss.size(), settlements.size())):
		settlements[i].owner = int(ss[i]["owner"])
		settlements[i].cap_t = float(ss[i]["cap"])
	clock = float(d.get("clock", 7.0))
	day = int(d.get("day", 1))
	fac_goal = d.get("goal", [-1, -1])
	next_id = int(d.get("next_id", tokens.size() + 1))
	player_prestige = int(d.get("prestige", player_prestige))
	for dd in d.get("depots", []):
		var si := int(dd["si"])
		if si < 0 or si >= settlements.size():
			continue
		var dep := Depot.new()
		dep.faction = int(dd["f"])
		dep.si = si
		dep.pos = settlements[si].pos + Vector3(60, 0, 60)
		dep.supply = float(dd["sup"])
		dep.node = _make_depot_node(dep.faction)
		dep.node.position = dep.pos
		add_child(dep.node)
		dep.label = Label3D.new()
		dep.label.font_size = 120
		dep.label.pixel_size = 0.12
		dep.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		dep.label.modulate = FACTION_COLS[dep.faction].lightened(0.4)
		dep.label.position = dep.pos + Vector3(0, 46, 0)
		add_child(dep.label)
		depots.append(dep)

# fold the battle's outcome back into the province: casualties, who broke, who held
func _apply_battle_result() -> void:
	var res: Dictionary = {}
	if GameConfig.setup != null:
		res = GameConfig.setup.result
	var bt: Array = GameConfig.battle_tokens
	var by_id := {}
	for t in tokens:
		by_id[t.id] = t
	var seen := {}
	for rec in res.get("survivors", []):
		var si := int(rec["idx"])
		if si < 0 or si >= bt.size():
			continue
		var tid: int = bt[si]
		seen[tid] = true
		if by_id.has(tid):
			var t: Token = by_id[tid]
			t.men = float(rec["men"])
			t.morale = float(rec["morale"])
			var rsk: Dictionary = rec.get("skills", {})
			if not rsk.is_empty():
				t.skills = rsk.duplicate()        # drill and blooding from the fight carry home
			t.fatigue = float(rec.get("fatigue", t.fatigue))
			if rec.get("state", "") == "routing" or t.men < 60.0:
				_rout_token(t)
	# any battle participant not in the survivor list was destroyed
	for tid in bt:
		if not seen.has(tid) and by_id.has(tid):
			var t2: Token = by_id[tid]
			if t2 != null:
				_event("[color=#caa]%s was destroyed in the battle.[/color]" % t2.name)
				tokens.erase(t2)
	var winner: int = res.get("winner", -1)   # battle team: 0 = your faction, 1 = enemy
	var gained := int(res.get("prestige", 0))
	if gained != 0:
		player_prestige = maxi(0, player_prestige + gained)   # renown banked, to spend at a depot
		_event("[color=#ffd24a]You bank %+d prestige[/color] for the day's work (now %d)." % [gained, player_prestige])
	_event("[color=#9fe0a0]The field is decided.[/color] %s held the ground." % (
		"Your side" if winner == 0 else "The enemy"))
	GameConfig.world_state = {}               # consumed; next battle re-stows
	GameConfig.return_to_world = false
	follow = true
	if player_tok == null or not tokens.has(player_tok):
		_event("[color=#ff8] Your battalion is no more. You watch the war as a free camera.[/color]")
		player_tok = null
		follow = false

func _rout_token(t: Token) -> void:
	t.state = "rout"
	t.dest = settlements[_cap_idx(t.faction)].pos   # flee for home
	t.has_dest = true
	t.enemy = null

func _ord(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "th"
	match n % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
	return "th"
