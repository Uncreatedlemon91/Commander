extends Node

# Proximity voice chat (autoload). Hold V to talk; your voice is streamed to the
# other peers and played from your COMMANDER's position, so it pans and fades with
# distance like any other battlefield sound.
#
# EXPERIMENTAL: needs a microphone, "Audio > Enable Input" on (set in project),
# and an active multiplayer session. Uses raw PCM (LAN-friendly, not bandwidth
# optimised). If it misbehaves, it simply stays silent — it won't affect SFX.

const PTT_KEY := KEY_T   # push-to-talk (V is the FIRE command)

var _cap: AudioEffectCapture
var _mic: AudioStreamPlayer
var _talking := false
var _peers: Dictionary = {}   # peer_id -> AudioStreamPlayer2D
var _ready_ok := false

func _ready() -> void:
	_setup()

func _setup() -> void:
	var idx := AudioServer.get_bus_index("Capture")
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Capture")
		AudioServer.add_bus_effect(idx, AudioEffectCapture.new())
		AudioServer.set_bus_mute(idx, true)   # don't hear our own mic
	_cap = AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "Capture"
	add_child(_mic)
	_ready_ok = _cap != null

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == PTT_KEY and not event.echo:
		_talking = event.pressed
		if _talking and _mic and not _mic.playing:
			_mic.play()

func _process(_delta: float) -> void:
	if not _ready_ok or multiplayer.multiplayer_peer == null:
		return
	if _talking:
		var avail := _cap.get_frames_available()
		if avail > 0:
			var buf := _cap.get_buffer(avail)
			var mono := PackedFloat32Array()
			mono.resize(buf.size())
			for i in range(buf.size()):
				mono[i] = buf[i].x
			var p := _local_pos()
			rpc("_recv_voice", mono, p.x, p.y)
	else:
		_cap.clear_buffer()

@rpc("any_peer", "call_remote", "unreliable")
func _recv_voice(samples: PackedFloat32Array, px: float, py: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	var player: AudioStreamPlayer2D = _peers.get(id)
	if not is_instance_valid(player):
		player = AudioStreamPlayer2D.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = AudioServer.get_mix_rate()
		gen.buffer_length = 0.3
		player.stream = gen
		player.max_distance = 3200.0
		add_child(player)
		player.play()
		_peers[id] = player
	player.global_position = Vector2(px, py)
	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var room := pb.get_frames_available()
		var count: int = min(room, samples.size())
		for i in range(count):
			pb.push_frame(Vector2(samples[i], samples[i]))

func _local_pos() -> Vector2:
	# 3D game: proxy the officer's ground position (x,z) for panning
	if is_instance_valid(Net.game) and "off_pos" in Net.game:
		var p: Vector3 = Net.game.off_pos
		return Vector2(p.x, p.z)
	return Vector2.ZERO
