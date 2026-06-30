extends Node

# Networking (autoload). Host-authoritative, with two host flavours:
#   - LISTEN SERVER ("Host Game"): the host BOTH plays a battalion AND runs the sim.
#   - DEDICATED SERVER ("--server" / "Dedicated Server"): a headless host that runs the
#     sim and serves clients but commands NO battalion of its own.
# In both, the HOST runs the full battle simulation (every battalion, the AI, combat);
# CLIENTS render the host's synced state, drive their own officer, and forward orders.
# Each player commands ONE battalion (a slot = a global unit index into the OOB).

signal lobby_updated
signal net_status(text: String)      # human-readable connection state, for the menu/HUD

const PORT := 24555
const MAX_PEERS := 16
# Multiplayer IS the campaign (one scene, no staged skirmish): each player commands one battalion
# inside the full order of battle and rides the living province. A slot is an abstract PLAYER INDEX
# (0..MAX); game.gd maps it to a brigade-lead battalion (even index -> Crown, odd -> Continental),
# so players spread across the field on opposing sides and take their orders from the command chain.
const MP_PER_SIDE := 8
const HUMAN_SLOTS := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
const DEDICATED_START_GRACE := 8.0   # a dedicated server kicks off this long after the first player joins

var lobby: Dictionary = {}      # peer_id -> battalion slot (synced to everyone)
var scenario: String = ""       # "" = the campaign field; else a historical key ("waterloo"), synced to clients
var game: Node = null           # the running battle, set by game.gd
var dedicated := false          # this peer is a headless dedicated server (commands no battalion)
var _started := false           # the battle has been launched (guards a double start)
var _upnp: UPNP = null          # the opened router port-mapping (for internet play), if any

# ---------------------------------------------------------------- hosting / joining

# Start hosting. dedicated_mode = true → a headless server with no battalion of its own.
# use_upnp = true → best-effort open the router's port so players can join over the internet.
func host_game(dedicated_mode := false, use_upnp := false) -> int:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(PORT, MAX_PEERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	if use_upnp:
		_try_upnp()
	GameConfig.mode = "host"
	dedicated = dedicated_mode
	GameConfig.dedicated = dedicated_mode
	scenario = GameConfig.historical    # "" for the campaign field; a key for a set-piece battle
	_started = false
	if dedicated_mode:
		lobby = {}                          # the server holds no command slot
		GameConfig.local_slot = -1
	else:
		lobby = { 1: HUMAN_SLOTS[0] }       # the listen-server's host plays the first slot
		GameConfig.local_slot = HUMAN_SLOTS[0]
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	emit_signal("lobby_updated")
	emit_signal("net_status", "Hosting on port %d%s" % [PORT, "  (dedicated)" if dedicated_mode else ""])
	return OK

func join_game(ip: String) -> int:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	GameConfig.mode = "client"
	GameConfig.dedicated = false
	_started = false
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	emit_signal("net_status", "Connecting to %s …" % ip)
	return OK

# Best-effort: ask the router (via UPnP) to forward our port to this machine, and report the
# public address players should connect to. Many networks disable UPnP — on failure we just tell
# the host to forward PORT/UDP by hand. NOTE: discover() blocks briefly while it probes the LAN.
func _try_upnp() -> void:
	var u := UPNP.new()
	var derr := u.discover()
	if derr != UPNP.UPNP_RESULT_SUCCESS:
		print("[NET] UPnP: no router found (%d). For internet play, forward port %d/UDP manually." % [derr, PORT])
		emit_signal("net_status", "UPnP unavailable — forward port %d (UDP) on your router" % PORT)
		return
	var gw := u.get_gateway()
	if gw == null or not gw.is_valid_gateway():
		print("[NET] UPnP: no valid gateway. Forward port %d/UDP manually." % PORT)
		return
	var merr := u.add_port_mapping(PORT, PORT, "Commander", "UDP", 0)
	var ext := u.query_external_address()
	if merr == UPNP.UPNP_RESULT_SUCCESS and ext != "":
		_upnp = u
		print("[NET] UPnP: port %d open. Players join at  %s  (port %d)" % [PORT, ext, PORT])
		emit_signal("net_status", "Internet ready — players join at %s" % ext)
	else:
		print("[NET] UPnP: port mapping failed (%d). External IP looks like %s; forward %d/UDP manually." % [merr, ext, PORT])
		emit_signal("net_status", "UPnP map failed — forward port %d (UDP) manually" % PORT)

# tear everything down and return to a clean single-player state
func leave() -> void:
	if _upnp != null:
		_upnp.delete_port_mapping(PORT, "UDP")
		_upnp = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	lobby = {}
	scenario = ""
	dedicated = false
	_started = false
	game = null
	GameConfig.mode = "single"
	GameConfig.dedicated = false
	emit_signal("lobby_updated")

# ---------------------------------------------------------------- peer lifecycle

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	# the match is already under way — a late joiner can't catch the running sim, so turn it
	# away cleanly instead of letting it sit nodeless and choke on state RPCs it can't route.
	if _started:
		print("[NET] peer %d turned away — match already in progress" % id)
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)
		return
	lobby[id] = _first_free_slot()
	print("[NET] peer %d connected -> slot %d (%d players)" % [id, lobby[id], lobby.size()])
	_broadcast_lobby()
	emit_signal("net_status", "%d player(s) connected" % lobby.size())
	# a dedicated server, having no operator to press "Start", kicks the match off itself
	# a short while after the first player arrives (a window for others to join the lobby)
	if dedicated and not _started:
		get_tree().create_timer(DEDICATED_START_GRACE).timeout.connect(_dedicated_autostart)

