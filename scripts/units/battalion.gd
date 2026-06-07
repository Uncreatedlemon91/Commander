extends Node2D
class_name Battalion

# A battalion. The SIMULATION (position, strength, morale, firing, melee) always
# runs and is cheap — strength is just a number. The VISUALS (individual soldier
# shapes) are only spawned while the unit is near the camera, and despawned when
# it leaves. So off-screen units keep fighting and the AI keeps working, but we
# only pay for thousands of shapes where the player is actually looking.

enum Morale { STEADY, SHAKEN, ROUTING, DESTROYED }

var id: int = 0
var team: int = 0
var game_manager: Node = null

var unit_name: String = "Battalion"
var unit_type: String = "infantry"     # infantry | cavalry | artillery

var strength: int = 0
var max_strength: int = 0
var ammo: int = 50

var is_selected: bool = false
var formation_type: String = "line"    # line | column | attack_column | square
var skirmishers_deployed: bool = false

var facing_dir: Vector2 = Vector2.RIGHT
var target_position: Vector2

var morale: float = 100.0
var morale_state: Morale = Morale.STEADY
var fire_cd: float = 0.0
var skirm_cd: float = 0.0
var time_since_hit: float = 999.0

var in_melee: bool = false
var was_in_melee: bool = false
var melee_cd: float = 0.0
var charge_active: bool = false
var charge_timer: float = 0.0

# Networking (clients smooth toward host-authoritative position)
var net_target_pos: Vector2

# Visualization
var visualized: bool = false
var soldiers: Array[Soldier] = []
var officer: Soldier
var flag: Soldier
var musician: Soldier
var volley_shooters: Array = []
var volley_index: int = 0
var volley_timer: float = 0.0

var speech_text: String = ""
var speech_timer: float = 0.0

const SPACING := 4.0
const LINE_RANKS := 3
const VISUAL_CAP := 450
const VIEW_MARGIN := 360.0

const ROUT_SPEED := 22.0
const SKIRMISH_FRACTION := 0.25
const ADVANCE_DIST := 160.0
const SKIRMISH_FRONT := 95.0
const SKIRMISH_SPACING := 9.0
const SKIRMISH_RANGE := 160.0

const FIRE_ARC := 0.9
const MORALE_PER_CASUALTY := 0.5
const MORALE_SUPPRESSION := 2.0
const MORALE_RECOVER := 3.0
const MAX_MORALE := 100.0

const MELEE_DIST := 42.0
const MELEE_INTERVAL := 1.0
const MELEE_LETHALITY := 0.03
const MELEE_MORALE := 3.0
const CHARGE_SHOCK := 18.0
const CHARGE_DURATION := 6.0
const AUTO_WHEEL_RATE := 0.7
const WHEEL_STEP := 0.5236
const SPEECH_TIME := 3.0

# ---------------------------------------------------------------- type stats

func base_strength() -> int:
	match unit_type:
		"cavalry": return 140
		"artillery": return 90
	return 300

func move_speed_base() -> float:
	match unit_type:
		"cavalry": return 26.0
		"artillery": return 7.0
	return 12.0

func charge_speed() -> float:
	if unit_type == "cavalry":
		return 42.0
	return 24.0

func musket_range() -> float:
	match unit_type:
		"artillery": return 420.0
		"cavalry": return 0.0
	return 180.0

func fire_interval() -> float:
	if unit_type == "artillery":
		return 6.0
	return 5.0

func can_shoot() -> bool:
	return unit_type != "cavalry"

func type_melee_factor() -> float:
	match unit_type:
		"cavalry": return 2.0
		"artillery": return 0.25
	return 1.0

# ---------------------------------------------------------------- lifecycle

func _ready() -> void:
	facing_dir = Vector2.RIGHT if team == 0 else Vector2.LEFT
	max_strength = base_strength()
	strength = max_strength
	target_position = global_position
	net_target_pos = global_position

func is_authority() -> bool:
	return game_manager == null or game_manager.authoritative

