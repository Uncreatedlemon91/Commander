extends CanvasLayer

# Bottom-left readout for the currently selected battalion. Builds its own
# controls in code so no .tscn wiring is needed.

var controller: Node
var panel: Panel
var title: Label
var body: Label

func _ready() -> void:
	controller = get_node_or_null("../CommandController")

	panel = Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 12.0
	panel.offset_right = 290.0
	panel.offset_top = -190.0
	panel.offset_bottom = -12.0
	add_child(panel)

	title = Label.new()
	title.position = Vector2(12, 8)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	panel.add_child(title)

	body = Label.new()
	body.position = Vector2(12, 34)
	body.add_theme_font_size_override("font_size", 14)
	panel.add_child(body)

	panel.visible = false

func _process(_delta: float) -> void:
	var b = controller.selected if controller else null
	if not is_instance_valid(b):
		panel.visible = false
		return

	panel.visible = true
	title.text = b.unit_name

	var morale_pct: int = int(round(b.morale))
	var skirm: String = "Deployed" if b.skirmishers_deployed else "—"
	var type_label: String = String(b.unit_type).capitalize()

	body.text = "Type: %s\nStrength: %d / %d\nMorale: %d%%  (%s)\nAmmo: %d rounds\nFormation: %s\nSkirmishers: %s" % [
		type_label,
		b.strength, b.max_strength,
		morale_pct, b.morale_state_name(),
		b.ammo,
		b.formation_name(),
		skirm,
	]
