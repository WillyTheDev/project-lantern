extends Node

## DungeonMultiSpawner
## Handles server-authoritative spawning of players, enemies, and loot.

func _ready() -> void:
	# Setup Spawner
	var spawner = %MultiplayerPlayerSpawner
	spawner.spawn_function = custom_spawn
	spawner.add_spawnable_scene("res://scenes/actors/player/Player.tscn")
	spawner.add_spawnable_scene("res://scenes/world/interactables/LootDrop.tscn")
	spawner.add_spawnable_scene("res://scenes/actors/enemies/DungeonGuardian.tscn")
	
	# Server-side logic for Dungeon
	if multiplayer.is_server():
		NetworkManager.multiplayer.peer_connected.connect(_on_peer_connected)
		NetworkManager.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		# Spawn initial enemies at designated points
		call_deferred("_spawn_initial_enemies")

# --- SERVER SIDE CALLBACKS ---

func _spawn_initial_enemies():
	if not multiplayer.is_server(): return
	
	var enemy_points = get_tree().get_nodes_in_group("enemy_spawners")
	print("[Dungeon] Found ", enemy_points.size(), " enemy spawn points.")
	
	for point in enemy_points:
		_spawn_enemy("guardian", point.global_position)

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
		"type": "player",
		"player_name": "Player_%d" % peer_id,
		"peer_id": peer_id,
		"display_name": "Player_%d" % peer_id,
		"name_color": [0.8, 0.2, 0.2],
		"pos": spawn_pos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)),
		"inventory": InventoryManager.data.to_dict() if peer_id == 1 else {}
	}
	spawner.spawn(data)

func _spawn_enemy(enemy_type: String, pos: Vector3):
	var spawner = %MultiplayerPlayerSpawner
	var data = {
		"type": "enemy",
		"enemy_type": enemy_type,
		"pos": pos
	}
	spawner.spawn(data)

# --- SPANW FUNCTION ---

func custom_spawn(data: Dictionary) -> Node:
	var type = data.get("type", "player")
	var node: Node3D
	
	match type:
		"loot":
			node = preload("res://scenes/world/interactables/LootDrop.tscn").instantiate()
			if data.has("items"):
				node.items = data.items
		"enemy":
			var enemy_scene = preload("res://scenes/actors/enemies/DungeonGuardian.tscn")
			node = enemy_scene.instantiate()
			node.name = "Enemy_" + str(node.get_instance_id())
		"player":
			node = preload("res://scenes/actors/player/Player.tscn").instantiate()
			node.name = data.player_name
			node.player_id = data.peer_id
			node.display_name = data.get("display_name", "Player_%d" % data.peer_id)
			if "name_color" in data:
				var color_array = data.name_color
				node.name_color = Color(color_array[0], color_array[1], color_array[2], 1.0)
			
			if multiplayer.is_server() and data.has("inventory"):
				node.server_inventory = InventoryData.new()
				node.server_inventory.load_from_dict(data.inventory)
	
	if node:
		var pos = data.get("pos", Vector3.ZERO)
		node.position = pos
		if "sync_position" in node:
			node.sync_position = pos
	return node