func _process(delta: float) -> void:
	if speech_timer > 0.0:
		speech_timer -= delta

	if is_authority():
		time_since_hit += delta
		update_charge(delta)
		update_morale(delta)
		if morale_state == Morale.DESTROYED:
			return

		var foe := find_melee_contact()
		in_melee = foe != null
		if in_melee:
			handle_melee(foe, delta)
		else:
			was_in_melee = false
			auto_engage(delta)

		handle_movement(delta)
		handle_fire(delta)
		handle_skirmishers(delta)
	else:
		# Client: glide toward the host's authoritative position.
		global_position = global_position.move_toward(net_target_pos, 250.0 * delta)

	update_visualization(delta)
	queue_redraw()

func apply_net_state(e: Array) -> void:
	net_target_pos = Vector2(e[1], e[2])
	facing_dir = Vector2(e[3], e[4])
	strength = e[5]
	morale = e[6]
	morale_state = e[7]
	formation_type = e[8]
	skirmishers_deployed = e[9]
	in_melee = e[10]
	if visualized:
		rebuild_formation()

# ---------------------------------------------------------------- visualization (culled)

func update_visualization(delta: float) -> void:
	var should := true
	if game_manager and game_manager.has_method("is_in_view"):
		should = game_manager.is_in_view(global_position, VIEW_MARGIN)

	if should and not visualized:
		spawn_visuals()
	elif not should and visualized:
		despawn_visuals()

	if visualized:
		# keep node count in step with strength
		while soldiers.size() > min(strength, VISUAL_CAP):
			var s: Soldier = soldiers.pop_back()
			if is_instance_valid(s):
				s.queue_free()
		advance_volley(delta)

func spawn_visuals() -> void:
	var n: int = min(strength, VISUAL_CAP)
	for i in range(n):
		soldiers.append(_make_soldier(Soldier.Role.LINE))
	officer = _make_soldier(Soldier.Role.OFFICER)
	flag = _make_soldier(Soldier.Role.FLAG)
	musician = _make_soldier(Soldier.Role.MUSICIAN)
	visualized = true
	rebuild_formation()

func despawn_visuals() -> void:
	for s in soldiers:
		if is_instance_valid(s):
			s.queue_free()
	soldiers.clear()
	for c in [officer, flag, musician]:
		if is_instance_valid(c):
			c.queue_free()
	officer = null
	flag = null
	musician = null
	volley_shooters.clear()
	volley_index = 0
	visualized = false

func team_color() -> Color:
	return Color(0.4, 0.6, 1.0) if team == 0 else Color(1.0, 0.4, 0.4)

func _make_soldier(role: int) -> Soldier:
	var scene := load("res://scenes/units/soldier.tscn")
	var s: Soldier = scene.instantiate()
	s.battalion = self
	s.role = role
	s.unit_type = unit_type
	s.team_color = team_color()
	s.jitter = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	s.move_speed = randf_range(16.0, 24.0) if unit_type != "cavalry" else randf_range(30.0, 40.0)
	add_child(s)
	s.global_position = global_position
	return s

# ---------------------------------------------------------------- formation (visual only)

func _basis() -> Array:
	var fwd := facing_dir
	var right := Vector2(-fwd.y, fwd.x)
	return [fwd, right]

func _to_world(local: Vector2, fwd: Vector2, right: Vector2) -> Vector2:
	return right * local.x - fwd * local.y

func _cols(count: int) -> int:
	match formation_type:
		"line": return max(1, int(ceil(count / float(LINE_RANKS))))
		"column": return 12
		"attack_column": return 30
		"square": return max(1, int(ceil(sqrt(count))))
	return 20

