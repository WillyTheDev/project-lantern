@tool
extends Node3D

class_name DungeonGenerator

## DungeonGenerator
## Advanced procedural builder with Dynamic Tile Handshaking and Logging.

@export_group("Navigation Assets")
@export var hallways: Array[PackedScene] = []
@export var turns: Array[PackedScene] = []
@export var tris: Array[PackedScene] = []
@export var crosses: Array[PackedScene] = []

@export_group("Structure Assets")
@export var corner_tiles: Array[PackedScene] = []
@export var edge_tiles: Array[PackedScene] = []
@export var open_tiles: Array[PackedScene] = []
@export var doorway_tiles: Array[PackedScene] = []

@export_group("Functional Assets")
@export var spawn_room: PackedScene
@export var stairs_up_room: PackedScene
@export var stairs_down_room: PackedScene
@export var portal_room: PackedScene

@export_group("Special Assets")
@export var special_rooms: Array[PackedScene] = []
@export var simple_rooms: Array[PackedScene] = []

@export_group("Generation Settings")
@export var grid_size: float = 8.0
@export var vertical_grid_size: float = 4.0
@export var floors: int = 3
@export var rooms_per_floor: int = 12
@export var floor_width: int = 25
@export var floor_height: int = 25
@export var corridor_complexity: float = 0.6
@export var dungeon_seed: int = 0

@export_group("Editor Tools")
@export var auto_load_templates: bool = false:
	set(val):
		if val:
			_auto_load_all_templates_recursive()
			auto_load_templates = false
			notify_property_list_changed()

@export var clear_now: bool = false:
	set(val):
		if val:
			clear_dungeon()
			clear_now = false
			notify_property_list_changed()

@export var generate_now: bool = false:
	set(val):
		if val:
			print("[DungeonGenerator] Manual generation triggered.")
			if dungeon_seed == 0:
				randomize()
				dungeon_seed = randi()
			generate()
			generate_now = false
			notify_property_list_changed()

var _logical_grid: Dictionary = {}
@onready var room_templates: Array[PackedScene] = []

func _ready() -> void:
	_populate_templates()

func _auto_load_all_templates_recursive() -> void:
	print("[DungeonGenerator] Auto-loading templates...")
	var base = "res://scenes/dungeon_rooms/"
	hallways.clear()
	turns.clear()
	tris.clear()
	crosses.clear()
	corner_tiles.clear()
	edge_tiles.clear()
	open_tiles.clear()
	doorway_tiles.clear()
	special_rooms.clear()
	simple_rooms.clear()
	
	var all_files = _get_all_files_recursive(base)
	for file in all_files:
		var scene = load(file)
		if not scene is PackedScene:
			continue
		
		var f_lower = file.to_lower()
		if "hallway" in f_lower or "corridor" in f_lower:
			hallways.append(scene)
		elif "turn" in f_lower:
			turns.append(scene)
		elif "tri" in f_lower:
			tris.append(scene)
		elif "corner" in f_lower:
			corner_tiles.append(scene)
		elif "edge" in f_lower:
			edge_tiles.append(scene)
		elif "open" in f_lower:
			open_tiles.append(scene)
		elif "doorway" in f_lower:
			doorway_tiles.append(scene)
		elif "simple" in f_lower:
			simple_rooms.append(scene)
		elif "special" in f_lower:
			special_rooms.append(scene)
		elif "spawn" in f_lower:
			spawn_room = scene
		elif "portal" in f_lower:
			portal_room = scene
		elif "stair" in f_lower:
			if "up" in f_lower:
				stairs_up_room = scene
			elif "down" in f_lower:
				stairs_down_room = scene
			else: 
				if not stairs_up_room:
					stairs_up_room = scene
				else:
					stairs_down_room = scene
					
	print("[DungeonGenerator] Loading complete. Scenes: %d" % all_files.size())
	notify_property_list_changed()

func _get_all_files_recursive(path: String) -> Array[String]:
	var files: Array[String] = []
	if not DirAccess.dir_exists_absolute(path):
		return files
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if dir.current_is_dir():
				if not f.begins_with("."):
					files.append_array(_get_all_files_recursive(path.path_join(f)))
			elif f.ends_with(".tscn") or f.ends_with(".scn"):
				files.append(path.path_join(f))
			f = dir.get_next()
	return files

