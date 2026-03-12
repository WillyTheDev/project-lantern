extends Node

signal _on_player_spawned

func _ready() -> void:
	# Setup Spawner
	var spawner = %MultiplayerPlayerSpawner
	spawner.spawn_function = custom_spawn
	spawner.add_spawnable_scene("res://scenes/actors/player/Player.tscn")
	
	# Server-side connection handling
	if NetworkManager.current_role == NetworkManager.Role.HUB_SERVER:
		# We wait for PB data before spawning
		PBHelper.server_player_data_ready.connect(_on_server_player_data_ready)
		NetworkManager.multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# --- CLIENT SIDE CALLBACKS ---
func _on_connection_success():
	print("[Hub] Connected to Hub Server!")
	_on_player_spawned.emit()

# --- SERVER SIDE CALLBACKS ---

func _on_server_player_data_ready(peer_id: int, data: Dictionary):
	print("[Hub] [Server] Data ready for peer ", peer_id, ". Waiting 0.5s for client scene transition...")
	# Wait a bit to ensure the client has finished loading the Hub scene
	await get_tree().create_timer(0.5).timeout
	print("[Hub] [Server] Spawning player node for peer: ", peer_id)
	_spawn_player(peer_id, data)

func _on_peer_disconnected(peer_id: int):
	print("[Hub] Peer disconnected: ", peer_id)
	var player_name = "Player_%d" % peer_id
	var spawner = %MultiplayerPlayerSpawner
	var spawn_path = spawner.spawn_path
	var spawn_node = get_node(spawn_path)
	var player_node = spawn_node.get_node_or_null(player_name)
	if player_node:
		player_node.queue_free()
		print("[Hub] Removed player node: ", player_name)

func _spawn_player(peer_id: int, pb_data: Dictionary):
	var spawner = %MultiplayerPlayerSpawner
	var spawn_pos = %SpawnPoint.global_position if has_node("%SpawnPoint") else Vector3.ZERO

	var data = {
		"player_name": "Player_%d" % peer_id,
		"peer_id": peer_id,
		"display_name": pb_data.get("name", "Player_%d" % peer_id),
		"name_color": [0.8, 0.8, 0.8], # Default color
		"pos": spawn_pos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	}
	spawner.spawn(data)

# --- HELPER FUNCTIONS ---
func custom_spawn(data: Dictionary) -> Node3D:
	print("[Hub] custom_spawn called on ", "Server" if multiplayer.is_server() else "Client", " for: ", data.player_name)
	var p = preload("res://scenes/actors/player/Player.tscn").instantiate()
	p.name = data.player_name
	p.player_id = data.peer_id
	p.display_name = data.get("display_name", "Player_%d" % data.peer_id)
	if "name_color" in data:
		var color_array = data.name_color
		p.name_color = Color(color_array[0], color_array[1], color_array[2], 1.0)
	p.global_position = data.pos
	p.scale = Vector3(0.3, 0.3, 0.3)
	return p