func rebuild_formation() -> void:
	if not visualized:
		return
	var b := _basis()
	var fwd: Vector2 = b[0]
	var right: Vector2 = b[1]

	var skirm_count := 0
	if skirmishers_deployed and can_shoot():
		skirm_count = int(round(soldiers.size() * SKIRMISH_FRACTION))
	var body_count := soldiers.size() - skirm_count

	var cols := _cols(body_count)
	var rows: int = max(1, int(ceil(body_count / float(cols))))

	var bi := 0
	var si := 0
	for i in range(soldiers.size()):
		var s := soldiers[i]
		if i < skirm_count:
			s.is_skirmisher = true
			var lateral := (si - (skirm_count - 1) * 0.5) * SKIRMISH_SPACING
			var scatter := Vector2(randf_range(-5, 5), randf_range(-8, 8))
			s.formation_offset = fwd * SKIRMISH_FRONT + right * lateral + scatter
			si += 1
		else:
			s.is_skirmisher = false
			var row := bi / cols
			var col := bi % cols
			var lx := col * SPACING - (cols - 1) * SPACING * 0.5
			var ly := row * SPACING - (rows - 1) * SPACING * 0.5
			s.formation_offset = _to_world(Vector2(lx, ly), fwd, right)
			bi += 1

	var back := (rows - 1) * SPACING * 0.5 + 10.0
	if is_instance_valid(officer):
		officer.formation_offset = _to_world(Vector2(0, back), fwd, right)
	if is_instance_valid(flag):
		flag.formation_offset = _to_world(Vector2(-7, back), fwd, right)
	if is_instance_valid(musician):
		musician.formation_offset = _to_world(Vector2(7, back), fwd, right)

func density_factor() -> float:
	match formation_type:
		"attack_column": return 1.3
		"column": return 1.5
		"square": return 1.4
	return 1.0

func fire_factor() -> float:
	match formation_type:
		"line": return 0.6
		"attack_column": return 0.4
		"column": return 0.25
		"square": return 0.45
	return 0.5

# ---------------------------------------------------------------- movement

func handle_movement(delta: float) -> void:
	var speed := move_speed_base()
	if morale_state == Morale.ROUTING:
		speed = ROUT_SPEED
		var enemy: Battalion = game_manager.nearest_enemy(self) if game_manager else null
		if enemy:
			var flee := (global_position - enemy.global_position).normalized()
			target_position = global_position + flee * 30.0
	elif in_melee:
		return
	elif charge_timer > 0.0:
		speed = charge_speed()
		var e: Battalion = game_manager.nearest_enemy(self) if game_manager else null
		if e:
			target_position = e.global_position
	if global_position.distance_to(target_position) > 1.0:
		var tf := 1.0
		if game_manager and is_instance_valid(game_manager.terrain):
			tf = game_manager.terrain.movement_factor(global_position)
		global_position = global_position.move_toward(target_position, speed * tf * delta)

# ---------------------------------------------------------------- morale

func update_morale(delta: float) -> void:
	var enemy_near := false
	if game_manager:
		var e: Battalion = game_manager.nearest_enemy(self)
		enemy_near = e != null and e.global_position.distance_to(global_position) < musket_range() + 40.0
	if time_since_hit > 6.0 and not enemy_near and strength > 0:
		var rec := MORALE_RECOVER
		morale = min(MAX_MORALE, morale + rec * delta)

	if strength <= 0:
		morale_state = Morale.DESTROYED
	elif morale_state == Morale.ROUTING:
		if morale > 45.0 and not enemy_near:
			morale_state = Morale.STEADY
	elif morale < 20.0:
		morale_state = Morale.ROUTING
	elif morale < 50.0:
		morale_state = Morale.SHAKEN
	else:
		morale_state = Morale.STEADY

	if morale_state == Morale.DESTROYED:
		despawn_visuals()
		queue_free()

func add_morale(amount: float) -> void:
	morale = clamp(morale + amount, 0.0, MAX_MORALE)

# ---------------------------------------------------------------- firing (abstract + rolling visual)

func can_fight() -> bool:
	return strength > 0 and morale_state != Morale.ROUTING and morale_state != Morale.DESTROYED

