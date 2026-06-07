extends Node
class_name EnemyCommander

# Strategic AI. Controls every team that has no human player (set by GameManager).
# Only runs on the authority (host/offline). Tactical execution (firing, wheeling,
# melee, routing) is each battalion's own AI.

var game_manager: GameManager
var ai_teams: Array = [1]
var think_cd: float = 0.0

const THINK_INTERVAL := 2.5

func setup(gm: GameManager, teams: Array) -> void:
	game_manager = gm
	ai_teams = teams

func _process(delta: float) -> void:
	if not game_manager or not game_manager.authoritative:
		return
	if ai_teams.is_empty():
		return
	think_cd -= delta
	if think_cd > 0.0:
		return
	think_cd = THINK_INTERVAL
	think()

func think() -> void:
	for b in game_manager.all_battalions:
		if not is_instance_valid(b) or b.is_dead():
			continue
		if b.team not in ai_teams:
			continue
		if b.morale_state == Battalion.Morale.ROUTING:
			continue
		var foes := _foes_of(b)
		if foes.is_empty():
			continue
		command_battalion(b, foes)

func _foes_of(b: Battalion) -> Array:
	var out: Array = []
	for e in game_manager.all_battalions:
		if is_instance_valid(e) and not e.is_dead() and e.team != b.team:
			out.append(e)
	return out

func command_battalion(b: Battalion, foes: Array) -> void:
	var target := nearest_in(b, foes)
	if not target:
		return
	var d := b.global_position.distance_to(target.global_position)
	var contact: float = Battalion.MELEE_DIST + 20.0

	if b.unit_type == "cavalry":
		if d > contact:
			ensure_formation(b, "column")
			b.ai_move(target.global_position)
		elif not b.charge_active and b.charge_timer <= 0.0:
			b.receive_order({ "type": "charge" })
		return

	var rng: float = b.musket_range()
	if d > rng * 1.05:
		ensure_formation(b, "column")
		b.ai_move(approach_point(b, target, rng))
	elif d > contact:
		ensure_formation(b, "line")
		if b.can_shoot() and not b.skirmishers_deployed:
			b.receive_order({ "type": "skirmishers" })
		b.ai_stop()
	elif b.unit_type != "artillery":
		if not b.charge_active and b.charge_timer <= 0.0:
			b.receive_order({ "type": "charge" })

func ensure_formation(b: Battalion, f: String) -> void:
	if b.formation_type != f:
		b.receive_order({ "type": "formation", "formation": f })

func approach_point(b: Battalion, target: Battalion, rng: float) -> Vector2:
	var dir := (b.global_position - target.global_position).normalized()
	return target.global_position + dir * (rng * 0.8)

func nearest_in(b: Battalion, list: Array) -> Battalion:
	var best: Battalion = null
	var best_d := INF
	for e in list:
		if not is_instance_valid(e) or e.is_dead():
			continue
		var d := b.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
