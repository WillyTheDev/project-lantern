extends Node

signal _on_player_spawned

func _ready() -> void:
	# Server-side connection handling
	if NetworkService.current_role == NetworkService.Role.HUB_SERVER:
		# We wait for login success before spawning
		PocketBaseRPCManager.server_player_login_completed.connect(_on_server_player_login_completed)
		NetworkService.multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# --- CLIENT SIDE CALLBACKS ---
func _on_connection_success():
	print("[Hub] Connected to Hub Server!")
	_on_player_spawned.emit()

# --- SERVER SIDE CALLBACKS ---

func _on_server_player_login_completed(peer_id: int, data: Dictionary):
	# Wait a bit to ensure the client has finished loading the Hub scene
	# This timer is still useful to give the client time to add the Hub to tree
	await get_tree().create_timer(0.5).timeout
	
	# Safety: Don't spawn if peer disconnected during the timer
	if not multiplayer.get_peers().has(peer_id) and peer_id != 1:
		return
		
	# Safety: Don't spawn if node already exists
	var player_name = "Player_%d" % peer_id
	if NetworkService.players_root.has_node(player_name):
		return

	_spawn_player(peer_id, data)

func _on_peer_disconnected(peer_id: int):
	var player_name = "Player_%d" % peer_id
	var player_node = NetworkService.players_root.get_node_or_null(player_name)
	if player_node:
		player_node.queue_free()

func _spawn_player(peer_id: int, pb_data: Dictionary):
	var spawner = NetworkService.player_spawner
	var spawn_pos = %SpawnPoint.global_position if has_node("%SpawnPoint") else Vector3.ZERO

	var data = {
		"player_name": "Player_%d" % peer_id,
		"db_id": pb_data.get("id", ""),
		"peer_id": peer_id,
		"display_name": pb_data.get("name", "Player_%d" % peer_id),
		"name_color": [0.8, 0.8, 0.8],
		"pos": spawn_pos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)),
		"inventory": pb_data.get("inventory", {})
	}
	spawner.spawn(data)
