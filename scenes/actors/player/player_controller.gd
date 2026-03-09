extends CharacterBody3D


@export var speed = 3.5
@export var jump_velocity = 6.5
@export var fall_acceleration = 20.0
@export var interpolation_speed = 15.0
@export var sync_position: Vector3

@export var player_id: int = 1
@export var player_name: String = ""
@export var display_name: String = "": # AdjectiveAnimal name displayed above player
	set(value):
		display_name = value
		_update_nametag()
@export var name_color: Color = Color.WHITE: # RGB color for the player's name
	set(value):
		name_color = value
		_update_nametag()

# This is the variable you will add to the MultiplayerSynchronizer!
@export var shared_velocity: Vector3 = Vector3.ZERO

# VOIP Variables
var voice_playback: AudioStreamOpusChunked
var voice_player: AudioStreamPlayer3D
var local_mic_player: AudioStreamPlayer
var voice_timer: float = 0.0

const MOUSE_SENSIBILITY = 0.002
const COYOTE_TIME = 0.15
var coyote_timer = 0.0

var interact_ray: RayCast3D

func _enter_tree() -> void:
	set_multiplayer_authority(player_id)
	
func _ready() -> void:
	# Exclude the player's own body from SpringArm3D collision
	$CameraPivot/SpringArm3D.add_excluded_object(get_rid())

	# Check if this specific player instance belongs to the local machine
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		var camera = $CameraPivot/SpringArm3D/Camera3D
		camera.make_current()
		
		# Set display name from persistence
		display_name = PersistenceManager.current_player_name
		
		# --- INTERACTION SETUP ---
		# Create a RayCast3D to detect interactable objects
		interact_ray = RayCast3D.new()
		interact_ray.target_position = Vector3(0, 0, -2.5) # Reach of 2.5 meters
		interact_ray.enabled = true
		camera.add_child(interact_ray)
		
		# --- LOCAL MIC CAPTURE SETUP ---
		# Create an AudioStreamPlayer that uses the Microphone stream
		# and sends its output to our custom capture bus
		local_mic_player = AudioStreamPlayer.new()
		local_mic_player.stream = AudioStreamMicrophone.new()
		local_mic_player.bus = VoiceManager.VOICE_BUS_NAME
		add_child(local_mic_player)
		local_mic_player.play()
		print("[Player] Local mic capture started for player: ", player_id)
	else:
		$CameraPivot/SpringArm3D/Camera3D.current = false
		
		# --- REMOTE PLAYER VOIP SETUP ---
		# Create a 3D player so we can hear this specific peer in 3D space
		voice_player = AudioStreamPlayer3D.new()
		voice_playback = AudioStreamOpusChunked.new()
		voice_player.stream = voice_playback
		# Standard proximity settings
		voice_player.max_distance = 25.0
		voice_player.unit_size = 5.0
		add_child(voice_player)
		voice_player.play()
		
		# Listen for voice packets for this specific peer
		VoiceManager.voice_packet_received.connect(_on_voice_packet_received)
		print("[Player] Remote spatial VOIP initialized for player: ", player_id)
	
	_update_nametag()

func _on_voice_packet_received(peer_id: int, packet: PackedByteArray) -> void:
	# Only process if the packet belongs to THIS player instance
	if peer_id == player_id and voice_playback:
		voice_timer = 0.2 # Keep indicator visible for ~200ms after last packet
		if voice_playback.chunk_space_available():
			voice_playback.push_opus_packet(packet, 0, 0)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSIBILITY)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_settings_menu()

	if event.is_action_pressed("interact"):
		_try_interact()

func _try_interact() -> void:
	if interact_ray and interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if collider:
			print("[Player] Interacting with: ", collider.name)
			if collider.has_method("interact"):
				collider.interact(self)
			elif collider.get_parent().has_method("interact"):
				collider.get_parent().interact(self)

func _toggle_settings_menu() -> void:
	var settings_scene = preload("res://ui/SettingsMenu.tscn")
	# Check if menu is already open
	var existing_menu = get_tree().root.get_node_or_null("SettingsMenu")
	
	if existing_menu:
		existing_menu.queue_free()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		var menu = settings_scene.instantiate()
		menu.name = "SettingsMenu"
		get_tree().root.add_child(menu)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	# --- VOICE ACTIVITY VISUALS ---
	if is_multiplayer_authority():
		# Sync local visual with the logic in VoiceManager
		if VoiceManager.is_talking:
			voice_timer = 0.2
	
	if voice_timer > 0:
		voice_timer -= delta
		$VoiceIndicator.visible = true
	else:
		$VoiceIndicator.visible = false

	if is_multiplayer_authority():
		# 1. Horizontal Movement
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		# Negate input to match the 180° rotated model and transform relative to facing
		var direction = (transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()

		shared_velocity.x = direction.x * speed
		shared_velocity.z = direction.z * speed

		# 2. Gravity & Coyote Timer
		if is_on_floor():
			shared_velocity.y = 0 # Stop falling when on floor
			coyote_timer = COYOTE_TIME
		else:
			shared_velocity.y -= fall_acceleration * delta
			coyote_timer -= delta

		# 3. Jump Logic
		if coyote_timer > 0.0 and Input.is_action_just_pressed("jump"):
			shared_velocity.y = jump_velocity
			coyote_timer = 0.0 # Consume coyote time so we can't double jump


		# 4. Apply to the BUILT-IN velocity so physics works
		velocity = shared_velocity
		move_and_slide()
		
		# 5. Respawn player when it fall below the map
		if position.y < -20:
			sync_respawn.rpc()
			
		# 5. Update shared_velocity after move_and_slide 
		# (This catches if the physics engine stopped us, like hitting a wall)
		shared_velocity = velocity
		sync_position = global_position
	else:
		# --- REMOTE CLIENT LOGIC ---
		velocity = shared_velocity
		move_and_slide()
		# 2. Gently pull the player toward the "True" position (Compensation)
		if global_position.distance_to(sync_position) > 2.0:
			# LAG IS TOO HIGH: Just snap to the correct spot
			global_position = sync_position
		else:
			# LAG IS MANAGEABLE: Smoothly transition
			global_position = global_position.lerp(sync_position, 10 * delta)

@rpc("authority", "call_local", "reliable")
func sync_respawn():
	print("RESPAWNING PLAYER ON ALL CLIENTS")
	var spawn_node = get_parent().find_child("SpawnPoint")
	if spawn_node:
		global_position = spawn_node.global_position
		velocity = Vector3.ZERO
		shared_velocity = Vector3.ZERO
		force_update_transform()

func _update_nametag() -> void:
	if has_node("NameTag"):
		var nametag = $NameTag
		nametag.text = display_name if display_name != "" else "Player"
		nametag.modulate = name_color
		# Hide nametag for local player (show your name in Tab menu instead)
		nametag.visible = not is_multiplayer_authority()
