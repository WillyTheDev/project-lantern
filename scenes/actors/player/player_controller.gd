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

const MOUSE_SENSIBILITY = 0.002
const COYOTE_TIME = 0.15
var coyote_timer = 0.0

func _enter_tree() -> void:
	set_multiplayer_authority(player_id)
	
func _ready() -> void:
	# Exclude the player's own body from SpringArm3D collision
	$CameraPivot/SpringArm3D.add_excluded_object(get_rid())

	# Check if this specific player instance belongs to the local machine
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$CameraPivot/SpringArm3D/Camera3D.make_current()
	else:
		$CameraPivot/SpringArm3D/Camera3D.current = false
	
	_update_nametag()

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSIBILITY)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
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