func _populate_templates() -> void:
	room_templates.clear()
	var all = [spawn_room, stairs_up_room, stairs_down_room, portal_room]
	all.append_array(hallways)
	all.append_array(turns)
	all.append_array(tris)
	all.append_array(crosses)
	all.append_array(special_rooms)
	all.append_array(simple_rooms)
	all.append_array(corner_tiles)
	all.append_array(edge_tiles)
	all.append_array(open_tiles)
	all.append_array(doorway_tiles)
	
	for res in all:
		if res and not room_templates.has(res):
			room_templates.append(res)
	room_templates.sort_custom(func(a, b): return a.resource_path < b.resource_path)

func clear_dungeon() -> void:
	_logical_grid.clear()
	for child in get_children():
		if not child.is_queued_for_deletion():
			child.free()

func generate(p_seed: int = -1) -> void:
	if not Engine.is_editor_hint() and not multiplayer.is_server():
		return
	_populate_templates()
	if room_templates.is_empty():
		return
	if p_seed != -1:
		dungeon_seed = p_seed
	elif dungeon_seed == 0:
		randomize()
		dungeon_seed = randi()
	seed(dungeon_seed)
	print("[DungeonGenerator] Generating Seed: %d" % dungeon_seed)
	clear_dungeon()
	_generate_bones()
	_generate_flesh()
	_generate_labyrinth_connectors()
	_instantiate_grid()
	print("[DungeonGenerator] Complete. Nodes: %d" % _logical_grid.size())

func _generate_bones() -> void:
	var spawn_pos = Vector3i(floor_width / 2, 0, floor_height / 2)
	_logical_grid[spawn_pos] = {"type": "spawn", "connections": 0}
	for y in range(floors):
		if y < floors - 1:
			var stairs_pos = _get_random_empty_pos(y)
			if stairs_pos != Vector3i(-1, -1, -1):
				_logical_grid[stairs_pos] = {"type": "stairs_up", "connections": 0}
				var down_pos = Vector3i(stairs_pos.x, y + 1, stairs_pos.z)
				_logical_grid[down_pos] = {"type": "stairs_down", "connections": 0}
		else:
			var portal_pos = _get_random_empty_pos(y)
			if portal_pos != Vector3i(-1, -1, -1):
				_logical_grid[portal_pos] = {"type": "portal", "connections": 0}

func _generate_flesh() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = dungeon_seed + 1
	for y in range(floors):
		for i in range(rooms_per_floor):
			var pos = _get_random_empty_pos(y)
			if pos == Vector3i(-1, -1, -1):
				break
			if rng.randf() > 0.8:
				_logical_grid[pos] = {"type": "special", "connections": 0}
			else:
				var size = Vector2i(1, 1)
				if rng.randf() > 0.5:
					size = Vector2i(2, 2)
				if _can_place_room(pos, size):
					_logical_grid[pos] = {"type": "simple", "size": size, "connections": 0}
					if size != Vector2i(1, 1):
						for ox in range(size.x):
							for oz in range(size.y):
								if ox == 0 and oz == 0:
									continue
								var occupied_pos = pos + Vector3i(ox, 0, oz)
								_logical_grid[occupied_pos] = {"type": "occupied", "parent": pos, "connections": 0}

func _generate_labyrinth_connectors() -> void:
	for y in range(floors):
		var key_rooms = []
		for pos in _logical_grid:
			if pos.y == y:
				var cell = _logical_grid[pos]
				if cell.type in ["spawn", "stairs_up", "stairs_down", "portal", "special", "simple"]:
					key_rooms.append(pos)
		if key_rooms.is_empty():
			continue
		var connected = [key_rooms.pop_front()]
		while not key_rooms.is_empty():
			var b_p1 = Vector3i.ZERO
			var b_p2 = Vector3i.ZERO
			var b_dist = 999999
			var b_idx = -1
			for i in range(key_rooms.size()):
				var p2 = key_rooms[i]
				for p1 in connected:
					var d = p1.distance_squared_to(p2)
					if d < b_dist:
						b_dist = d
						b_p1 = p1
						b_p2 = p2
						b_idx = i
			if b_idx != -1:
				_pathfind_connect(b_p1, b_p2)
				connected.append(key_rooms.pop_at(b_idx))
			else:
				break
		if connected.size() > 2:
			for i in range(int(connected.size() * corridor_complexity)):
				var p1 = connected[randi() % connected.size()]
				var p2 = connected[randi() % connected.size()]
				if p1 != p2 and p1.distance_to(p2) > 2:
					_pathfind_connect(p1, p2)

