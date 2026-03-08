extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Only the server should handle the handoff logic
	if not multiplayer.is_server():
		return
		
	# Check if the body that entered is a player
	# Assuming your player controller has a 'player_id' property
	if body.has_method("get_player_id") or "player_id" in body:
		var peer_id = body.player_id
		print("[Portal] Player ", peer_id, " entered portal. Sending to Dungeon.")
		
		# RPC to the specific client to tell them to switch servers
		_request_client_switch.rpc_id(peer_id, NetworkManager.server_address, NetworkManager.dungeon_server_port)

@rpc("authority", "call_remote", "reliable")
func _request_client_switch(address: String, port: int) -> void:
	print("[Client] Received portal request to move to ", address, ":", port)
	
	# Use SceneManager to handle the scene change locally
	# Since it's a separate server, we first change the local scene 
	# then the NetworkManager will handle the connection.
	SceneManager._load_scene(SceneManager.DUNGEON_SCENE)
	
	# Reconnect to the new server
	NetworkManager.switch_server(address, port)
