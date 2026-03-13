extends Node
class_name PlayerMovement

@export var speed: float = 3.5
@export var jump_velocity: float = 6.5
@export var fall_acceleration: float = 20.0
const COYOTE_TIME = 0.15

var coyote_timer: float = 0.0
var player: CharacterBody3D

func _init(_player: CharacterBody3D) -> void:
	player = _player

func handle_movement(delta: float, input_dir: Vector2) -> Vector3:
	var direction = (player.transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()
	var velocity = player.velocity

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

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