func _pathfind_connect(p1: Vector3i, p2: Vector3i) -> void:
	var astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, floor_width, floor_height)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for x in range(floor_width):
		for z in range(floor_height):
			var pos = Vector3i(x, p1.y, z)
			if pos == p1 or pos == p2:
				continue
			if _logical_grid.has(pos):
				var type = _logical_grid[pos].type
				if type == "corridor":
					astar.set_point_weight_scale(Vector2i(x, z), 0.1)
				else:
					astar.set_point_weight_scale(Vector2i(x, z), 50.0)
			else:
				astar.set_point_weight_scale(Vector2i(x, z), 1.0)
	var path = astar.get_id_path(Vector2i(p1.x, p1.z), Vector2i(p2.x, p2.z))
	if path.is_empty():
		return
	for i in range(path.size()):
		var curr_v3 = Vector3i(path[i].x, p1.y, path[i].y)
		if not _logical_grid.has(curr_v3):
			_logical_grid[curr_v3] = {"type": "corridor", "connections": 0}
		if i > 0:
			var prev_v3 = Vector3i(path[i-1].x, p1.y, path[i-1].y)
			var diff = path[i] - path[i-1]
			var bit = _vec2_to_bit(diff)
			_logical_grid[prev_v3].connections |= bit
			_logical_grid[curr_v3].connections |= _get_opposite_bit(bit)

func _vec2_to_bit(v: Vector2i) -> int:
	if v == Vector2i(0, -1): return 1 # North
	if v == Vector2i(1, 0): return 2  # East
	if v == Vector2i(0, 1): return 4  # South
	if v == Vector2i(-1, 0): return 8 # West
	return 0

func _get_opposite_bit(bit: int) -> int:
	if bit == 1: return 4
	if bit == 4: return 1
	if bit == 2: return 8
	if bit == 8: return 2
	return 0

func _instantiate_grid() -> void:
	for pos in _logical_grid:
		var cell = _logical_grid[pos]
		if cell.type == "occupied":
			continue
		if cell.type == "simple" and cell.has("size") and cell.size != Vector2i(1, 1):
			_skin_macro_room(pos, cell.size)
			continue
		var data = _select_scene_and_rotation(pos)
		if data.scene:
			_place_scene(pos, data.scene, data.rotation)

func _select_scene_and_rotation(pos: Vector3i) -> Dictionary:
	var cell = _logical_grid[pos]
	var mask = cell.connections
	var res = {"scene": null, "rotation": 0}
	match cell.type:
		"spawn": res.scene = spawn_room
		"portal": res.scene = portal_room
		"stairs_up": res.scene = stairs_up_room
		"stairs_down": res.scene = stairs_down_room
		"special": res.scene = _pick_best_template(mask, special_rooms)
		"simple": res.scene = _pick_best_template(mask, simple_rooms)
		"corridor": res.scene = _pick_connector_scene(pos)
	if res.scene:
		res.rotation = _calculate_handshake_rotation(mask, res.scene)
	return res

func _pick_best_template(target_mask: int, pool: Array[PackedScene]) -> PackedScene:
	if pool.is_empty():
		return null
	var best_scene = pool[0]
	var best_score = -999999
	for scene in pool:
		var inst = scene.instantiate()
		if not inst is DungeonRoom:
			inst.free()
			continue
		for r in range(4):
			var m = inst.get_mask_for_rotation(r)
			var score = _get_handshake_score(target_mask, m)
			if score > best_score:
				best_score = score
				best_scene = scene
		inst.free()
	return best_scene

func _get_handshake_score(target_mask: int, room_mask: int) -> int:
	var score = 0
	for i in [1, 2, 4, 8]:
		var has_target = (target_mask & i) > 0
		var has_room = (room_mask & i) > 0
		if has_target and has_room:
			score += 100
		elif has_target and not has_room:
			score -= 500 # High penalty for missing door
		elif not has_target and has_room:
			score -= 50  # Low penalty for extra door
	return score

