extends Control

# Launcher + lobby. Single / Host / Join, then a lobby where players claim a
# battalion (slot). The host starts the battle for everyone.

var root: VBoxContainer
var ip_edit: LineEdit
var status: Label
var _use_upnp := false   # set by the --upnp launch flag: open the router port for internet play
var lobby_box: VBoxContainer
var slots_grid: GridContainer
var start_btn: Button
var in_lobby := false
# historical battle — picking your command (which side, which battalion)
var _hist_setup = null      # the built BattleSetup, kept while the player chooses a unit
var _hist_key := ""         # the battle key (e.g. "waterloo")
var _hist_side := 1         # which side's roster is shown (0 French, 1 Anglo-Allied/Prussian)
# character creation (raise your militia)
var _ci_uniform := 2
var _ci_facing := 0
var _ci_flag := 0
var _ci_hat := 0
var _ci_belt := 0
var _ci_pants := 0
var _ci_name: LineEdit
var _ci_officers: Array = []
var _ci_uni_btns: Array = []
var _ci_fac_btns: Array = []
var _ci_flag_btns: Array = []
var _ci_hat_btns: Array = []
var _ci_belt_btns: Array = []
var _ci_pants_btns: Array = []
var _ci_off_label: RichTextLabel

func _ready() -> void:
	# the painted backdrop, cropped to fill the screen at any aspect
	var bg := TextureRect.new()
	var bgtex = load("res://images/Background.png")
	if bgtex != null:
		bg.texture = bgtex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# a soft vertical scrim so the menu reads cleanly over the art
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.03, 0.04, 0.06, 0.42)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	# a dark, bordered card behind ALL the menu text so it reads cleanly over the painted
	# backdrop on every screen (main / lobby / intro / OOB), rather than loose labels floating
	# on the busy art behind only a faint scrim
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var cardsb := StyleBoxFlat.new()
	cardsb.bg_color = Color(0.04, 0.05, 0.08, 0.88)
	cardsb.set_corner_radius_all(14)
	cardsb.border_color = Color(1.0, 0.84, 0.42, 0.35)
	cardsb.set_border_width_all(1)
	cardsb.set_content_margin_all(30)
	cardsb.shadow_color = Color(0, 0, 0, 0.55)
	cardsb.shadow_size = 20
	card.add_theme_stylebox_override("panel", cardsb)
	add_child(card)

	root = VBoxContainer.new()
	root.custom_minimum_size = Vector2(440, 0)
	root.add_theme_constant_override("separation", 12)
	card.add_child(root)

	var title := Label.new()
	title.text = "COMMANDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	root.add_child(title)
	var tag := Label.new()
	tag.text = "— a war of the colonies —"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94))
	root.add_child(tag)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	root.add_child(spacer)

	_build_main()

	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color(0.80, 0.88, 1.0))
	root.add_child(status)

	Net.lobby_updated.connect(_refresh_lobby)

	var args := OS.get_cmdline_user_args()
	_use_upnp = "--upnp" in args               # open the router port for internet play
	if "--server" in args or "--dedicated" in args:
		_on_dedicated()                       # headless dedicated server: host, wait, auto-start
	elif "--auto-host" in args:
		_on_host()
		get_tree().create_timer(3.0).timeout.connect(_on_start)
	elif "--auto-join" in args:
		_on_join()
	elif "--test-soldiers" in args:
		get_tree().change_scene_to_file.call_deferred("res://test_soldiers.tscn")   # defer past _ready so the tree isn't mid-swap

# ------------------------------------------------------------------ main screen

