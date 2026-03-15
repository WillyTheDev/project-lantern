extends Node

enum Role { CLIENT, HUB_SERVER, DUNGEON_SERVER }

var current_role: Role = Role.CLIENT
var server_port: int = 9797
var hub_server_port: int = 9797
var dungeon_server_port: int = 9798
var server_address: String = "127.0.0.1"
var is_switching_server: bool = false

var player_spawner: MultiplayerSpawner
var players_root: Node

func _ready() -> void:
	_parse_arguments()
	
	# 1. Create a persistent root for players under this service
	# Moving it here ensures it's always in the tree when the spawner needs it
	players_root = Node.new()
	players_root.name = "Players"
	add_child(players_root)
	
	# 2. Create a persistent spawner as a sibling to the players root
	player_spawner = MultiplayerSpawner.new()
	player_spawner.name = "PlayerSpawner"
	add_child(player_spawner)
	
	# 3. Setup spawner deferred to ensure the tree is ready
	# This fixes absolute path resolution and late-joining sync issues
	_setup_spawner_deferred.call_deferred()
	
	# Ensure DTLS certificates are ready
	TLSHelper.ensure_certs()
	
	if current_role != Role.CLIENT:
		start_server()
	else:
		# Clients listen for connection to hide loading screen
		multiplayer.connected_to_server.connect(_on_connected_ok)
		multiplayer.connection_failed.connect(_on_connected_fail)

func _setup_spawner_deferred() -> void:
	# Use the absolute path to ensure deterministic resolution across all peers
	player_spawner.spawn_path = players_root.get_path()
	player_spawner.spawn_function = _global_custom_spawn
	
	# Register common spawnable scenes early
	player_spawner.add_spawnable_scene("res://scenes/actors/player/Player.tscn")
	player_spawner.add_spawnable_scene("res://scenes/world/interactables/LootDrop.tscn")
	player_spawner.add_spawnable_scene("res://scenes/actors/enemies/DungeonGuardian.tscn")
	
	print("[NetworkService] Global Spawner initialized at: ", player_spawner.spawn_path)

func _global_custom_spawn(data: Dictionary) -> Node:
	# This is a fallback/global spawn function. 
	var type = data.get("type", "player")
	var node: Node3D
	
	match type:
		"player":
			node = preload("res://scenes/actors/player/Player.tscn").instantiate()
			node.name = data.player_name
			node.player_id = data.peer_id
			node.display_name = data.get("display_name", "Player_%d" % data.peer_id)
			
			if multiplayer.is_server():
				node.player_name = data.get("db_id", "")
				if data.has("inventory"):
					var load_data = data.inventory
					node.ready.connect(func():
						InventoryService.load_inventory_for_player(node, node.player_name, load_data)
					, CONNECT_ONE_SHOT)

			if "name_color" in data:
				var color_array = data.name_color
				node.name_color = Color(color_array[0], color_array[1], color_array[2], 1.0)
		
		"enemy":
			var enemy_scene = preload("res://scenes/actors/enemies/DungeonGuardian.tscn")
			node = enemy_scene.instantiate()
			node.name = "Enemy_" + str(node.get_instance_id())
			
		"loot":
			node = preload("res://scenes/world/interactables/LootDrop.tscn").instantiate()
			if data.has("items"):
				node.items = data.items
	
	if node:
		var pos = data.get("pos", Vector3.ZERO)
		node.position = pos
		if "sync_position" in node:
			node.sync_position = pos
	return node

func _on_connected_ok():
	print("[NetworkService] Connected to server successfully (DTLS).")
	is_switching_server = false
	
	# If we were switching shards, trigger the re-authentication automatically
	if SceneService.is_switching_shard:
		if SceneService.cached_token != "":
			print("[NetworkService] Shard switch detected. Requesting auto-login via Token.")
			PocketBaseRPCManager.request_login_with_token(SceneService.cached_token)
		elif SceneService.cached_username != "" and SceneService.cached_password != "":
			# Fallback to password if token is missing but password exists
			print("[NetworkService] Shard switch detected. Requesting auto-login via Password.")
			PocketBaseRPCManager.request_login(SceneService.cached_username, SceneService.cached_password)
		else:
			print("[NetworkService] Shard switch detected, but no credentials available. Aborting auto-login.")
		SceneService.is_switching_shard = false

func _on_connected_fail():
	print("[NetworkService] Failed to connect to server.")
	SceneService.show_loading_screen(false)
	
	if is_switching_server:
		print("[NetworkService] Handoff failed during server switch.")
		is_switching_server = false
		return
		
	# Standard connection fail: return to main menu
	SceneService._load_scene(SceneService.MENU_SCENE)

func _parse_arguments() -> void:
	var args = OS.get_cmdline_user_args()
	
	if "--hub" in args:
		current_role = Role.HUB_SERVER
		server_port = 9797
		print("[NetworkService] Role: HUB SERVER (Port 9797)")
	elif "--dungeon" in args:
		current_role = Role.DUNGEON_SERVER
		server_port = 9798
		print("[NetworkService] Role: DUNGEON SERVER (Port 9798)")
	else:
		current_role = Role.CLIENT
		print("[NetworkService] Role: CLIENT")

func start_server() -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(server_port, 32)
	if err != OK:
		printerr("[NetworkService] Failed to start server: ", err)
		return
	
	var host = peer.get_host()
	var server_tls = TLSHelper.get_server_options()
	host.dtls_server_setup(server_tls)
		
	multiplayer.multiplayer_peer = peer
	print("[NetworkService] Secure DTLS Server started on port ", server_port)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func join_server(address: String, port: int) -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	if err != OK:
		printerr("[NetworkService] Failed to connect: ", err)
		return
	
	var host = peer.get_host()
	var client_tls = TLSHelper.get_client_options()
	host.dtls_client_setup(address, client_tls)
	
	multiplayer.multiplayer_peer = peer

func _on_peer_connected(id: int) -> void:
	print("[NetworkService] Peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkService] Peer disconnected: ", id)

func switch_server(address: String, port: int) -> void:
	print("[NetworkService] Switching to server: ", address, ":", port)
	is_switching_server = true
	
	# Disconnect current peer
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Wait a bit longer to ensure signals are processed and state is clean
	await get_tree().create_timer(0.2).timeout
	join_server(address, port)

func reset() -> void:
	print("[NetworkService] Resetting network state.")
	
	# Disconnect peer
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Clear all players/entities from the root
	if players_root:
		for child in players_root.get_children():
			child.queue_free()
	
	is_switching_server = false
