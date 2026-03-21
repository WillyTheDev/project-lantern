extends Node
class_name PlayerMovement

@export var speed: float = 4.5
@export var jump_velocity: float = 6.5
@export var fall_acceleration: float = 20.0
@export var rotation_speed: float = 12.0

# Roll Parameters
@export var roll_speed: float = 10.0
@export var roll_duration: float = 0.5
@export var roll_cooldown: float = 15.0

const COYOTE_TIME = 0.15

var coyote_timer: float = 0.0
var roll_timer: float = 0.0
var roll_cooldown_timer: float = 0.0
var roll_direction: Vector3 = Vector3.ZERO

var player: CharacterBody3D

func _init(_player: CharacterBody3D) -> void:
	player = _player

func handle_movement(delta: float, input_dir: Vector2) -> Vector3:
	var velocity = player.velocity
	var camera_pivot = player.get_node_or_null("CameraPivot")
	var model = player.get_node_or_null("Model")
	
	# Update Cooldowns
	if roll_cooldown_timer > 0:
		roll_cooldown_timer -= delta
		
	# --- ROLL LOGIC ---
	if roll_timer > 0:
		roll_timer -= delta
		player.is_rolling = true
		if roll_timer <= 0:
			player.is_rolling = false
		return roll_direction * roll_speed + Vector3(0, velocity.y, 0) # Maintain vertical velocity

	# Trigger Roll
	if Input.is_action_just_pressed("roll") and roll_cooldown_timer <= 0 and player.is_on_floor():
		_start_roll(input_dir, camera_pivot)
		return player.velocity

	var current_speed = speed
	if player.animations and player.animations.is_attacking():
		current_speed *= 0.4 # Reduce speed down when attacking
	
	if player.get("is_blocking"):
		current_speed *= 0.5 # Slow down when blocking
	
	var cam_basis = camera_pivot.global_transform.basis if camera_pivot else player.global_transform.basis
	var forward = -cam_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right = cam_basis.x
	right.y = 0
	right = right.normalized()

	var is_aiming = false
	if Input.is_action_pressed("right_click"):
		if player.inventory:
			var item = player.inventory.get_active_item()
			if item:
				var data = ItemService.get_item(item.id)
				if data and (data.type == ItemData.Type.RANGED or data.type == ItemData.Type.MAGIC):
					is_aiming = true

	if is_aiming and model:
		var aim_dir = forward
		var camera = player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
		
		if camera and camera.current:
			var viewport = camera.get_viewport()
			if viewport:
				var center = viewport.get_visible_rect().size / 2.0
				var crosshair_origin = camera.project_ray_origin(center)
				var crosshair_dir = camera.project_ray_normal(center)
				
				var space_state = player.get_world_3d().direct_space_state
				var query = PhysicsRayQueryParameters3D.create(crosshair_origin, crosshair_origin + (crosshair_dir * 100.0), 3)
				query.exclude = [player.get_rid()]
				var result = space_state.intersect_ray(query)
				
				var target_pos = crosshair_origin + (crosshair_dir * 100.0)
				if result:
					target_pos = result.position
				
				var origin = player.global_position + Vector3(0, 1.5, 0)
				var skeleton = player.get_node_or_null("Model/rig_deform/GeneralSkeleton")
				if skeleton and player.inventory:
					var item = player.inventory.get_active_item()
					if item:
						var data = ItemService.get_item(item.id)
						if data and data.get("attachment_bone"):
							var bone = skeleton.get_node_or_null(data.attachment_bone)
							if bone: origin = bone.global_position
				
				var shoot_dir = (target_pos - origin).normalized()
				shoot_dir.y = 0
				if shoot_dir.length_squared() > 0.01:
					aim_dir = shoot_dir.normalized()
					
		var target_angle = atan2(-aim_dir.x, -aim_dir.z) + PI
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * 1.5 * delta)

	if input_dir.length() > 0.1:
		var direction = (forward * -input_dir.y + right * input_dir.x).normalized()
		if model and direction != Vector3.ZERO and not is_aiming:
			var target_angle = atan2(-direction.x, -direction.z) + PI
			model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)
		
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * 10 * delta)
		velocity.z = move_toward(velocity.z, 0, current_speed * 10 * delta)

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
		if player.animations:
			player.animations.play_jump()

	return velocity

func _start_roll(input_dir: Vector2, camera_pivot: Node3D) -> void:
	roll_timer = roll_duration
	roll_cooldown_timer = roll_cooldown
	player.is_rolling = true
	
	if input_dir.length() > 0.1:
		var cam_basis = camera_pivot.global_transform.basis if camera_pivot else player.global_transform.basis
		var forward = -cam_basis.z
		forward.y = 0
		var right = cam_basis.x
		right.y = 0
		roll_direction = (forward * -input_dir.y + right * input_dir.x).normalized()
	else:
		# Roll forward based on model orientation
		var model = player.get_node_or_null("Model")
		if model:
			roll_direction = -model.global_transform.basis.z
		else:
			roll_direction = -player.global_transform.basis.z
			
	if player.animations:
		player.animations.play_roll()
