extends Node

# Peer-to-peer networking (autoload). Host-authoritative:
#   - The HOST runs the full battle simulation (every battalion, the AI, combat).
#   - CLIENTS render the host's synced battalion state, drive their own officer,
#     and forward their orders + officer position to the host.
# Each player commands ONE battalion (a slot = an index into the battalion array).

signal lobby_updated

const PORT := 24555
# the multiplayer skirmish is per_side battalions a team; the claimable command
# slots are global unit indices: 0..MP_PER_SIDE-1 = team 0, the rest = team 1.
const MP_PER_SIDE := 8
# interleaved so the first players to join end up on opposing sides
const HUMAN_SLOTS := [0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15]

var lobby: Dictionary = {}      # peer_id -> battalion slot (synced to everyone)
var game: Node = null           # the running battle, set by game.gd

func host_game() -> int:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(PORT, 8)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	GameConfig.mode = "host"
	lobby = { 1: HUMAN_SLOTS[0] }
	GameConfig.local_slot = HUMAN_SLOTS[0]
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	emit_signal("lobby_updated")
	return OK

func join_game(ip: String) -> int:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	GameConfig.mode = "client"
	multiplayer.connection_failed.connect(_on_connection_failed)
	return OK

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		lobby[id] = _first_free_slot()
		print("[NET] peer %d connected -> slot %d" % [id, lobby[id]])
		_broadcast_lobby()

func _on_peer_disconnected(id: int) -> void:
	lobby.erase(id)
	if multiplayer.is_server():
		_broadcast_lobby()

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	GameConfig.mode = "single"

func _first_free_slot() -> int:
	for s in HUMAN_SLOTS:
		if not (s in lobby.values()):
			return s
	return HUMAN_SLOTS[0]

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

func start_game() -> void:
	if multiplayer.is_server():
		# author the shared skirmish (small enough to sync) and hand it to everyone
		var setup := BattleSetup.skirmish(MP_PER_SIDE, lobby.values())
		rpc("_load_battle", setup.to_dict())

@rpc("authority", "call_local", "reliable")
func _load_battle(setup_dict: Dictionary) -> void:
	var setup := BattleSetup.from_dict(setup_dict)
	GameConfig.setup = setup
	GameConfig.match_seed = setup.seed_value
	GameConfig.return_to_world = false
	print("[NET] loading battle (mode=%s, slot=%d, %d battalions)" % [GameConfig.mode, GameConfig.local_slot, setup.units.size()])
	get_tree().change_scene_to_file("res://game.tscn")

# --- client -> host: my officer + my orders ---

func send_input(off_pos: Vector3, off_facing: float, order: Dictionary) -> void:
	rpc_id(1, "_srv_input", GameConfig.local_slot, off_pos, off_facing, order)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _srv_input(slot: int, off_pos: Vector3, off_facing: float, order: Dictionary) -> void:
	if multiplayer.is_server() and game:
		game.net_apply_input(slot, off_pos, off_facing, order)
