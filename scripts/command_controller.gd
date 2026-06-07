extends Node2D
class_name CommandController

# Tactical input:
#   Left-click  -> select one of your battalions
#   Right-click -> open an order menu for the selected battalion
# Every chosen order is dispatched as a courier from the commander, so it only
# takes effect once the courier physically reaches the battalion.

var commander: Node2D
var game_manager: Node
var controlled: Array[Battalion] = []
var selected: Battalion
var last_click_world: Vector2

const SELECT_RADIUS := 75.0

# Menu item ids
const ID_LINE := 0
const ID_COLUMN := 1
const ID_ATTACK_COLUMN := 2
const ID_SQUARE := 3
const ID_MOVE := 103
const ID_SKIRMISH := 100
const ID_ADVANCE := 101
const ID_FALLBACK := 102
const ID_CHARGE := 104
const ID_WHEEL_LEFT := 105
const ID_WHEEL_RIGHT := 106

var menu: PopupMenu

func _ready() -> void:
	_build_menu()

func setup(p_commander: Node2D, p_manager: Node, p_battalions: Array) -> void:
	commander = p_commander
	game_manager = p_manager
	controlled.clear()
	for b in p_battalions:
		controlled.append(b)

func _build_menu() -> void:
	menu = PopupMenu.new()

	var formation_menu := PopupMenu.new()
	formation_menu.name = "FormationMenu"
	formation_menu.add_item("Line", ID_LINE)
	formation_menu.add_item("Column", ID_COLUMN)
	formation_menu.add_item("Attack Column", ID_ATTACK_COLUMN)
	formation_menu.add_item("Square", ID_SQUARE)

	var maneuver_menu := PopupMenu.new()
	maneuver_menu.name = "ManeuverMenu"
	maneuver_menu.add_item("Advance", ID_ADVANCE)
	maneuver_menu.add_item("Fall Back", ID_FALLBACK)
	maneuver_menu.add_item("Wheel Left", ID_WHEEL_LEFT)
	maneuver_menu.add_item("Wheel Right", ID_WHEEL_RIGHT)

	var command_menu := PopupMenu.new()
	command_menu.name = "CommandMenu"
	command_menu.add_item("Move Here", ID_MOVE)
	command_menu.add_item("Charge!", ID_CHARGE)
	command_menu.add_item("Deploy / Recall Skirmishers", ID_SKIRMISH)

	menu.add_child(formation_menu)
	menu.add_child(maneuver_menu)
	menu.add_child(command_menu)
	menu.add_submenu_item("Formation", "FormationMenu")
	menu.add_submenu_item("Maneuver", "ManeuverMenu")
	menu.add_submenu_item("Commands", "CommandMenu")
	add_child(menu)

	formation_menu.id_pressed.connect(_on_menu_id)
	maneuver_menu.id_pressed.connect(_on_menu_id)
	command_menu.id_pressed.connect(_on_menu_id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			select_at(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if selected:
				last_click_world = get_global_mouse_position()
				var mp := get_viewport().get_mouse_position()
				menu.popup(Rect2i(int(mp.x), int(mp.y), 0, 0))

func select_at(world_pos: Vector2) -> void:
	var nearest: Battalion = null
	var best := SELECT_RADIUS
	for b in controlled:
		if not is_instance_valid(b):
			continue
		var d := b.global_position.distance_to(world_pos)
		if d < best:
			best = d
			nearest = b

	if selected and selected != nearest:
		selected.deselect()
	selected = nearest
	if selected:
		selected.select()

func _on_menu_id(id: int) -> void:
	if not is_instance_valid(selected):
		return
	match id:
		ID_LINE:
			dispatch({ "type": "formation", "formation": "line" })
		ID_COLUMN:
			dispatch({ "type": "formation", "formation": "column" })
		ID_ATTACK_COLUMN:
			dispatch({ "type": "formation", "formation": "attack_column" })
		ID_SQUARE:
			dispatch({ "type": "formation", "formation": "square" })
		ID_MOVE:
			dispatch({ "type": "move", "target": last_click_world })
		ID_SKIRMISH:
			dispatch({ "type": "skirmishers" })
		ID_ADVANCE:
			dispatch({ "type": "advance" })
		ID_FALLBACK:
			dispatch({ "type": "fallback" })
		ID_CHARGE:
			dispatch({ "type": "charge" })
		ID_WHEEL_LEFT:
			dispatch({ "type": "wheel_left" })
		ID_WHEEL_RIGHT:
			dispatch({ "type": "wheel_right" })

func dispatch(order: Dictionary) -> void:
	if not selected:
		return
	# Client: ask the host to apply the order (no local courier simulation).
	if game_manager and not game_manager.authoritative:
		Net.request_order(selected.id, order)
		return
	if not commander:
		return
	var courier_scene := load("res://scenes/units/courier.tscn")
	var courier: Courier = courier_scene.instantiate()
	courier.global_position = commander.global_position
	courier.target_battalion = selected
	courier.order = order
	game_manager.add_courier(courier)
