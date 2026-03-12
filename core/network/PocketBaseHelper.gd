extends Node

## PocketBaseHelper
## High-level interface for game-specific PocketBase operations.
## Server-Authoritative version: Clients request, Server executes.

# Collection Names
const COL_PLAYERS = "players"

# Signals for UI/Game logic
signal player_data_loaded(data: Dictionary)
signal player_data_sync_failed(error_msg: String)
signal server_player_data_ready(peer_id: int, data: Dictionary) # New signal for server-side logic

func _ready() -> void:
	# Servers listen to generic request completed if they need to do extra logic
	if multiplayer.is_server():
		PersistenceManager.request_completed.connect(_on_server_request_completed)

# --- Client Facing Methods ---

## CLIENT CALL: Requests login from the server
func request_login(username: String) -> void:
	if multiplayer.is_server():
		PersistenceManager.login(username)
	else:
		rpc_id(1, "server_request_login", username)

## CLIENT CALL: Requests inventory sync from the server
func request_sync_inventory(player_db_id: String, inventory: Dictionary) -> void:
	if multiplayer.is_server():
		PersistenceManager.update_record(COL_PLAYERS, player_db_id, {"inventory": inventory})
	else:
		rpc_id(1, "server_request_sync_inventory", player_db_id, inventory)

# --- RPC Methods ---

## SERVER SIDE: Handles login request from client
@rpc("any_peer", "call_remote", "reliable")
func server_request_login(username: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	print("[PBHelper] Server received login request from peer ", sender_id, " for user: ", username)
	PersistenceManager.login(username, sender_id) # Pass sender_id!

## SERVER SIDE: Handles sync request from client
@rpc("any_peer", "call_remote", "reliable")
func server_request_sync_inventory(player_db_id: String, inventory: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	print("[PBHelper] Server received sync request from peer ", sender_id)
	PersistenceManager.update_record(COL_PLAYERS, player_db_id, {"inventory": inventory}, sender_id)

## CLIENT SIDE: Server calls this to deliver data
@rpc("authority", "call_remote", "reliable")
func fulfill_login(data: Dictionary) -> void:
	print("[PBHelper] Client received login data from server.")
	PersistenceManager.current_player_id = data["id"]
	PersistenceManager.current_player_name = data["name"]
	
	player_data_loaded.emit(data)
	# Also update InventoryManager locally
	InventoryManager.load_inventory(data["id"], data.get("inventory", {}))

# --- Server Internal ---

## SERVER SIDE: Called by PersistenceManager when a request finishes
func relay_login_success(peer_id: int, data: Dictionary) -> void:
	# Emit signal for other server systems (like Spawner)
	server_player_data_ready.emit(peer_id, data)
	
	if peer_id == 1: # Local server login (if any)
		fulfill_login(data)
	else:
		rpc_id(peer_id, "fulfill_login", data)

func _on_server_request_completed(collection: String, method: String, response_code: int, result: Variant) -> void:
	if response_code >= 400:
		printerr("[PBHelper] Server-side PB Error: ", response_code, " Result: ", result)
