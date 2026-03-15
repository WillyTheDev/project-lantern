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
		# Wait for login success before spawning players
		PocketBaseRPCManager.server_player_login_completed.connect(_on_server_player_login_completed)
		NetworkService.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		# Spawn initial enemies at designated points
		call_deferred("_spawn_initial_enemies")

# --- SERVER SIDE CALLBACKS ---

func _spawn_initial_enemies():
	if not multiplayer.is_server(): return
	
	var enemy_points = get_tree().get_nodes_in_group("enemy_spawners")
	print("[Dungeon] Found ", enemy_points.size(), " enemy spawn points.")
	
	for point in enemy_points:
		_spawn_enemy("guardian", point.global_position)

func _on_server_player_login_completed(peer_id: int, pb_data: Dictionary):
	# Wait a bit to ensure the client has finished loading the Dungeon scene
	await get_tree().create_timer(0.5).timeout
	
	# Safety: Don't spawn if peer disconnected during the timer
	if not multiplayer.get_peers().has(peer_id) and peer_id != 1:
		return
		
	# Safety: Don't spawn if node already exists
	var player_name = "Player_%d" % peer_id
	if get_node(%MultiplayerPlayerSpawner.spawn_path).has_node(player_name):
		return

	print("[Dungeon] Spawning player for: ", peer_id)
	_spawn_player(peer_id, pb_data)

func _on_peer_disconnected(peer_id: int):
	var player_name = "Player_%d" % peer_id
	var spawner = %MultiplayerPlayerSpawner
	var spawn_path = spawner.spawn_path
	var spawn_node = get_node(spawn_path)
	var player_node = spawn_node.get_node_or_null(player_name)
	if player_node:
		player_node.queue_free()

func _spawn_player(peer_id: int, pb_data: Dictionary):
	var spawner = %MultiplayerPlayerSpawner
	var spawn_pos = %SpawnPoint.global_position if has_node("%SpawnPoint") else Vector3.ZERO

	var data = {
		"type": "player",
		"player_name": "Player_%d" % peer_id,
		"db_id": pb_data.get("id", ""),
		"peer_id": peer_id,
		"display_name": pb_data.get("name", "Player_%d" % peer_id),
		"name_color": [0.8, 0.2, 0.2],
		"pos": spawn_pos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)),
		"inventory": pb_data.get("inventory", {})
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
			
			if multiplayer.is_server():
				# IMPORTANT: Set the PocketBase record ID for server-side syncing
				node.player_name = data.get("db_id", "")
				
				if data.has("inventory"):
					# Deferred Loading: Wait until node is in tree/ready
					var load_data = data.inventory
					node.ready.connect(func():
						InventoryService.load_inventory_for_player(node, node.player_name, load_data)
					, CONNECT_ONE_SHOT)

			if "name_color" in data:
				var color_array = data.name_color
				node.name_color = Color(color_array[0], color_array[1], color_array[2], 1.0)
	
	if node:
		var pos = data.get("pos", Vector3.ZERO)
		node.position = pos
		if "sync_position" in node:
			node.sync_position = pos
	return node

