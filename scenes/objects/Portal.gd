extends Area3D

@export_file("*.tscn") var target_scene: String = ""
@export var target_port: int = 9797
@export var portal_name: String = "Portal"

func _ready() -> void:
	print("[Portal] ", portal_name, " initialized. Role: ", "Server" if multiplayer.is_server() else "Client")
	print("[Portal] Monitoring: ", monitoring, " Monitorable: ", monitorable)
	print("[Portal] Layer: ", collision_layer, " Mask: ", collision_mask)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Debug print for both server and client to confirm signal firing
	print("[Portal] ", portal_name, " - Body entered: ", body.name, " (Is Server: ", multiplayer.is_server(), ")")
	
	if not multiplayer.is_server(): return
	if body.has_method("get_multiplayer_authority") or "player_id" in body:
		var peer_id = body.get_multiplayer_authority() if body.has_method("get_multiplayer_authority") else body.player_id
		
		if peer_id == 1: return
			
		print("[Portal] ", portal_name, ": Handoff peer ", peer_id, " to port ", target_port)
		_request_client_switch.rpc_id(peer_id, NetworkManager.server_address, target_port, target_scene)

@rpc("authority", "call_local", "reliable")
func _request_client_switch(address: String, port: int, scene_path: String) -> void:
	print("[Client] Shard Handoff Trace: User=", SceneManager.cached_username, " Path=", scene_path, " Port=", port)
	
	SceneManager.is_switching_shard = true # Mark the transition
	
	# 1. Start loading screen
	SceneManager.show_loading_screen(true)
	
	# 2. Tell SceneManager to load scene AND use cached credentials for auto-login
	# We pass cached credentials so SceneManager handles the post-load login
	SceneManager._load_scene(scene_path, SceneManager.cached_username, SceneManager.cached_password)
	
	# 3. Reconnect
	NetworkManager.switch_server(address, port)
