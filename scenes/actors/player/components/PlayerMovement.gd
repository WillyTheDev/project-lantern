extends Node
class_name PlayerMovement

@export var speed: float = 4.5
@export var jump_velocity: float = 6.5
@export var fall_acceleration: float = 20.0
@export var rotation_speed: float = 12.0

const COYOTE_TIME = 0.15

var coyote_timer: float = 0.0
var player: CharacterBody3D

func _init(_player: CharacterBody3D) -> void:
	player = _player

func handle_movement(delta: float, input_dir: Vector2) -> Vector3:
	var velocity = player.velocity
	var camera_pivot = player.get_node_or_null("CameraPivot")
	var model = player.get_node_or_null("Model")
	
	if input_dir.length() > 0.1:
		# Calculate direction relative to CameraPivot
		var basis = camera_pivot.global_transform.basis if camera_pivot else player.global_transform.basis
		
		# Standard mapping for Action RPG:
		var direction = (basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		direction.y = 0
		
		# Smoothly rotate model to face movement direction
		if model and direction != Vector3.ZERO:
			# Adding PI (180 degrees) to fix the model facing the wrong way
			var target_angle = atan2(-direction.x, -direction.z) + PI
			model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)
		
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		# Friction/Braking
		velocity.x = move_toward(velocity.x, 0, speed * 10 * delta)
		velocity.z = move_toward(velocity.z, 0, speed * 10 * delta)

	# Gravity & Jump
	if player.is_on_floor():
		velocity.y = 0
		coyote_timer = COYOTE_TIME
	else:
		velocity.y -= fall_acceleration * delta
		coyote_timer -= delta

	if coyote_timer > 0.0 and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		coyote_timer = 0.0

	return velocity
