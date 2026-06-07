extends Node

# Peer-to-peer networking (autoload). The host runs the authoritative simulation;
# clients render synced state and send order requests to the host.
#
# Multiplayer here is server-authoritative:
#   - Host + single-player run the full battalion simulation.
#   - Clients do NOT simulate; they receive battalion state snapshots from the
#     host and render them, and forward player orders to the host via RPC.

signal lobby_updated

const PORT := 24555

var peers: Dictionary = {}   # peer_id -> team
var game: Node = null        # set by GameManager when the battle loads

func host_game(team: int) -> int:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(PORT, 32)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	GameConfig.mode = "host"
	GameConfig.local_team = team
	peers[1] = team
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	emit_signal("lobby_updated")
	return OK

func join_game(ip: String, team: int) -> int:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	GameConfig.mode = "client"
	GameConfig.local_team = team
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	return OK

func _on_peer_connected(_id: int) -> void:
	emit_signal("lobby_updated")

func _on_peer_disconnected(id: int) -> void:
	peers.erase(id)
	emit_signal("lobby_updated")

func _on_connected_to_server() -> void:
	rpc_id(1, "_register", GameConfig.local_team)

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	GameConfig.mode = "single"

@rpc("any_peer", "call_remote", "reliable")
func _register(team: int) -> void:
	if multiplayer.is_server():
		peers[multiplayer.get_remote_sender_id()] = team
		emit_signal("lobby_updated")

func human_teams() -> Array:
	var set := {}
	for v in peers.values():
		set[v] = true
	if GameConfig.mode == "host":
		set[GameConfig.local_team] = true
	return set.keys()

func start_game() -> void:
	if multiplayer.is_server():
		rpc("_load_battle")

@rpc("authority", "call_local", "reliable")
func _load_battle() -> void:
	get_tree().change_scene_to_file("res://node_2d.tscn")

# --- orders from clients to host ---

func request_order(battalion_id: int, order: Dictionary) -> void:
	rpc_id(1, "_srv_order", battalion_id, order)

@rpc("any_peer", "call_remote", "reliable")
func _srv_order(battalion_id: int, order: Dictionary) -> void:
	if multiplayer.is_server() and game:
		game.order_battalion(battalion_id, order)