func _build_main() -> void:
	var main := VBoxContainer.new()
	main.name = "Main"
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)
	root.move_child(main, 3)

	# FOCUS: historical battles. (The dynamic campaign — New Game / Continue / campaign hosting — is
	# disabled for now; its _on_world/_on_continue/_on_host/_on_dedicated handlers are kept below so a
	# button can be re-added when the campaign returns.)
	_btn(main, "Historical Battles", _on_historical)    # set-piece battles, authored to history (single-player + MP host)

	var mp_lbl := Label.new()
	mp_lbl.text = "MULTIPLAYER"
	mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_lbl.add_theme_font_size_override("font_size", 13)
	mp_lbl.add_theme_color_override("font_color", Color(0.66, 0.72, 0.82))
	var mp_top := Control.new(); mp_top.custom_minimum_size = Vector2(0, 8); main.add_child(mp_top)
	main.add_child(mp_lbl)

	# Host a battle from the Historical Battles screen ("Host Multiplayer"); clients join below.
	var iprow := HBoxContainer.new()
	iprow.add_theme_constant_override("separation", 6)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "host address"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iprow.add_child(ip_edit)
	var jb := Button.new()
	jb.text = "Join"
	jb.custom_minimum_size = Vector2(90, 0)
	jb.pressed.connect(_on_join)
	iprow.add_child(jb)
	main.add_child(iprow)

	var q_top := Control.new(); q_top.custom_minimum_size = Vector2(0, 8); main.add_child(q_top)
	_btn(main, "Animation Test", func(): get_tree().change_scene_to_file("res://test_soldiers.tscn"))   # soldier mesh/anim bench
	_btn(main, "Quit", func(): get_tree().quit())

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
	# a fresh province — discard any stowed campaign and battle handoff state, then raise
	# your militia before you ride to the war
	GameConfig.world_state = {}
	GameConfig.return_to_world = false
	GameConfig.setup = null
	GameConfig.battle_tokens = []
	GameConfig.has_militia = false
	GameConfig.load_requested = false
	_enter_campaign_intro()

# Historical Battles: a screen listing the set-piece battles, each authored into a BattleSetup.
func _on_historical() -> void:
	var main := root.get_node_or_null("Main")
	if main:
		main.queue_free()
	var box := VBoxContainer.new()
	box.name = "Historical"
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	root.move_child(box, 3)
	var hdr := Label.new()
	hdr.text = "HISTORICAL BATTLES"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	box.add_child(hdr)
	_btn(box, "Waterloo — 18 June 1815", func(): box.queue_free(); _choose_command("waterloo"))
	_btn(box, "Waterloo — Host Multiplayer", func(): box.queue_free(); _host_historical("waterloo"))
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 8); box.add_child(sp)
	_btn(box, "‹ Back", func(): box.queue_free(); _build_main())

# Host a set-piece battle online: players claim a command (either side) in the shared lobby, then the
# host starts. Reuses the campaign lobby — only the scenario flag differs.
func _host_historical(key: String) -> void:
	GameConfig.historical = key
	var err := Net.host_game(false, _use_upnp)
	if err != OK:
		GameConfig.historical = ""
		status.text = "Failed to host (error %d)" % err
		_build_main()
		return
	_enter_lobby()
	status.text = "Hosting %s on port %d — players claim a command and the host starts." % [key.capitalize(), Net.PORT]

# Choose which command to take into the battle — either side, any battalion in the order of battle.
func _choose_command(key: String) -> void:
	_hist_setup = Historical.make(key)
	if _hist_setup == null:
		status.text = "Unknown battle: %s" % key
		_build_main()
		return
	_hist_key = key
	# default to the side the scenario's default player unit is on
	_hist_side = 1
	for u in _hist_setup.units:
		if u.human_slot == 0:
			_hist_side = u.team
			break
	_show_command_picker()

func _show_command_picker() -> void:
	var old := root.get_node_or_null("CommandPick")
	if old:
		old.queue_free()
	var box := VBoxContainer.new()
	box.name = "CommandPick"
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	root.move_child(box, 3)
	var hdr := Label.new()
	hdr.text = "CHOOSE YOUR COMMAND"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	box.add_child(hdr)
	# the side toggle
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(srow)
	_side_tab(srow, 0, "Armée du Nord")
	_side_tab(srow, 1, "Anglo-Allied / Prussian")
	# the roster for the chosen side, grouped by brigade
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(500, 380)
	box.add_child(sc)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(480, 0)
	col.add_theme_constant_override("separation", 3)
	sc.add_child(col)
	var last_brig := -999
	for i in range(_hist_setup.units.size()):
		var u = _hist_setup.units[i]
		if u.team != _hist_side:
			continue
		if u.brigade != last_brig:
			last_brig = u.brigade
			var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 6); col.add_child(gap)
			var bl := Label.new()
			bl.text = "— Corps %s · Division %s · Brigade %s —" % [str(u.corps), str(u.division), str(u.brigade)]
			bl.add_theme_font_size_override("font_size", 12)
			bl.add_theme_color_override("font_color", Color(0.70, 0.78, 0.92))
			col.add_child(bl)
		_unit_btn(col, i, String(u.name), int(u.men))
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 8); box.add_child(sp)
	_btn(box, "‹ Back", func(): box.queue_free(); _on_historical())

