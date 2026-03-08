extends Area3D

@export_file("*.tscn") var target_scene: String = ""
@export var target_port: int = 9797
@export var portal_name: String = "Portal"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Only the server of the CURRENT instance handles the handoff
	if not multiplayer.is_server():
		return
		
	# Check if the body that entered is a player
	if body.has_method("get_multiplayer_authority") or "player_id" in body:
		# Use the peer ID (authority) to target the RPC
		var peer_id = body.get_multiplayer_authority() if body.has_method("get_multiplayer_authority") else body.player_id
		
		# SAFETY: Don't tell the server (peer 1) to switch servers.
		# This avoids the "RPC on yourself" error and prevents the server from disconnecting itself.
		if peer_id == 1:
			return
			
		print("[Portal] ", portal_name, ": Player ", peer_id, " entering. Handoff to port ", target_port)
		
		# RPC to the specific client to tell them to switch servers
		_request_client_switch.rpc_id(peer_id, NetworkManager.server_address, target_port, target_scene)

@rpc("authority", "call_local", "reliable")
func _request_client_switch(address: String, port: int, scene_path: String) -> void:
	print("[Client] Received portal request: Moving to ", scene_path, " on port ", port)
	
	# 1. Show Loading Screen (via SceneManager)
	SceneManager.show_loading_screen(true)
	
	# 2. Load the scene locally first (so we have the world ready)
	SceneManager._load_scene(scene_path)
	
	# 3. Reconnect to the new server shard
	NetworkManager.switch_server(address, port)
