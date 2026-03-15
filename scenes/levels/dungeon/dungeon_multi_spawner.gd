extends Node

## DungeonMultiSpawner
## Handles server-authoritative spawning of players, enemies, and loot.

func _ready() -> void:
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
	var spawner = NetworkService.player_spawner
	var data = {
		"type": "enemy",
		"enemy_type": enemy_type,
		"pos": pos
	}
	spawner.spawn(data)