# a side-selector tab; re-renders the picker for that side
func _side_tab(row: HBoxContainer, side: int, text: String) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(215, 38)
	b.add_theme_font_size_override("font_size", 15)
	var on := (side == _hist_side)
	b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62) if on else Color(0.78, 0.80, 0.86))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.17, 0.10, 0.95) if on else Color(0.10, 0.12, 0.16, 0.82)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.9) if on else Color(1.0, 0.84, 0.42, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(7)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(func():
		if _hist_side != side:
			_hist_side = side
			_show_command_picker())
	row.add_child(b)

# a compact roster button: take command of this battalion
func _unit_btn(col: VBoxContainer, idx: int, name: String, men: int) -> void:
	var b := Button.new()
	b.text = "   %s   (%d men)" % [name, men]
	b.custom_minimum_size = Vector2(470, 30)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.93, 0.91, 0.84))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.62))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.70)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(5)
	b.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(0.17, 0.19, 0.25, 0.92)
	sbh.border_color = Color(1.0, 0.88, 0.5, 0.9)
	b.add_theme_stylebox_override("hover", sbh)
	b.pressed.connect(func(): _pick_unit(idx))
	col.add_child(b)

func _pick_unit(idx: int) -> void:
	if _hist_setup == null or idx < 0 or idx >= _hist_setup.units.size():
		return
	for u in _hist_setup.units:
		u.human_slot = -1           # clear the scenario default
	_hist_setup.units[idx].human_slot = 0
	_launch_hist_setup(_hist_key, _hist_setup)

# launch a (possibly already-built) historical setup
func _launch_hist_setup(key: String, setup) -> void:
	GameConfig.world_state = {}
	GameConfig.return_to_world = false
	GameConfig.battle_tokens = []
	GameConfig.has_militia = false
	GameConfig.load_requested = false
	GameConfig.mode = "single"
	GameConfig.historical = key
	GameConfig.setup = setup
	GameConfig.match_seed = setup.seed_value
	GameConfig.local_slot = 0
	get_tree().change_scene_to_file("res://game.tscn")

func _launch_historical(key: String) -> void:
	var setup := Historical.make(key)
	if setup == null:
		status.text = "Unknown battle: %s" % key
		return
	_launch_hist_setup(key, setup)

# Resume the saved campaign: game.gd reads the save on start (seed, militia, towns, units).
func _on_continue() -> void:
	GameConfig.world_state = {}
	GameConfig.return_to_world = false
	GameConfig.setup = null
	GameConfig.battle_tokens = []
	GameConfig.mode = "single"
	GameConfig.load_requested = true
	get_tree().change_scene_to_file("res://game.tscn")

func _take_the_field() -> void:
	GameConfig.has_militia = true
	var nm := _ci_name.text.strip_edges()
	GameConfig.militia_name = nm if nm != "" else "1st Volunteers"
	GameConfig.militia_uniform = _ci_uniform
	GameConfig.militia_facing = GameConfig.FACING_SWATCHES[_ci_facing]
	GameConfig.militia_flag = _ci_flag
	GameConfig.militia_hat = _ci_hat
	GameConfig.militia_belt = _ci_belt
	GameConfig.militia_pants = _ci_pants
	GameConfig.militia_officers = _ci_officers.duplicate(true)
	# ONE SCENE: the campaign rides straight into the tactical province (no world.tscn
	# scene-swap). Your militia rides independent of the Crown's order of battle —
	# see _spawn_independent_militia() in game.gd.
	GameConfig.mode = "single"
	GameConfig.match_seed = randi() | 1
	GameConfig.local_slot = 52
	GameConfig.setup = null
	get_tree().change_scene_to_file("res://game.tscn")