func handle_fire(delta: float) -> void:
	if not game_manager or not can_fight() or not can_shoot() or ammo <= 0:
		return
	fire_cd -= delta
	if fire_cd > 0.0:
		return
	fire_cd = fire_interval() * (1.6 if morale_state == Morale.SHAKEN else 1.0)

	var target: Battalion = game_manager.nearest_enemy_in_arc(self)
	if not target:
		return

	ammo -= 1
	var dist := global_position.distance_to(target.global_position)
	var casualties := compute_fire_casualties(target, dist)
	if casualties > 0:
		target.take_casualties(casualties, global_position)
	target.add_morale(-(casualties * MORALE_PER_CASUALTY + MORALE_SUPPRESSION))

	if visualized:
		start_volley_visual(target)

func compute_fire_casualties(target: Battalion, dist: float) -> int:
	var raw: float
	if unit_type == "artillery":
		var guns: int = max(1, int(strength / 15))
		var per := 3.0 if dist < 200.0 else 1.5
		raw = guns * per * target.density_factor()
	else:
		raw = strength * fire_factor() * hit_chance(dist) * target.density_factor()
	# High ground improves fire.
	if game_manager and is_instance_valid(game_manager.terrain):
		var dh: float = game_manager.terrain.elevation_at(global_position) - game_manager.terrain.elevation_at(target.global_position)
		if dh > 0.05:
			raw *= 1.2
	return clampi(int(round(raw)), 0, target.strength)

func hit_chance(dist: float) -> float:
	if dist < 50.0:
		return 0.10
	elif dist < 100.0:
		return 0.06
	elif dist <= musket_range():
		return 0.03
	return 0.0

func start_volley_visual(target: Battalion) -> void:
	var roll_axis := Vector2(-facing_dir.y, facing_dir.x)
	var list: Array = []
	for s in soldiers:
		if s.is_skirmisher:
			continue
		if s.global_position.distance_to(target.global_position) > musket_range():
			continue
		var to := (target.global_position - s.global_position).normalized()
		if acos(clampf(facing_dir.dot(to), -1.0, 1.0)) <= FIRE_ARC:
			list.append(s)
	list.sort_custom(func(a, b): return a.global_position.dot(roll_axis) < b.global_position.dot(roll_axis))
	volley_shooters = list
	volley_index = 0
	volley_timer = 0.0

func advance_volley(delta: float) -> void:
	if volley_index >= volley_shooters.size():
		return
	volley_timer += delta
	var roll_time := 1.4
	var want := int((volley_timer / roll_time) * volley_shooters.size())
	while volley_index < min(want, volley_shooters.size()):
		var s = volley_shooters[volley_index]
		if is_instance_valid(s):
			s.fire_flash()
			if game_manager:
				game_manager.spawn_smoke(s.global_position)
				if unit_type == "artillery":
					game_manager.spawn_smoke(s.global_position + facing_dir * 8.0)
		volley_index += 1

func take_casualties(count: int, from_pos: Vector2) -> void:
	# Cover (woods/town) reduces losses.
	if game_manager and is_instance_valid(game_manager.terrain):
		count = int(round(count * game_manager.terrain.cover_factor(global_position)))
	count = min(count, strength)
	if count <= 0:
		return
	strength -= count
	time_since_hit = 0.0

	if visualized and not soldiers.is_empty():
		soldiers.sort_custom(func(a, b):
			var da: float = a.global_position.distance_to(from_pos) + (40.0 if a.is_skirmisher else 0.0)
			var db: float = b.global_position.distance_to(from_pos) + (40.0 if b.is_skirmisher else 0.0)
			return da < db)
		var remove: int = min(count, soldiers.size())
		for i in range(remove):
			var s := soldiers[0]
			soldiers.remove_at(0)
			if game_manager:
				var col := team_color().darkened(0.45)
				col.a = 0.7
				game_manager.add_corpse(s.global_position, col)
			s.queue_free()
		rebuild_formation()

# ---------------------------------------------------------------- skirmishing (abstract)

