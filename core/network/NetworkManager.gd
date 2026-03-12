extends Node

enum Role { CLIENT, HUB_SERVER, DUNGEON_SERVER }

var current_role: Role = Role.CLIENT
var server_port: int = 9797
var hub_server_port: int = 9797
var dungeon_server_port: int = 9798
var server_address: String = "127.0.0.1"
var is_switching_server: bool = false

func _ready() -> void:
	_parse_arguments()
	
	# Ensure DTLS certificates are ready
	TLSHelper.ensure_certs()
	
	if current_role != Role.CLIENT:
		start_server()
	else:
		# Clients listen for connection to hide loading screen
		multiplayer.connected_to_server.connect(_on_connected_ok)
		multiplayer.connection_failed.connect(_on_connected_fail)

func _on_connected_ok():
	print("[NetworkManager] Connected to server successfully (DTLS).")
	is_switching_server = false
	
	# If we were switching shards, trigger the re-authentication automatically
	if SceneManager.is_switching_shard:
		if SceneManager.cached_token != "":
			print("[NetworkManager] Shard switch detected. Requesting auto-login via Token.")
			PBHelper.request_login_with_token(SceneManager.cached_token)
		elif SceneManager.cached_username != "" and SceneManager.cached_password != "":
			# Fallback to password if token is missing but password exists
			print("[NetworkManager] Shard switch detected. Requesting auto-login via Password.")
			PBHelper.request_login(SceneManager.cached_username, SceneManager.cached_password)
		else:
			print("[NetworkManager] Shard switch detected, but no credentials available. Aborting auto-login.")
		SceneManager.is_switching_shard = false

func _on_connected_fail():
	print("[NetworkManager] Failed to connect to server.")
	SceneManager.show_loading_screen(false)
	
	if is_switching_server:
		print("[NetworkManager] Handoff failed during server switch.")
		is_switching_server = false
		# You might want to show an error message or try reconnecting to Hub
		return
		
	# Standard connection fail: return to main menu
	SceneManager._load_scene(SceneManager.MENU_SCENE)

func _parse_arguments() -> void:
	var args = OS.get_cmdline_user_args()
	
	if "--hub" in args:
		current_role = Role.HUB_SERVER
		server_port = 9797
		print("[NetworkManager] Role: HUB SERVER (Port 9797)")
	elif "--dungeon" in args:
		current_role = Role.DUNGEON_SERVER
		server_port = 9798
		print("[NetworkManager] Role: DUNGEON SERVER (Port 9798)")
	else:
		current_role = Role.CLIENT
		print("[NetworkManager] Role: CLIENT")

func start_server() -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(server_port, 32)
	if err != OK:
		printerr("[NetworkManager] Failed to start server: ", err)
		return
	
	var host = peer.get_host()
	var server_tls = TLSHelper.get_server_options()
	host.dtls_server_setup(server_tls)
		
	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Secure DTLS Server started on port ", server_port)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func join_server(address: String, port: int) -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	if err != OK:
		printerr("[NetworkManager] Failed to connect: ", err)
		return
	
	var host = peer.get_host()
	var client_tls = TLSHelper.get_client_options()
	host.dtls_client_setup(address, client_tls)
	
	multiplayer.multiplayer_peer = peer

func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Peer disconnected: ", id)

func switch_server(address: String, port: int) -> void:
	print("[NetworkManager] Switching to server: ", address, ":", port)
	is_switching_server = true
	
	# Disconnect current peer
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Wait a bit longer to ensure signals are processed and state is clean
	await get_tree().create_timer(0.2).timeout
	join_server(address, port)
