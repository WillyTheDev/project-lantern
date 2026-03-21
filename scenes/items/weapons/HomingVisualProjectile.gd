extends Node3D
class_name HomingVisualProjectile

var target_node: Node3D
var target_position: Vector3
var speed: float = 25.0
var active: bool = false
var lifetime: float = 5.0
var max_distance: float = 100.0
var distance_traveled: float = 0.0

var velocity: Vector3
var turn_speed: float = 2.0
var curve_intensity: float = 1.0

func fire_homing(start_pos: Vector3, target_n: Node3D, fallback_pos: Vector3, proj_speed: float) -> void:
	global_position = start_pos
	target_node = target_n
	target_position = fallback_pos
	speed = proj_speed
	
	# Create an initial arc
	var dist = start_pos.distance_to(target_n.global_position)
	var to_target = start_pos.direction_to(target_n.global_position)
	var right = Vector3.UP.cross(to_target).normalized()
	if right == Vector3.ZERO: right = Vector3.RIGHT
	
	# Randomize curve direction (left, right, or up)
	var curve_dir = (Vector3.UP + right * randf_range(-1.5, 1.5)).normalized()
	
	# Start velocity angled away from the target to create the arc
	velocity = (to_target + curve_dir * 1.5).normalized() * speed
	curve_intensity = clamp(15.0 / max(dist, 1.0), 1.0, 5.0) # Scales turn speed based on distance
	
	look_at(global_position + velocity, Vector3.UP)
	active = true

func fire(start_pos: Vector3, end_pos: Vector3, proj_speed: float) -> void:
	# Fallback to straight line if no target
	global_position = start_pos
	target_position = end_pos
	speed = proj_speed
	var dir = start_pos.direction_to(end_pos)
	if dir == Vector3.ZERO: dir = -global_transform.basis.z
	velocity = dir * speed
	look_at(global_position + velocity, Vector3.UP)
	active = true

func _process(delta: float) -> void:
	if not active: return
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
		
	distance_traveled += velocity.length() * delta
	if distance_traveled >= max_distance:
		queue_free()
		return
		
	var current_target_pos = target_position
	if is_instance_valid(target_node):
		if target_node.has_method("get_target_position"):
			current_target_pos = target_node.get_target_position()
		else:
			# Target middle of standard humanoid if possible
			current_target_pos = target_node.global_position + Vector3(0, 1.0, 0)
			
	var distance = global_position.distance_to(current_target_pos)
	
	# If we have a target node, steer towards it
	if is_instance_valid(target_node):
		var exact_dir = global_position.direction_to(current_target_pos)
		var turn_rate = turn_speed * curve_intensity
		if distance < 3.0:
			turn_rate *= 3.0 # Snap sharply when very close
			
		var desired_velocity = exact_dir * speed
		velocity = velocity.lerp(desired_velocity, turn_rate * delta)
	
	var move_dist = velocity.length() * delta
	
	if distance <= move_dist or distance < 0.5:
		global_position = current_target_pos
		queue_free()
	else:
		global_position += velocity * delta
		var nforward = velocity.normalized()
		if nforward.length_squared() > 0.01 and abs(nforward.y) < 0.99:
			look_at(global_position + nforward, Vector3.UP)
