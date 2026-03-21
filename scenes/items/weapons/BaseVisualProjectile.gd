extends Node3D
class_name BaseVisualProjectile

var target_position: Vector3
var speed: float = 25.0
var active: bool = false
var lifetime: float = 3.0
var max_distance: float = 100.0
var distance_traveled: float = 0.0

func fire(start_pos: Vector3, end_pos: Vector3, proj_speed: float) -> void:
	global_position = start_pos
	target_position = end_pos
	speed = proj_speed
	look_at(target_position, Vector3.UP)
	active = true

func _process(delta: float) -> void:
	if not active: return
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
		
	distance_traveled += speed * delta
	if distance_traveled >= max_distance:
		queue_free()
		return
		
	var dir = global_position.direction_to(target_position)
	var distance = global_position.distance_to(target_position)
	var move_dist = speed * delta
	
	if move_dist >= distance:
		global_position = target_position
		# Could play an impact particle here!
		queue_free()
	else:
		global_position += dir * move_dist
