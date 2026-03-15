extends Node

## DungeonMultiSpawner
## Handles server-authoritative spawning of players, enemies, and loot.

func _ready() -> void:
	# Setup Generator Templates
	_setup_generator()
	
	# Server-side logic for Dungeon
	if multiplayer.is_server():
		# 1. Generate the Dungeon FIRST
		%DungeonGenerator.generate()
		
		# Wait a frame for rooms to be added to tree
		await get_tree().process_frame
		
		# 2. Setup standard multiplayer signals
		PocketBaseRPCManager.server_player_login_completed.connect(_on_server_player_login_completed)
		NetworkService.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		# 3. Spawn initial enemies
		call_deferred("_spawn_initial_enemies")

func _setup_generator() -> void:
	var gen = %DungeonGenerator
	var spawner = %RoomSpawner
	
	# Register all templates found in the generator's consolidated list
	# This includes spawn_room, portal_room, stairs, hallways, and modular tiles.
	for room in gen.room_templates:
		if room:
			spawner.add_spawnable_scene(room.resource_path)
	
	print("[Dungeon] Registered ", gen.room_templates.size(), " room templates to MultiplayerSpawner.")

# --- SERVER SIDE CALLBACKS ---

func _spawn_initial_enemies():
	if not multiplayer.is_server(): return
	
	# Search for enemy spawn points in the GENERATED rooms
	var enemy_points = get_tree().get_nodes_in_group("enemy_spawners")
	print("[Dungeon] Found ", enemy_points.size(), " enemy spawn points in generated rooms.")
	
	for point in enemy_points:
		_spawn_enemy("guardian", point.global_position)

func _on_server_player_login_completed(peer_id: int, pb_data: Dictionary):
	# Wait a bit to ensure the client has finished loading the Dungeon scene
	# and received the room spawn packets
	await get_tree().create_timer(1.0).timeout
	
	# Safety: Don't spawn if peer disconnected during the timer
	if not multiplayer.get_peers().has(peer_id) and peer_id != 1:
		return
		
	# Safety: Don't spawn if node already exists
	var player_name = "Player_%d" % peer_id
	if NetworkService.players_root.has_node(player_name):
		return

	print("[Dungeon] Spawning player for: ", peer_id)
	_spawn_player(peer_id, pb_data)

func _on_peer_disconnected(peer_id: int):
	var player_name = "Player_%d" % peer_id
	var player_node = NetworkService.players_root.get_node_or_null(player_name)
	if player_node:
		player_node.queue_free()

func _spawn_player(peer_id: int, pb_data: Dictionary):
	var spawner = NetworkService.player_spawner
	
	# 1. Find the SpawnPoint marker inside the generated rooms
	var spawn_pos = Vector3(0, 2, 0) # Fallback if no marker found
	var generator = %DungeonGenerator
	
	var spawn_node = generator.find_child("SpawnPoint", true, false)
	if spawn_node:
		spawn_pos = spawn_node.global_position
		print("[Dungeon] Found SpawnPoint marker at: ", spawn_pos)
	else:
		printerr("[Dungeon] WARNING: No 'SpawnPoint' marker found in spawn room! Using fallback.")

	# 2. Prepare spawn data
	var data = {
		"type": "player",
		"player_name": "Player_%d" % peer_id,
		"db_id": pb_data.get("id", ""),
		"peer_id": peer_id,
		"display_name": pb_data.get("name", "Player_%d" % peer_id),
		"name_color": [0.8, 0.2, 0.2],
		# Spawn slightly above ground with a tiny horizontal jitter to prevent overlapping
		"pos": spawn_pos + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5)),
		"inventory": pb_data.get("inventory", {})
	}
	
	spawner.spawn(data)

func _spawn_enemy(enemy_type: String, pos: Vector3):
	var spawner = NetworkService.player_spawner
	var data = {
		"type": "enemy",
		"enemy_type": enemy_type,
		"pos": pos
	}
	spawner.spawn(data)
