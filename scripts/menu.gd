extends Control

# Launcher + lobby. Single / Host / Join, then a lobby where players claim a
# battalion (slot). The host starts the battle for everyone.

var root: VBoxContainer
var ip_edit: LineEdit
var status: Label
var lobby_box: VBoxContainer
var slots_grid: GridContainer
var start_btn: Button
var in_lobby := false

func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.09, 0.12)
	add_child(bg)

	root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.custom_minimum_size = Vector2(420, 0)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = "COMMANDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.86, 0.45))
	root.add_child(title)

	_build_main()

	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	root.add_child(status)

	Net.lobby_updated.connect(_refresh_lobby)

	var args := OS.get_cmdline_user_args()
	if "--auto-host" in args:
		_on_host()
		get_tree().create_timer(3.0).timeout.connect(_on_start)
	elif "--auto-join" in args:
		_on_join()

# ------------------------------------------------------------------ main screen

func _build_main() -> void:
	var main := VBoxContainer.new()
	main.name = "Main"
	main.add_theme_constant_override("separation", 8)
	root.add_child(main)
	root.move_child(main, 1)

	_btn(main, "Single Player", _on_single)
	_btn(main, "Campaign Province  (preview — watch the war)", _on_world)
	_btn(main, "Host Game", _on_host)
	var iprow := HBoxContainer.new()
	iprow.add_theme_constant_override("separation", 6)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iprow.add_child(ip_edit)
	var jb := Button.new()
	jb.text = "Join"
	jb.pressed.connect(_on_join)
	iprow.add_child(jb)
	main.add_child(iprow)

# ------------------------------------------------------------------ lobby

func _enter_lobby() -> void:
	in_lobby = true
	var main := root.get_node_or_null("Main")
	if main:
		main.queue_free()
	lobby_box = VBoxContainer.new()
	lobby_box.add_theme_constant_override("separation", 8)
	root.add_child(lobby_box)
	root.move_child(lobby_box, 1)

	var hdr := Label.new()
	hdr.text = "LOBBY — claim a battalion"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	lobby_box.add_child(hdr)

	slots_grid = GridContainer.new()
	slots_grid.columns = 5
	slots_grid.add_theme_constant_override("h_separation", 6)
	slots_grid.add_theme_constant_override("v_separation", 6)
	lobby_box.add_child(slots_grid)

	if GameConfig.mode == "host":
		start_btn = Button.new()
		start_btn.text = "▶  START BATTLE"
		start_btn.custom_minimum_size = Vector2(0, 40)
		start_btn.pressed.connect(_on_start)
		lobby_box.add_child(start_btn)

	_refresh_lobby()

func _refresh_lobby() -> void:
	if not in_lobby:
		_enter_lobby()
		return
	if slots_grid == null:
		return
	for c in slots_grid.get_children():
		c.queue_free()
	var taken := Net.lobby.values()
	var mine := GameConfig.local_slot
	for slot in Net.HUMAN_SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(70, 34)
		var is_taken: bool = slot in taken
		var is_mine: bool = is_taken and slot == mine
		b.text = Net.slot_label(slot)
		if is_mine:
			b.text += "  (you)"
			b.disabled = true
		elif is_taken:
			b.text += "  ✓"
			b.disabled = true
		else:
			var s: int = slot
			b.pressed.connect(func(): Net.request_slot(s))
		slots_grid.add_child(b)
	status.text = "Players: %d   ·   you command %s" % [Net.lobby.size(), Net.slot_label(mine)]

# ------------------------------------------------------------------ actions

const GS := preload("res://scripts/game.gd")   # read the order-of-battle constants

func _on_single() -> void:
	GameConfig.mode = "single"
	GameConfig.match_seed = randi() | 1
	_enter_select()

func _on_world() -> void:
	get_tree().change_scene_to_file("res://world.tscn")

# ------------------------------------------------- battalion select (the OOB)

func _enter_select() -> void:
	var main := root.get_node_or_null("Main")
	if main:
		main.queue_free()
	var box := VBoxContainer.new()
	box.name = "Select"
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	root.move_child(box, 1)
	var hdr := Label.new()
	hdr.text = "CHOOSE YOUR COMMAND"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	box.add_child(hdr)
	var quick := Button.new()
	quick.text = "▶  Quick start — a battalion at the army's centre"
	quick.pressed.connect(func(): _start_with(52))
	box.add_child(quick)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(470, 430)
	box.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	sc.add_child(col)
	var slot := 0
	for cp in range(GS.CORPS_PER_TEAM):
		_oob_header(col, "%s CORPS" % ("I" if cp == 0 else "II"), Color(1.0, 0.84, 0.42))
		for dv in range(GS.DIVISIONS_PER_CORPS):
			var dname := "%d%s Division — %s" % [dv + 1, _ord(dv + 1), "first line" if dv == 0 else "second line (reserve)"]
			_oob_header(col, "  " + dname, Color(0.75, 0.85, 1.0))
			for bg in range(GS.BRIGADES_PER_DIVISION):
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 4)
				var bl := Label.new()
				bl.text = "    Bde %d" % (bg + 1)
				bl.custom_minimum_size = Vector2(74, 0)
				bl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
				row.add_child(bl)
				for k in range(GS.BATTS_PER_BRIGADE):
					var s := slot
					var btn := Button.new()
					btn.text = "%d%s" % [s + 1, _ord(s + 1)]
					btn.custom_minimum_size = Vector2(62, 30)
					btn.pressed.connect(func(): _start_with(s))
					row.add_child(btn)
					slot += 1
				col.add_child(row)
	_oob_header(col, "CAVALRY WINGS — under the army's hand", Color(1.0, 0.84, 0.42))
	for r in range(GS.CAV_PER_TEAM):
		var cb := Button.new()
		cb.text = "  %d%s Regiment of Horse   (AI — not yet playable)" % [r + 1, _ord(r + 1)]
		cb.disabled = true
		col.add_child(cb)
	status.text = "Pick the battalion you will command — its place in the line is its fate."

func _oob_header(col: VBoxContainer, text: String, c: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", c)
	col.add_child(l)

func _ord(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "th"
	match n % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
	return "th"

func _start_with(slot: int) -> void:
	GameConfig.local_slot = slot
	get_tree().change_scene_to_file("res://game.tscn")

func _on_host() -> void:
	var err := Net.host_game()
	if err != OK:
		status.text = "Failed to host (error %d)" % err
		return
	_enter_lobby()
	status.text = "Hosting on port %d — waiting for players…" % Net.PORT

func _on_join() -> void:
	var err := Net.join_game(ip_edit.text.strip_edges())
	if err != OK:
		status.text = "Failed to join (error %d)" % err
		return
	status.text = "Connecting to %s …" % ip_edit.text
	# the lobby appears when the host's first lobby sync arrives

func _on_start() -> void:
	Net.start_game()

# ------------------------------------------------------------------ helpers

func _btn(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	box.add_child(b)
