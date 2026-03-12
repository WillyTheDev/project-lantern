extends Node

enum Role { CLIENT, HUB_SERVER, DUNGEON_SERVER }

var current_role: Role = Role.CLIENT
var server_port: int = 9797
var hub_server_port: int = 9797
var dungeon_server_port: int = 9798
var server_address: String = "127.0.0.1"
#var server_address: String = "34.158.30.12"

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
	SceneManager.show_loading_screen(false)

func _on_connected_fail():
	print("[NetworkManager] Failed to connect to server.")
	SceneManager.show_loading_screen(false)
	# Maybe return to main menu here
	SceneManager._load_scene(SceneManager.MENU_SCENE)

func _parse_arguments() -> void:
	# Use user arguments (passed after --)
	# Example: godot --headless -- --hub
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
	
	# Correct way to enable DTLS in Godot 4: 
	# Access the ENetConnection host and setup DTLS
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
	
	# Correct way to enable DTLS in Godot 4:
	var host = peer.get_host()
	var client_tls = TLSHelper.get_client_options()
	# Use host.dtls_client_setup(hostname, options)
	# Hostname is used for SNI/Verification
	host.dtls_client_setup(address, client_tls)
	
	multiplayer.multiplayer_peer = peer

func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Peer disconnected: ", id)

func switch_server(address: String, port: int) -> void:
	print("[NetworkManager] Switching to server: ", address, ":", port)
	# Disconnect current peer
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Wait a frame to ensure cleanup
	await get_tree().process_frame
	join_server(address, port)
