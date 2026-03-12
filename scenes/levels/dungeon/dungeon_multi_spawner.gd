extends Node

signal _on_player_spawned

func _ready() -> void:
	# Setup Spawner
	var spawner = %MultiplayerPlayerSpawner
	spawner.spawn_function = custom_spawn
	spawner.add_spawnable_scene("res://scenes/actors/player/Player.tscn")
	spawner.add_spawnable_scene("res://scenes/world/interactables/LootDrop.tscn")
	
	# Server-side connection handling for Dungeon
	if NetworkManager.current_role == NetworkManager.Role.DUNGEON_SERVER:
		NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
		NetworkManager.multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# --- SERVER SIDE CALLBACKS ---
func _on_peer_connected(peer_id: int):
	print("[Dungeon] Spawning player for: ", peer_id)
	_spawn_player(peer_id)

func _on_peer_disconnected(peer_id: int):
	var player_name = "Player_%d" % peer_id
	var spawner = %MultiplayerPlayerSpawner
	var spawn_path = spawner.spawn_path
	var spawn_node = get_node(spawn_path)
	var player_node = spawn_node.get_node_or_null(player_name)
	if player_node:
		player_node.queue_free()

func _spawn_player(peer_id: int):
	var spawner = %MultiplayerPlayerSpawner
	var spawn_pos = %SpawnPoint.global_position if has_node("%SpawnPoint") else Vector3.ZERO

	var data = {
		"player_name": "Player_%d" % peer_id,
		"peer_id": peer_id,
		"display_name": "Player_%d" % peer_id,
		"name_color": [0.8, 0.2, 0.2], # Redder color for dungeon
		"pos": spawn_pos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	}
	spawner.spawn(data)

# --- HELPER FUNCTIONS ---
func custom_spawn(data: Dictionary) -> Node3D:
	var type = data.get("type", "player")
	var node: Node3D
	
	if type == "loot":
		node = preload("res://scenes/world/interactables/LootDrop.tscn").instantiate()
		node.items = data.get("items", [])
	else:
		node = preload("res://scenes/actors/player/Player.tscn").instantiate()
		node.name = data.player_name
		node.player_id = data.peer_id
		node.display_name = data.get("display_name", "Player_%d" % data.peer_id)
		if "name_color" in data:
			var color_array = data.name_color
			node.name_color = Color(color_array[0], color_array[1], color_array[2], 1.0)
		
	node.global_position = data.pos
	return node
