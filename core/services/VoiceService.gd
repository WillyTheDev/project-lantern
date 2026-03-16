extends Node

# The bus name used for capturing microphone input
const VOICE_BUS_NAME = "VoiceCaptureBus"
var voice_bus_idx: int = -1
var opuschunked: AudioEffectOpusChunked

# VAD Settings
var voice_threshold: float = 0.05 # 0.0 to 1.0 (5% default)
var is_talking: bool = false
var hang_timer: float = 0.0
const HANG_TIME_MAX: float = 0.8 # Seconds to keep sending audio after last peak

# Signal for packet distribution
signal voice_packet_received(peer_id: int, packet: PackedByteArray)

func _ready() -> void:
	# 1. Setup the Audio Bus for capturing
	_setup_voice_bus()
	
	# 2. Only run capture if we are the local client and not a server
	# Servers don't need to capture local mic input
	if NetworkService.current_role != NetworkService.Role.CLIENT:
		set_process(false)

func _setup_voice_bus() -> void:
	voice_bus_idx = AudioServer.get_bus_count()
	AudioServer.add_bus(voice_bus_idx)
	AudioServer.set_bus_name(voice_bus_idx, VOICE_BUS_NAME)
	
	# Mute the bus so we don't hear ourselves
	AudioServer.set_bus_mute(voice_bus_idx, true)
	
	# Add the OpusChunked effect
	# Note: This requires the twovoip GDExtension to be loaded correctly
	opuschunked = AudioEffectOpusChunked.new()
	AudioServer.add_bus_effect(voice_bus_idx, opuschunked)
	
	print("[VoiceService] Voice Capture Bus initialized at index: ", voice_bus_idx)

func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	# Prevent sending voice while in the main menu
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == SceneService.MENU_SCENE:
		while opuschunked and opuschunked.chunk_available():
			opuschunked.drop_chunk()
		is_talking = false
		return

	# Handle Hang Timer logic
	if is_talking:
		hang_timer -= delta
		if hang_timer <= 0:
			is_talking = false
			print("[VoiceService] Stopped talking (Hang Time ended)")

	# Read all available chunks
	while opuschunked and opuschunked.chunk_available():
		# VAD: Use denoise=true for more accurate speech detection
		var peak = opuschunked.chunk_max(true, false)
		
		if peak >= voice_threshold:
			if not is_talking:
				print("[VoiceService] Started talking (Threshold crossed)")
			is_talking = true
			hang_timer = HANG_TIME_MAX
		
		if is_talking:
			var packet = opuschunked.read_opus_packet(PackedByteArray())
			opuschunked.drop_chunk()
			if packet.size() > 0:
				send_voice_packet.rpc_id(1, packet)
		else:
			# Silence, drop the chunk to save CPU/Bandwidth
			opuschunked.drop_chunk()

@rpc("any_peer", "call_remote", "unreliable_ordered")
func send_voice_packet(packet: PackedByteArray) -> void:
	if not multiplayer.has_multiplayer_peer(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	# If we are the server, relay to all other clients
	if NetworkService.is_server():
		# Relay to all except sender
		# In a real game, you might check distance here to optimize
		# For now, simple relay to everyone
		receive_voice_packet.rpc(sender_id, packet)
	else:
		# If we are a client receiving this from server (via relay)
		receive_voice_packet(sender_id, packet)

@rpc("authority", "call_remote", "unreliable_ordered")
func receive_voice_packet(peer_id: int, packet: PackedByteArray) -> void:
	# Emit signal so the correct Player instance can pick it up
	voice_packet_received.emit(peer_id, packet)

