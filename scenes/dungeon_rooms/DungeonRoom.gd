@tool
extends Node3D
class_name DungeonRoom

@export_group("Connectivity")
@export var has_north: bool = false
@export var has_east: bool = false
@export var has_south: bool = false
@export var has_west: bool = false

## If the mesh is modeled E-W but marked N-S, set this to 1. 
## It adjusts the visual rotation without breaking the logic.
@export var mesh_rotation_offset: int = 0

@export_group("Room Settings")
@export var size: Vector2i = Vector2i(1, 1)
@export_enum("corridor", "room", "special", "spawn", "exit") var type: String = "room"

func _ready() -> void:
	_create_collisions_recursive(self)
	_reconstruct_transform_from_name()

func _reconstruct_transform_from_name() -> void:
	var parts = name.split("_")
	if parts.size() >= 5 and parts[0] == "Room":
		var gx = int(parts[1])
		var gy = int(parts[2])
		var gz = int(parts[3])
		var rot_idx = int(parts[4])
		var g_size = 8.0
		if get_parent() and "grid_size" in get_parent(): g_size = get_parent().grid_size
		position = Vector3(gx * g_size, gy * g_size, gz * g_size)
		# Apply CW rotation + mesh offset
		rotation.y = -(rot_idx + mesh_rotation_offset) * (PI / 2.0)

func _create_collisions_recursive(node: Node) -> void:
	if node is MeshInstance3D: node.create_trimesh_collision()
	for child in node.get_children(): _create_collisions_recursive(child)

## Returns a bitmask (N=1, E=2, S=4, W=8) representing doors after CW rotation
func get_mask_for_rotation(rot_idx: int) -> int:
	var bits = [has_north, has_east, has_south, has_west]
	var mask = 0
	for i in range(4):
		if bits[i]:
			# CW rotation: Index 0(N) + 1(rot) = Index 1(E)
			var new_idx = (i + rot_idx) % 4
			mask |= (1 << new_idx)
	return mask