# ---------------------------------------------- campaign intro: raise your militia

func _enter_campaign_intro() -> void:
	var main := root.get_node_or_null("Main")
	if main:
		main.queue_free()
	var box := VBoxContainer.new()
	box.name = "Intro"
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	root.move_child(box, 1)
	var hdr := Label.new()
	hdr.text = "RAISE YOUR MILITIA"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 24)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	box.add_child(hdr)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(500, 460)
	box.add_child(sc)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(480, 0)
	col.add_theme_constant_override("separation", 9)
	sc.add_child(col)
	var story := RichTextLabel.new()
	story.bbcode_enabled = true
	story.fit_content = true
	story.custom_minimum_size = Vector2(470, 0)
	story.text = "[color=#cdd6e6]The Crown and the Continentals are at war.\n\nAs the son of a wealthy family you have spurned the quiet life — taking your inheritance into the country to [color=#ffe9a8]raise a militia[/color] of local men and march them to the war. Choose their dress, their colours, the standard they will follow, and the officers who will lead them.[/color]"
	col.add_child(story)
	_ci_section(col, "NAME OF THE REGIMENT")
	_ci_name = LineEdit.new()
	_ci_name.text = "1st Volunteers"
	_ci_name.custom_minimum_size = Vector2(320, 0)
	col.add_child(_ci_name)
	_ci_section(col, "UNIFORM")
	_ci_uni_btns.clear()
	var ug := HBoxContainer.new()
	ug.add_theme_constant_override("separation", 4)
	for i in range(GameConfig.UNIFORM_NAMES.size()):
		var bi := i
		var b := Button.new()
		b.text = GameConfig.UNIFORM_NAMES[i]
		b.pressed.connect(func(): _ci_uniform = bi; _ci_hl(_ci_uni_btns, _ci_uniform))
		ug.add_child(b)
		_ci_uni_btns.append(b)
	col.add_child(ug)
	_ci_hl(_ci_uni_btns, _ci_uniform)
	_ci_section(col, "HEADGEAR")
	_ci_choice(col, GameConfig.HAT_NAMES, _ci_hat_btns, func(i): _ci_hat = i)
	_ci_hl(_ci_hat_btns, _ci_hat)
	_ci_section(col, "CROSSBELTS")
	_ci_choice(col, GameConfig.BELT_NAMES, _ci_belt_btns, func(i): _ci_belt = i)
	_ci_hl(_ci_belt_btns, _ci_belt)
	_ci_section(col, "TROUSERS")
	_ci_choice(col, GameConfig.PANTS_NAMES, _ci_pants_btns, func(i): _ci_pants = i)
	_ci_hl(_ci_pants_btns, _ci_pants)
	# FACING COLOUR customization removed for now — facings use the regimental default.
	_ci_section(col, "REGIMENTAL STANDARD")
	_ci_flag_btns.clear()
	var lg := HBoxContainer.new()
	lg.add_theme_constant_override("separation", 4)
	for i in range(GameConfig.FLAG_NAMES.size()):
		var bi := i
		var b := Button.new()
		b.text = GameConfig.FLAG_NAMES[i]
		b.pressed.connect(func(): _ci_flag = bi; _ci_hl(_ci_flag_btns, _ci_flag))
		lg.add_child(b)
		_ci_flag_btns.append(b)
	col.add_child(lg)
	_ci_hl(_ci_flag_btns, _ci_flag)
	_ci_section(col, "COMMISSION OFFICERS")
	var reroll := Button.new()
	reroll.text = "↻  Call a fresh slate of applicants"
	reroll.pressed.connect(_commission_officers)
	col.add_child(reroll)
	_ci_off_label = RichTextLabel.new()
	_ci_off_label.bbcode_enabled = true
	_ci_off_label.fit_content = true
	_ci_off_label.custom_minimum_size = Vector2(460, 0)
	col.add_child(_ci_off_label)
	_commission_officers()
	var go := Button.new()
	go.text = "▶  TAKE THE FIELD"
	go.custom_minimum_size = Vector2(0, 42)
	go.pressed.connect(_take_the_field)
	box.add_child(go)
	status.text = "Raise and dress your regiment, then march to the war."

