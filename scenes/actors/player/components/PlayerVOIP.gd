extends Node
class_name PlayerVOIP

var player: CharacterBody3D
var voice_playback: AudioStreamOpusChunked
var voice_player: AudioStreamPlayer3D
var local_mic_player: AudioStreamPlayer
var voice_timer: float = 0.0

func _init(_player: CharacterBody3D) -> void:
	player = _player

func setup_local() -> void:
	local_mic_player = AudioStreamPlayer.new()
	local_mic_player.stream = AudioStreamMicrophone.new()
	local_mic_player.bus = VoiceManager.VOICE_BUS_NAME
	player.add_child(local_mic_player)
	local_mic_player.play()

func setup_remote() -> void:
	voice_player = AudioStreamPlayer3D.new()
	voice_playback = AudioStreamOpusChunked.new()
	voice_player.stream = voice_playback
	voice_player.max_distance = 25.0
	voice_player.unit_size = 5.0
	player.add_child(voice_player)
	voice_player.play()
	VoiceManager.voice_packet_received.connect(_on_voice_packet_received)

func _on_voice_packet_received(peer_id: int, packet: PackedByteArray) -> void:
	if peer_id == player.player_id and voice_playback:
		voice_timer = 0.2
		if voice_playback.chunk_space_available():
			voice_playback.push_opus_packet(packet, 0, 0)

func process_voip(delta: float) -> bool:
	if player.is_multiplayer_authority():
		if VoiceManager.is_talking: voice_timer = 0.2
	
	if voice_timer > 0:
		voice_timer -= delta
		return true
	return false
