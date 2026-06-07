extends Control

# Pre-game menu. Pick your side (which commander/army you control), then play
# single-player vs the AI, host a P2P game, or join one. Builds its UI in code.

var side_option: OptionButton
var ip_edit: LineEdit
var status: Label
var start_button: Button

func _ready() -> void:
	var root := VBoxContainer.new()
	root.anchor_left = 0.5
	root.anchor_top = 0.5
	root.anchor_right = 0.5
	root.anchor_bottom = 0.5
	root.offset_left = -180
	root.offset_top = -200
	root.offset_right = 180
	root.offset_bottom = 200
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = "COMMANDER\nBattle of Ulm, 1805"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)

	var side_row := HBoxContainer.new()
	var side_label := Label.new()
	side_label.text = "Your army:  "
	side_row.add_child(side_label)
	side_option = OptionButton.new()
	side_option.add_item("French (Napoléon)", 0)
	side_option.add_item("Austrian (Mack)", 1)
	side_row.add_child(side_option)
	root.add_child(side_row)

	var sp := Button.new()
	sp.text = "Single Player (vs AI)"
	sp.pressed.connect(_on_single)
	root.add_child(sp)

	var hostb := Button.new()
	hostb.text = "Host P2P Game"
	hostb.pressed.connect(_on_host)
	root.add_child(hostb)

	var ip_row := HBoxContainer.new()
	var ip_label := Label.new()
	ip_label.text = "Join IP:  "
	ip_row.add_child(ip_label)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.custom_minimum_size = Vector2(180, 0)
	ip_row.add_child(ip_edit)
	root.add_child(ip_row)

	var joinb := Button.new()
	joinb.text = "Join P2P Game"
	joinb.pressed.connect(_on_join)
	root.add_child(joinb)

	start_button = Button.new()
	start_button.text = "Start Battle (host)"
	start_button.pressed.connect(_on_start)
	start_button.visible = false
	root.add_child(start_button)

	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	root.add_child(status)

	Net.lobby_updated.connect(_update_lobby)

func _team() -> int:
	return side_option.get_selected_id()

func _on_single() -> void:
	GameConfig.mode = "single"
	GameConfig.local_team = _team()
	get_tree().change_scene_to_file("res://node_2d.tscn")

func _on_host() -> void:
	var err := Net.host_game(_team())
	if err != OK:
		status.text = "Failed to host (error %d)" % err
		return
	status.text = "Hosting on port %d — waiting for players…" % Net.PORT
	start_button.visible = true

func _on_join() -> void:
	var err := Net.join_game(ip_edit.text.strip_edges(), _team())
	if err != OK:
		status.text = "Failed to join (error %d)" % err
		return
	status.text = "Connecting to %s … (host starts the battle)" % ip_edit.text

func _on_start() -> void:
	Net.start_game()

func _update_lobby() -> void:
	if GameConfig.mode == "host":
		status.text = "Players connected: %d — press Start when ready" % Net.peers.size()