func handle_skirmishers(delta: float) -> void:
	if not skirmishers_deployed or not can_shoot() or not game_manager:
		return
	skirm_cd -= delta
	if skirm_cd > 0.0:
		return
	skirm_cd = 1.0
	var foe: Battalion = game_manager.nearest_enemy(self)
	if not foe or foe.is_dead():
		return
	if global_position.distance_to(foe.global_position) > SKIRMISH_RANGE:
		return
	var skirmishers := int(strength * SKIRMISH_FRACTION)
	var cas: int = int(round(skirmishers * 0.02))
	if cas > 0:
		foe.take_casualties(cas, global_position)
		foe.add_morale(-0.3)
	if visualized:
		for s in soldiers:
			if s.is_skirmisher and randf() < 0.4:
				s.fire_flash()
				game_manager.spawn_smoke(s.global_position)

# ---------------------------------------------------------------- melee / charge

func find_melee_contact() -> Battalion:
	if not game_manager or strength <= 0:
		return null
	var e: Battalion = game_manager.nearest_enemy(self)
	if e and not e.is_dead() and global_position.distance_to(e.global_position) <= MELEE_DIST:
		return e
	return null

func melee_formation_factor() -> float:
	match formation_type:
		"column": return 1.5
		"attack_column": return 1.4
		"square": return 1.2
	return 1.0

func melee_power() -> float:
	var mf := morale / 100.0
	var cb := 1.4 if charge_active else 1.0
	return maxf(0.0, strength * mf * melee_formation_factor() * cb * type_melee_factor())

# Infantry square wrecks a cavalry charge.
func effective_melee_power(vs: Battalion) -> float:
	var p := melee_power()
	if unit_type == "cavalry" and vs.unit_type == "infantry" and vs.formation_type == "square":
		p *= 0.2
	return p

func handle_melee(foe: Battalion, delta: float) -> void:
	if not was_in_melee and charge_active:
		var shock := CHARGE_SHOCK * melee_formation_factor()
		if unit_type == "cavalry":
			shock *= 1.8
			if foe.unit_type == "infantry" and foe.formation_type == "square":
				shock = 0.0   # square holds
		foe.add_morale(-shock)
	was_in_melee = true
	if id < foe.id:
		melee_cd -= delta
		if melee_cd <= 0.0:
			melee_cd = MELEE_INTERVAL
			melee_exchange(foe)

func melee_exchange(foe: Battalion) -> void:
	var mp := effective_melee_power(foe)
	var ep := foe.effective_melee_power(self)
	var my_loss := int(round(ep * MELEE_LETHALITY))
	var foe_loss := int(round(mp * MELEE_LETHALITY))
	if foe_loss > 0:
		foe.take_casualties(foe_loss, global_position)
	if my_loss > 0:
		take_casualties(my_loss, foe.global_position)
	add_morale(-(ep / maxf(1.0, mp)) * MELEE_MORALE)
	foe.add_morale(-(mp / maxf(1.0, ep)) * MELEE_MORALE)

func update_charge(delta: float) -> void:
	if charge_timer > 0.0:
		charge_timer -= delta
		if charge_timer <= 0.0:
			charge_active = false

func auto_engage(delta: float) -> void:
	if not game_manager or not can_shoot():
		return
	if global_position.distance_to(target_position) > 2.0:
		return
	var e: Battalion = game_manager.nearest_enemy(self)
	if not e or e.is_dead():
		return
	if global_position.distance_to(e.global_position) > musket_range():
		return
	var to := (e.global_position - global_position).normalized()
	var ang := facing_dir.angle_to(to)
	if absf(ang) > 0.05:
		var step := clampf(ang, -AUTO_WHEEL_RATE * delta, AUTO_WHEEL_RATE * delta)
		facing_dir = facing_dir.rotated(step)
		rebuild_formation()

# ---------------------------------------------------------------- orders + speech

func say(text: String) -> void:
	speech_text = text
	speech_timer = SPEECH_TIME

