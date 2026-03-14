extends Area3D

@export_file("*.tscn") var target_scene: String = ""
@export var target_port: int = 9797
@export var portal_name: String = "Portal"

enum PortalType { STANDARD, EXTRACTION }
@export var portal_type: PortalType = PortalType.STANDARD

func _ready() -> void:
	if multiplayer.has_multiplayer_peer():
		print("[Portal] ", portal_name, " initialized. Role: ", "Server" if multiplayer.is_server() else "Client")
		print("[Portal] Monitoring: ", monitoring, " Monitorable: ", monitorable)
		print("[Portal] Layer: ", collision_layer, " Mask: ", collision_mask)
	else:
		print("[Portal] ", portal_name, " initialized (offline/loading).")
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Debug print for both server and client to confirm signal firing
	print("[Portal] ", portal_name, " - Body entered: ", body.name, " (Is Server: ", multiplayer.is_server(), ")")
	
	if not multiplayer.is_server(): return
	if body.has_method("get_multiplayer_authority") or "player_id" in body:
		var peer_id = body.get_multiplayer_authority() if body.has_method("get_multiplayer_authority") else body.player_id
		
		if peer_id == 1: return
		
		if portal_type == PortalType.EXTRACTION:
			print("[Portal] ", portal_name, ": Player ", peer_id, " EXTRACTION SUCCESS.")
			# Future: Call InventoryService to "secure" loot found in dungeon
			
		print("[Portal] ", portal_name, ": Handoff peer ", peer_id, " to port ", target_port)
		_request_client_switch.rpc_id(peer_id, NetworkService.server_address, target_port, target_scene)

@rpc("authority", "call_local", "reliable")
func _request_client_switch(address: String, port: int, scene_path: String) -> void:
	print("[Client] Shard Handoff Trace: User=", SceneService.cached_username, " Path=", scene_path, " Port=", port)
	
	SceneService.is_switching_shard = true # Mark the transition
	
	# 1. Start loading screen
	SceneService.show_loading_screen(true)
	
	# 2. Tell SceneService to load scene. 
	# Note: We don't pass credentials here anymore as NetworkService 
	# handles the auto-login via cached token once reconnected.
	SceneService._load_scene(scene_path)
	
	# 3. Reconnect
	NetworkService.switch_server(address, port)

