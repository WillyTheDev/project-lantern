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
		var camera = $CameraPivot/SpringArm3D/Camera3D
		camera.make_current()
		# Hide loading screen IMMEDIATELY now that camera is active
		SceneManager.show_loading_screen(false)
		
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		# Set display name from persistence
		display_name = PersistenceManager.current_player_name
		
		# --- INTERACTION SETUP ---
		interact_ray = RayCast3D.new()
		interact_ray.position.y = 0.5
		interact_ray.target_position = Vector3(0, 0, 2.5) 
		interact_ray.enabled = true
		interact_ray.add_exception(self)
		add_child(interact_ray)
		
		# --- INVENTORY SETUP ---
		var inv_ui = get_node_or_null("GUILayer/InventoryUI")
		if inv_ui:
			inv_ui.is_local_authority = true
			inv_ui.visible = true 
		
		InventoryManager.active_slot_changed.connect(refresh_held_item)
		# Initial refresh after a short delay to ensure DB data is loaded
		await get_tree().create_timer(0.2).timeout
		refresh_held_item()
		
		# --- LOCAL MIC CAPTURE SETUP ---
		local_mic_player = AudioStreamPlayer.new()
		local_mic_player.stream = AudioStreamMicrophone.new()
		local_mic_player.bus = VoiceManager.VOICE_BUS_NAME
		add_child(local_mic_player)
		local_mic_player.play()
		print("[Player] Local mic capture started for player: ", player_id)
	else:
		$CameraPivot/SpringArm3D/Camera3D.current = false
		
		# --- REMOTE PLAYER VOIP SETUP ---
		voice_player = AudioStreamPlayer3D.new()
		voice_playback = AudioStreamOpusChunked.new()
		voice_player.stream = voice_playback
		voice_player.max_distance = 25.0
		voice_player.unit_size = 5.0
		add_child(voice_player)
		voice_player.play()
		
		VoiceManager.voice_packet_received.connect(_on_voice_packet_received)
	
	_update_nametag()

func refresh_held_item(_index: int = -1) -> void:
	if not is_inside_tree(): return
	
	# Clear current hand
	for child in %HandPoint.get_children():
		child.queue_free()
		
	var item = InventoryManager.get_active_item()
	if not item: return
	
	var data = ItemDB.get_item(item.id)
	if data and data.item_scene:
		var instance = data.item_scene.instantiate()
		%HandPoint.add_child(instance)
		print("[Player] Instantiated held item: ", data.name)

func _on_voice_packet_received(peer_id: int, packet: PackedByteArray) -> void:
	if peer_id == player_id and voice_playback:
		voice_timer = 0.2
		if voice_playback.chunk_space_available():
			voice_playback.push_opus_packet(packet, 0, 0)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	# Hotbar switching (1-0 keys)
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			InventoryManager.set_active_slot(event.keycode - KEY_1)
		elif event.keycode == KEY_0:
			InventoryManager.set_active_slot(9)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSIBILITY)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_settings_menu()

	if event.is_action_pressed("interact"):
		_try_interact()
		
	if event.is_action_pressed("use_item"):
		_use_held_item()

func _use_held_item() -> void:
	# Get the first child of HandPoint (our held item)
	var held_item = %HandPoint.get_child(0) if %HandPoint.get_child_count() > 0 else null
	if held_item and held_item.has_method("use"):
		held_item.use()

func _try_interact() -> void:
	if interact_ray:
		if interact_ray.is_colliding():
			var collider = interact_ray.get_collider()
			if collider:
				print("[Player] Ray colliding with: ", collider.name)
				if collider.has_method("interact"):
					collider.interact(self)
				elif collider.get_parent() and collider.get_parent().has_method("interact"):
					collider.get_parent().interact(self)
		else:
			print("[Player] Ray not colliding. Target: ", interact_ray.target_position)

func _toggle_settings_menu() -> void:
	var settings_scene = preload("res://ui/SettingsMenu.tscn")
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
	if is_multiplayer_authority():
		if VoiceManager.is_talking: voice_timer = 0.2
	
	if voice_timer > 0:
		voice_timer -= delta
		$VoiceIndicator.visible = true
	else:
		$VoiceIndicator.visible = false

	if is_multiplayer_authority():
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction = (transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()

		shared_velocity.x = direction.x * speed
		shared_velocity.z = direction.z * speed

		if is_on_floor():
			shared_velocity.y = 0
			coyote_timer = COYOTE_TIME
		else:
			shared_velocity.y -= fall_acceleration * delta
			coyote_timer -= delta

		if coyote_timer > 0.0 and Input.is_action_just_pressed("jump"):
			shared_velocity.y = jump_velocity
			coyote_timer = 0.0

		velocity = shared_velocity
		move_and_slide()
		
		if position.y < -20:
			sync_respawn.rpc()
			
		shared_velocity = velocity
		sync_position = global_position
	else:
		velocity = shared_velocity
		move_and_slide()
		if global_position.distance_to(sync_position) > 2.0:
			global_position = sync_position
		else:
			global_position = global_position.lerp(sync_position, 10 * delta)

@rpc("authority", "call_local", "reliable")
func sync_respawn():
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
		nametag.visible = not is_multiplayer_authority()
