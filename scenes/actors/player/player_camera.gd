extends Camera3D

const MIN_SPRING_LENGTH = 5.5
const MAX_SPRING_LENGTH = 11.0
const ZOOM_STEP = 0.3
const MOUSE_SENSIBILITY = 0.002

var shake_intensity: float = 0.0
var shake_duration: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var spring_arm = get_parent() as SpringArm3D
	if spring_arm:
		spring_arm.spring_length = (MIN_SPRING_LENGTH + MAX_SPRING_LENGTH) / 2.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var pivot = get_parent().get_parent()
	if global_position.distance_to(pivot.global_position) > 0.01:
		look_at(pivot.global_position, Vector3.UP)
	
	if shake_duration > 0:
		shake_duration -= delta
		h_offset = randf_range(-1, 1) * shake_intensity
		v_offset = randf_range(-1, 1) * shake_intensity
		if shake_duration <= 0:
			h_offset = 0
			v_offset = 0
			shake_intensity = 0

func shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration

func _input(event: InputEvent) -> void:
	var spring_arm = get_parent() as SpringArm3D
	if spring_arm == null:
		return
	
	if event.is_pressed():
		if event.is_action("ZOOM_IN"):
			spring_arm.spring_length = max(spring_arm.spring_length - ZOOM_STEP, MIN_SPRING_LENGTH)
		elif event.is_action("ZOOM_OUT"):
			spring_arm.spring_length = min(spring_arm.spring_length + ZOOM_STEP, MAX_SPRING_LENGTH)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion:
		var pivot = get_parent().get_parent()
		pivot.rotate_x(event.relative.y * MOUSE_SENSIBILITY)
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))