func _pick_connector_scene(pos: Vector3i) -> PackedScene:
	var mask = _logical_grid[pos].connections
	var bits = 0
	for i in range(4):
		if mask & (1 << i):
			bits += 1
	if bits <= 2:
		if (mask == 5) or (mask == 10):
			return _get_random(hallways)
		else:
			return _get_random(turns)
	elif bits == 3:
		return _get_random(tris)
	else:
		if not crosses.is_empty():
			return _get_random(crosses)
		else:
			return _get_random(tris)

func _calculate_handshake_rotation(target_mask: int, scene: PackedScene) -> int:
	if target_mask == 0:
		return 0
	var inst = scene.instantiate()
	if not inst is DungeonRoom:
		inst.free()
		return 0
	var best_rot = 0
	var best_score = -999999
	
	var debug_log = "[Handshake] Scene: %s, TargetMask: %d\n" % [inst.name, target_mask]
	
	for r in range(4):
		var room_mask = inst.get_mask_for_rotation(r)
		var score = _get_handshake_score(target_mask, room_mask)
		debug_log += "  - Rot %d: ResultMask %d, Score %d\n" % [r, room_mask, score]
		if score > best_score:
			best_score = score
			best_rot = r
		if room_mask == target_mask:
			best_rot = r
			break
	
	if "Corner" in inst.name or "Hallway" in inst.name:
		print(debug_log + "  => Chose Rot %d with score %d" % [best_rot, best_score])
		
	inst.free()
	return best_rot

func _skin_macro_room(pos: Vector3i, size: Vector2i) -> void:
	for ox in range(size.x):
		for oz in range(size.y):
			var t_pos = pos + Vector3i(ox, 0, oz)
			var scene: PackedScene = null
			var rot = 0
			var t_mask = 0 # Calculate Internal + External Target Mask
			if oz > 0: t_mask |= 1 # N
			if ox < size.x - 1: t_mask |= 2 # E
			if oz < size.y - 1: t_mask |= 4 # S
			if ox > 0: t_mask |= 8 # W
			t_mask |= _logical_grid[t_pos].connections # Add corridor connection
			
			var is_min_x = (ox == 0)
			var is_max_x = (ox == size.x - 1)
			var is_min_z = (oz == 0)
			var is_max_z = (oz == size.y - 1)
			
			if _logical_grid[t_pos].connections > 0:
				scene = _get_random(doorway_tiles)
			elif (is_min_x or is_max_x) and (is_min_z or is_max_z):
				scene = _get_random(corner_tiles)
			elif is_min_x or is_max_x or is_min_z or is_max_z:
				scene = _get_random(edge_tiles)
			else:
				scene = _get_random(open_tiles)
			
			if scene:
				rot = _calculate_handshake_rotation(t_mask, scene)
				var inst = _place_scene(t_pos, scene, rot)
				# Log the logic for troubleshooting
				if "Corner" in inst.name:
					print("[Macro] Corner Tile at %s: Target=%d, Result=%d, ChoseRot=%d" % [t_pos, t_mask, (inst.get_mask_for_rotation(rot) if inst.has_method("get_mask_for_rotation") else 0), rot])

func _place_scene(pos: Vector3i, scene: PackedScene, rot: int) -> Node3D:
	var inst = scene.instantiate()
	inst.name = "Room_%d_%d_%d_%d" % [pos.x, pos.y, pos.z, rot]
	add_child(inst, true)
	inst.position = Vector3(pos.x * grid_size, pos.y * vertical_grid_size, pos.z * grid_size)
	var offset = 0
	if inst is DungeonRoom:
		offset = inst.mesh_rotation_offset
	inst.rotation.y = -(rot + offset) * (PI / 2.0)
	
	if Engine.is_editor_hint():
		var root = get_tree().edited_scene_root
		if root:
			inst.owner = root
		else:
			inst.owner = self
	else:
		inst.owner = self
	return inst

func _get_random_empty_pos(y: int) -> Vector3i:
	for i in range(500):
		var p = Vector3i(randi() % floor_width, y, randi() % floor_height)
		if not _logical_grid.has(p):
			return p
	return Vector3i(-1, -1, -1)

func _can_place_room(pos: Vector3i, size: Vector2i) -> bool:
	for ox in range(size.x):
		for oz in range(size.y):
			var p = pos + Vector3i(ox, 0, oz)
			if p.x >= floor_width or p.z >= floor_height or _logical_grid.has(p):
				return false
	return true

func _get_random(arr: Array[PackedScene]) -> PackedScene:
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]