func _ci_section(col: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	l.add_theme_font_size_override("font_size", 13)
	col.add_child(l)

func _ci_hl(btns: Array, sel: int) -> void:
	for i in range(btns.size()):
		(btns[i] as Button).modulate = Color(1, 1, 1, 1) if i == sel else Color(0.46, 0.48, 0.54, 1)

# A row of labelled choice buttons; `setter` receives the chosen index, `btns` is filled.
func _ci_choice(col: VBoxContainer, names: Array, btns: Array, setter: Callable) -> void:
	btns.clear()
	var g := HBoxContainer.new()
	g.add_theme_constant_override("separation", 4)
	for i in range(names.size()):
		var bi := i
		var b := Button.new()
		b.text = String(names[i])
		b.pressed.connect(func() -> void:
			setter.call(bi)
			_ci_hl(btns, bi))
		g.add_child(b)
		btns.append(b)
	col.add_child(g)

func _commission_officers() -> void:
	_ci_officers.clear()
	var fn := ["Richard", "James", "William", "Henry", "George", "Thomas", "Charles", "Edward",
		"Francis", "Samuel", "Daniel", "John", "Hugh", "Robert"]
	var ln := ["Sharpe", "Harper", "Cooper", "Vane", "Frost", "Mercer", "Slade", "Burke", "Hale",
		"Croft", "Brand", "Doyle", "Reed", "Ward", "Pike", "Tanner", "Rourke", "Gale"]
	for i in range(8):
		_ci_officers.append({ "name": "%s %s" % [fn[randi() % fn.size()], ln[randi() % ln.size()]],
			"skill": randf_range(42.0, 82.0) })
	_refresh_officers()

func _refresh_officers() -> void:
	if _ci_off_label == null:
		return
	var t := ""
	for i in range(_ci_officers.size()):
		var o: Dictionary = _ci_officers[i]
		t += "[color=#9fb0c8]%d Coy[/color]  Capt. [color=#e8ecf5]%s[/color]  [color=#8f98a8](leadership %d)[/color]\n" % [i + 1, o["name"], int(o["skill"])]
	_ci_off_label.text = t

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
	var cav_types: int = GS.CAV_TYPE_DATA.size()
	for r in range(GS.CAV_PER_TEAM):
		var arm: String = GS.CAV_TYPE_DATA[r % cav_types]["name"]
		var cb := Button.new()
		cb.text = "  %d%s Regiment of Horse — %s   (AI — not yet playable)" % [r + 1, _ord(r + 1), arm]
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
	GameConfig.historical = ""        # a campaign host is the living province, not a set-piece battle
	var err := Net.host_game(false, _use_upnp)
	if err != OK:
		status.text = "Failed to host (error %d)" % err
		return
	_enter_lobby()
	status.text = "Hosting on port %d — waiting for players…" % Net.PORT

# Headless/standalone dedicated server: host the match, command no battalion, and let Net
# auto-start the battle a short while after the first player joins.
func _on_dedicated() -> void:
	GameConfig.historical = ""        # the dedicated campaign server, not a set-piece battle
	var err := Net.host_game(true, _use_upnp)
	if err != OK:
		status.text = "Failed to start server (error %d)" % err
		print("[NET] dedicated host failed: error %d" % err)
		return
	status.text = "Dedicated server on port %d — waiting for players to join…" % Net.PORT
	print("[NET] dedicated server up on port %d, awaiting players" % Net.PORT)

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
	b.custom_minimum_size = Vector2(440, 46)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.62))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.82)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(9)
	b.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(0.17, 0.19, 0.25, 0.92)
	sbh.border_color = Color(1.0, 0.88, 0.5, 0.9)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.bg_color = Color(0.22, 0.17, 0.10, 0.95)
	b.add_theme_stylebox_override("pressed", sbp)
	b.pressed.connect(cb)
	box.add_child(b)
