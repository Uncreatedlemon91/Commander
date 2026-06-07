extends Node2D
class_name GameManager

# Root of the battle. Spawns the OOB (deterministically on every peer), runs
# shared queries, hosts effects + terrain, and — in multiplayer — broadcasts
# authoritative state from the host to clients.

@onready var terrain: Node2D = $Terrain
@onready var corpse_field: Node2D = $Corpses
@onready var battalions_container: Node2D = $Battalions
@onready var smoke_field: Node2D = $Smoke
@onready var couriers_container: Node2D = $Couriers
@onready var commander: Node2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var enemy_commander: Node = $EnemyCommander
@onready var command_controller: CommandController = $CommandController

var all_battalions: Array[Battalion] = []
var authoritative: bool = true
var local_team: int = 0
var sync_timer: float = 0.0

const SYNC_INTERVAL := 0.1

func _ready() -> void:
	local_team = GameConfig.local_team
	authoritative = (GameConfig.mode != "client")
	if GameConfig.mode != "single":
		Net.game = self

	_spawn_oob()

	# Local player commands their own army.
	var mine := all_battalions.filter(func(b): return b.team == local_team)
	command_controller.setup(commander, self, mine)

	# AI runs the host/offline side and controls any team with no human player.
	var ai_teams := _ai_teams()
	enemy_commander.setup(self, ai_teams)

func _spawn_oob() -> void:
	var oob := [
		[0, Vector2(-360, -320), 0, "1er Bn, 17e Légère",        "infantry"],
		[1, Vector2(-360, -60),  0, "1er Bn, 30e de Ligne",      "infantry"],
		[2, Vector2(-360, 200),  0, "1er Bn, 6e de Ligne",       "infantry"],
		[3, Vector2(-540, -60),  0, "10e Chasseurs à Cheval",    "cavalry"],
		[4, Vector2(-560, -320), 0, "Artillerie à pied, 5e Rgt", "artillery"],
		[5, Vector2(360, -320),  1, "IR Reuss-Greitz Nr. 18",    "infantry"],
		[6, Vector2(360, -60),   1, "IR Kaunitz Nr. 20",         "infantry"],
		[7, Vector2(360, 200),   1, "IR Spork Nr. 25",           "infantry"],
		[8, Vector2(540, -60),   1, "Latour Chevaulegers Nr. 4", "cavalry"],
		[9, Vector2(560, -320),  1, "Linz Batterie",             "artillery"],
	]
	for e in oob:
		spawn_battalion(e[0], e[1], e[2], e[3], e[4])

func _ai_teams() -> Array:
	var humans: Array = [local_team]
	if GameConfig.mode != "single":
		humans = Net.human_teams()
	var ai: Array = []
	for t in [0, 1]:
		if t not in humans:
			ai.append(t)
	return ai

func _process(delta: float) -> void:
	if authoritative and GameConfig.mode != "single" and multiplayer.multiplayer_peer != null:
		sync_timer -= delta
		if sync_timer <= 0.0:
			sync_timer = SYNC_INTERVAL
			_broadcast_state()

func spawn_battalion(id: int, pos: Vector2, team: int, unit_name: String = "Battalion", unit_type: String = "infantry") -> void:
	var scene := load("res://scenes/units/battalion.tscn")
	var battalion: Battalion = scene.instantiate()
	battalion.id = id
	battalion.team = team
	battalion.game_manager = self
	battalion.unit_name = unit_name
	battalion.unit_type = unit_type
	battalion.position = pos
	battalions_container.add_child(battalion)
	all_battalions.append(battalion)

func add_courier(courier: Courier) -> void:
	couriers_container.add_child(courier)

func spawn_smoke(world_pos: Vector2) -> void:
	smoke_field.add(world_pos)

func add_corpse(world_pos: Vector2, color: Color) -> void:
	corpse_field.add_corpse(world_pos, color)

# Applied on the host when a client requests an order.
func order_battalion(id: int, order: Dictionary) -> void:
	var b := _find_battalion(id)
	if b:
		b.receive_order(order)

func _find_battalion(id: int) -> Battalion:
	for b in all_battalions:
		if is_instance_valid(b) and b.id == id:
			return b
	return null

# ---------------------------------------------------------------- state sync

func _broadcast_state() -> void:
	var data: Array = []
	for b in all_battalions:
		if is_instance_valid(b):
			data.append([
				b.id, b.global_position.x, b.global_position.y,
				b.facing_dir.x, b.facing_dir.y,
				b.strength, b.morale, int(b.morale_state),
				b.formation_type, b.skirmishers_deployed, b.in_melee,
			])
	rpc("_apply_state", data)

@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_state(data: Array) -> void:
	for e in data:
		var b := _find_battalion(e[0])
		if b:
			b.apply_net_state(e)

# ---------------------------------------------------------------- shared queries

func team_battalions(team: int) -> Array:
	var out: Array = []
	for b in all_battalions:
		if is_instance_valid(b) and not b.is_dead() and b.team == team:
			out.append(b)
	return out

func nearest_enemy(b: Battalion) -> Battalion:
	var best: Battalion = null
	var best_d := INF
	for e in all_battalions:
		if not is_instance_valid(e) or e.team == b.team or e.is_dead():
			continue
		var d := b.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func nearest_enemy_in_arc(b: Battalion) -> Battalion:
	var best: Battalion = null
	var best_d := INF
	var rng: float = b.musket_range()
	for e in all_battalions:
		if not is_instance_valid(e) or e.team == b.team or e.is_dead():
			continue
		var d := b.global_position.distance_to(e.global_position)
		if d > rng:
			continue
		var to := (e.global_position - b.global_position).normalized()
		if acos(clampf(b.facing_dir.dot(to), -1.0, 1.0)) > Battalion.FIRE_ARC:
			continue
		if d < best_d:
			best_d = d
			best = e
	return best

# ---------------------------------------------------------------- camera culling

func get_view_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var z := camera.zoom
	var world_size := Vector2(vp.x / z.x, vp.y / z.y)
	var top_left := camera.global_position - world_size * 0.5
	return Rect2(top_left, world_size)

func is_in_view(pos: Vector2, margin: float) -> bool:
	return get_view_rect().grow(margin).has_point(pos)
