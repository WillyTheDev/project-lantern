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
		
	EventBus.session_ended.connect(reset)

## Called securely after the root players node exists to configure the global MultiplayerSpawner.
## Registers the spawnable player and entity scenes for network replication.
func _setup_spawner_deferred() -> void:
	# Use the absolute path to ensure deterministic resolution across all peers
	player_spawner.spawn_path = players_root.get_path()
	player_spawner.spawn_function = _global_custom_spawn
	
	print("[NetworkService] Global Spawner initialized at: ", player_spawner.spawn_path)

## Global custom spawn function used by the MultiplayerSpawner.
## Interprets the incoming spawn data payload to instantiate players or enemies dynamically.
##
## @param data: Dictionary containing spawn instruction variables (e.g., type, peer_id, pos).
## @return: The instantiated Node3D ready to be added to the scene tree.
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
			var enemy_scene = preload("res://scenes/actors/enemies/BaseEnemy.tscn")
			node = enemy_scene.instantiate()
			node.name = "Enemy_" + str(node.get_instance_id())
			
		"loot":
			node = preload("res://scenes/world/interactables/LootDrop.tscn").instantiate()
			if data.has("items"):
				node.items = data.items
				if "sync_items" in node:
					node.sync_items = data.items
	
	if node:
		var pos = data.get("pos", Vector3.ZERO)
		node.position = pos
		if "sync_position" in node:
			node.sync_position = pos
	return node

## Callback fired when the client successfully establishes a low-level DTLS connection to the target server.
## Transitions internal states and triggers token-based auto-login if a shard switch was pending.
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

## Callback fired when the client fails to establish a connection to the target server.
## Hides the loading screen and falls back to the Main Menu.
func _on_connected_fail():
	print("[NetworkService] Failed to connect to server.")
	SceneService.show_loading_screen(false)
	
	if is_switching_server:
		print("[NetworkService] Handoff failed during server switch.")
		is_switching_server = false
		return
		
	# Standard connection fail: return to main menu
	SceneService._load_scene(SceneService.MENU_SCENE)

## Reads OS command line arguments (e.g., `--hub`, `--dungeon`) to determine the binary's execution role.
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

## Initializes an ENet server listening on the designated port and sets up DTLS encryption.
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

## Initiates a client-side connection attempt to a specific server address and port using DTLS.
##
## @param address: The target IPv4 or domain address.
## @param port: The target port.
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

## Convenience method to check if the current instance is running as a network authority server.
##
## @return: True if this binary is a Hub or Dungeon server handling clients.
func is_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()

func _on_peer_connected(id: int) -> void:
	print("[NetworkService] Peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkService] Peer disconnected: ", id)

## Finds a player node instance by its network peer ID.
##
## @param id: The network peer ID to search for.
## @return: The Player node if found, otherwise null.
func get_player(id: int) -> Node:
	if not players_root: return null
	for child in players_root.get_children():
		if child.is_in_group("players") and "player_id" in child and child.player_id == id:
			return child
	return null

## Clears the current server connection and connects to a new target server (Shard Handoff).
##
## @param address: The new server IPv4 or domain address.
## @param port: The new server port.
func switch_server(address: String, port: int) -> void:
	print("[NetworkService] Switching to server: ", address, ":", port)
	
	# Clear previous state including players
	reset()
	
	# Mark as switching AFTER reset so it doesn't get cleared
	is_switching_server = true
	
	# Wait a bit longer to ensure signals are processed and state is clean
	await get_tree().create_timer(0.2).timeout
	join_server(address, port)

## Hard-resets the entire networking state. Disconnects peers, cleans up tracked nodes, and removes player instances.
func reset() -> void:
	print("[NetworkService] Resetting network state.")
	
	# Disconnect peer
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Clear all players/entities from the root
	if players_root:
		for child in players_root.get_children():
			print("[NetworkService] Reset clearing player/node: ", child.name)
			child.queue_free()
	
	is_switching_server = false