func receive_order(order: Dictionary) -> void:
	match order.get("type", "move"):
		"move":
			var t: Vector2 = order.get("target", global_position)
			if global_position.distance_to(t) > 1.0:
				facing_dir = (t - global_position).normalized()
			target_position = t
			rebuild_formation()
			say("Forward — march!")
		"advance":
			_face_enemy()
			target_position = global_position + facing_dir * ADVANCE_DIST
			rebuild_formation()
			say("Advance!")
		"fallback":
			_face_enemy()
			target_position = global_position - facing_dir * ADVANCE_DIST
			rebuild_formation()
			say("Fall back — steady!")
		"wheel_left":
			facing_dir = facing_dir.rotated(-WHEEL_STEP)
			rebuild_formation()
			say("Wheel left!")
		"wheel_right":
			facing_dir = facing_dir.rotated(WHEEL_STEP)
			rebuild_formation()
			say("Wheel right!")
		"charge":
			_face_enemy()
			charge_active = true
			charge_timer = CHARGE_DURATION
			var e: Battalion = game_manager.nearest_enemy(self) if game_manager else null
			if e:
				target_position = e.global_position
			rebuild_formation()
			say("Charge!")
		"formation":
			change_formation(order.get("formation", "line"))
		"skirmishers":
			toggle_skirmishers()
		"hold":
			target_position = global_position
			say("Hold the line!")

func _face_enemy() -> void:
	if not game_manager:
		return
	var e: Battalion = game_manager.nearest_enemy(self)
	if e:
		facing_dir = (e.global_position - global_position).normalized()

func change_formation(new_formation: String) -> void:
	formation_type = new_formation
	rebuild_formation()
	match new_formation:
		"line": say("Form line!")
		"column": say("Form column!")
		"attack_column": say("Attack column!")
		"square": say("Form square!")

func toggle_skirmishers() -> void:
	if not can_shoot():
		return
	skirmishers_deployed = not skirmishers_deployed
	rebuild_formation()
	say("Skirmishers, out!" if skirmishers_deployed else "Skirmishers, recall!")

func ai_move(pos: Vector2) -> void:
	if global_position.distance_to(pos) > 1.0:
		facing_dir = (pos - global_position).normalized()
	target_position = pos
	rebuild_formation()

func ai_stop() -> void:
	target_position = global_position

# ---------------------------------------------------------------- queries / draw

func morale_state_name() -> String:
	match morale_state:
		Morale.STEADY: return "Steady"
		Morale.SHAKEN: return "Shaken"
		Morale.ROUTING: return "Routing"
		Morale.DESTROYED: return "Destroyed"
	return "?"

func formation_name() -> String:
	match formation_type:
		"line": return "Line"
		"column": return "Column"
		"attack_column": return "Attack Column"
		"square": return "Square"
	return formation_type

func is_routing() -> bool:
	return morale_state == Morale.ROUTING

func is_dead() -> bool:
	return strength <= 0 or morale_state == Morale.DESTROYED

func select() -> void:
	is_selected = true

func deselect() -> void:
	is_selected = false

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, team_color().darkened(0.2))
	draw_line(Vector2.ZERO, facing_dir * 26.0, team_color(), 1.5)
	if is_selected:
		var ring := Color.YELLOW
		match morale_state:
			Morale.SHAKEN: ring = Color.ORANGE
			Morale.ROUTING: ring = Color.RED
		draw_arc(Vector2.ZERO, 90.0, 0, TAU, 56, ring, 2.0)

	if speech_timer > 0.0 and is_instance_valid(officer):
		_draw_speech(officer.formation_offset + Vector2(0, -16))

func _draw_speech(local_pos: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var fs := 16
	var size := font.get_string_size(speech_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pad := Vector2(5, 3)
	var a := clampf(speech_timer, 0.0, 1.0)
	var rect_pos := local_pos - Vector2(size.x * 0.5, size.y) - pad
	var rect := Rect2(rect_pos, size + pad * 2.0)
	draw_rect(rect, Color(1, 1, 1, 0.85 * a))
	draw_rect(rect, Color(0, 0, 0, 0.6 * a), false, 1.0)
	var text_pos := rect_pos + Vector2(pad.x, pad.y + font.get_ascent(fs))
	draw_string(font, text_pos, speech_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a))
