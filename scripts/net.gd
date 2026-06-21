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
# the multiplayer skirmish is per_side battalions a team; the claimable command
# slots are global unit indices: 0..MP_PER_SIDE-1 = team 0, the rest = team 1.
const MP_PER_SIDE := 8
# interleaved so the first players to join end up on opposing sides
const HUMAN_SLOTS := [0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15]
const DEDICATED_START_GRACE := 8.0   # a dedicated server kicks off this long after the first player joins

var lobby: Dictionary = {}      # peer_id -> battalion slot (synced to everyone)
var game: Node = null           # the running battle, set by game.gd
var dedicated := false          # this peer is a headless dedicated server (commands no battalion)
var _started := false           # the battle has been launched (guards a double start)

# ---------------------------------------------------------------- hosting / joining

# Start hosting. dedicated_mode = true → a headless server with no battalion of its own.
func host_game(dedicated_mode := false) -> int:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(PORT, MAX_PEERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	GameConfig.mode = "host"
	dedicated = dedicated_mode
	GameConfig.dedicated = dedicated_mode
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

# tear everything down and return to a clean single-player state
func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	lobby = {}
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
	rpc("_sync_lobby", lobby)
	_sync_lobby(lobby)                # apply on the host too

@rpc("authority", "call_local", "reliable")
func _sync_lobby(l: Dictionary) -> void:
	lobby = l
	var myid := multiplayer.get_unique_id()
	if lobby.has(myid):
		GameConfig.local_slot = lobby[myid]
	emit_signal("lobby_updated")

func human_slots() -> Array:
	return lobby.values()

func slot_label(slot: int) -> String:
	if slot < MP_PER_SIDE:
		return "Foot %d" % (slot + 1)
	return "Prov %d" % (slot - MP_PER_SIDE + 1)

# ---------------------------------------------------------------- match start

func start_game() -> void:
	if not multiplayer.is_server() or _started:
		return
	if dedicated and lobby.is_empty():
		return                        # nobody to play — keep waiting
	_started = true
	# author the shared skirmish (small enough to sync) and hand it to everyone
	var setup := BattleSetup.skirmish(MP_PER_SIDE, lobby.values())
	rpc("_load_battle", setup.to_dict())

@rpc("authority", "call_local", "reliable")
func _load_battle(setup_dict: Dictionary) -> void:
	var setup := BattleSetup.from_dict(setup_dict)
	GameConfig.setup = setup
	GameConfig.match_seed = setup.seed_value
	GameConfig.return_to_world = false
	GameConfig.load_requested = false
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