func _dedicated_autostart() -> void:
	if dedicated and not _started and multiplayer.is_server() and not lobby.is_empty():
		print("[NET] dedicated server starting the match with %d player(s)" % lobby.size())
		start_game()

func _on_peer_disconnected(id: int) -> void:
	var slot: int = lobby.get(id, -1)
	lobby.erase(id)
	print("[NET] peer %d disconnected (was slot %d)" % [id, slot])
	if multiplayer.is_server():
		# in-battle: hand that player's battalion back to the AI so the line doesn't freeze
		if game != null and slot >= 0 and game.has_method("net_player_left"):
			game.net_player_left(slot)
		_broadcast_lobby()
		emit_signal("net_status", "%d player(s) connected" % lobby.size())

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	GameConfig.mode = "single"
	print("[NET] connection failed")
	emit_signal("net_status", "Connection failed.")

func _on_connected_to_server() -> void:
	print("[NET] connected to server")
	emit_signal("net_status", "Connected — waiting in the lobby…")

# the host vanished. If we are mid-battle, bail to the menu; otherwise reset to single.
func _on_server_disconnected() -> void:
	print("[NET] server disconnected")
	multiplayer.multiplayer_peer = null
	GameConfig.mode = "single"
	dedicated = false
	_started = false
	emit_signal("net_status", "Lost the host.")
	if game != null and game.has_method("net_server_lost"):
		game.net_server_lost()

func _first_free_slot() -> int:
	for s in HUMAN_SLOTS:
		if not (s in lobby.values()):
			return s
	return HUMAN_SLOTS[0]

# ---------------------------------------------------------------- lobby / slots

# a player (local UI) asks for a battalion slot
func request_slot(slot: int) -> void:
	if multiplayer.is_server():
		_set_slot(1, slot)
	else:
		rpc_id(1, "_req_slot", slot)

@rpc("any_peer", "call_remote", "reliable")
func _req_slot(slot: int) -> void:
	if multiplayer.is_server():
		_set_slot(multiplayer.get_remote_sender_id(), slot)

func _set_slot(id: int, slot: int) -> void:
	if (slot in lobby.values()) and lobby.get(id, -1) != slot:
		return                        # already taken by someone else
	lobby[id] = slot
	_broadcast_lobby()

func _broadcast_lobby() -> void:
	rpc("_sync_lobby", lobby, scenario)
	_sync_lobby(lobby, scenario)      # apply on the host too

@rpc("authority", "call_local", "reliable")
func _sync_lobby(l: Dictionary, sc: String) -> void:
	lobby = l
	scenario = sc
	# clients learn the scenario from the lobby so their slot labels read right and (at load) the
	# battle builds the correct terrain; the host already has it set.
	if not multiplayer.is_server():
		GameConfig.historical = sc
	var myid := multiplayer.get_unique_id()
	if lobby.has(myid):
		GameConfig.local_slot = lobby[myid]
	emit_signal("lobby_updated")

func human_slots() -> Array:
	return lobby.values()

func slot_label(slot: int) -> String:
	if scenario != "":
		# a set-piece battle: even player-index → Anglo-Allied, odd → French
		return "%s — cmd %d" % ["Allied" if slot % 2 == 0 else "French", slot / 2 + 1]
	# the campaign field: even → Crown (team 0), odd → Continental (team 1)
	return "%s — cmd %d" % ["Crown" if slot % 2 == 0 else "Continental", slot / 2 + 1]

# ---------------------------------------------------------------- match start

func start_game() -> void:
	if not multiplayer.is_server() or _started:
		return
	if dedicated and lobby.is_empty():
		return                        # nobody to play — keep waiting
	_started = true
	# a set-piece historical battle, or the campaign field. For history, build the authored OOB and
	# bind the CLAIMED lobby slots to real battalions (each side's commands); for the campaign, hand
	# everyone the same seeded full field. Either way every peer gets the identical setup.
	var setup: BattleSetup
	if scenario != "":
		setup = Historical.make(scenario)
		if setup == null:
			setup = BattleSetup.default_field()
		else:
			Historical.assign_mp_slots(setup, lobby.values())
	else:
		setup = BattleSetup.default_field()
	rpc("_load_battle", setup.to_dict())

@rpc("authority", "call_local", "reliable")
func _load_battle(setup_dict: Dictionary) -> void:
	var setup := BattleSetup.from_dict(setup_dict)
	GameConfig.setup = setup
	GameConfig.match_seed = setup.seed_value
	GameConfig.historical = setup.historical   # flips _wmap → the right terrain + AI script on every peer
	GameConfig.return_to_world = false
	GameConfig.load_requested = false
	GameConfig.has_militia = false        # MP: every player commands an OOB battalion, not a militia
	print("[NET] loading battle (mode=%s, dedicated=%s, slot=%d, %d battalions)"
		% [GameConfig.mode, GameConfig.dedicated, GameConfig.local_slot, setup.units.size()])
	get_tree().change_scene_to_file("res://game.tscn")

# --- client -> host: my officer + my orders ---

func send_input(off_pos: Vector3, off_facing: float, order: Dictionary) -> void:
	rpc_id(1, "_srv_input", GameConfig.local_slot, off_pos, off_facing, order)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _srv_input(slot: int, off_pos: Vector3, off_facing: float, order: Dictionary) -> void:
	if multiplayer.is_server() and game:
		game.net_apply_input(slot, off_pos, off_facing, order)
