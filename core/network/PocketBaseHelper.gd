extends Node

## PocketBaseHelper
## High-level interface for game-specific PocketBase operations.
## Server-Authoritative version: Clients request, Server executes.

# Collection Names
const COL_PLAYERS = "players"

# Signals for UI/Game logic
signal player_data_loaded(data: Dictionary)
signal player_data_sync_failed(error_msg: String)
signal server_player_login_completed(peer_id: int, data: Dictionary) # Renamed for clarity
signal server_auth_complete(success: bool)

var is_server_authenticated: bool = false
var pending_requests: Array = [] 

func _ready() -> void:
	if multiplayer.is_server():
		PersistenceManager.request_completed.connect(_on_server_request_completed)
		server_auth_complete.connect(_on_server_auth_complete)

func _on_server_auth_complete(success: bool) -> void:
	is_server_authenticated = success
	if success:
		print("[PBHelper] Server ready. Processing ", pending_requests.size(), " pending requests.")
		for req in pending_requests:
			match req.type:
				"login": server_request_login(req.username, req.password, req.sender_id)
				"sync": server_request_sync_inventory(req.db_id, req.inventory, req.sender_id)
				"register": server_request_register(req.username, req.email, req.password, req.sender_id)
		pending_requests.clear()

# --- Client Facing Methods ---

func request_login(username: String, password: String) -> void:
	if username == "" or password == "":
		print("[PBHelper] ABORT: Attempted login with empty credentials.")
		return
		
	if multiplayer.is_server():
		PersistenceManager.login(username, password)
	else:
		rpc_id(1, "server_request_login", username, password)

func request_login_with_token(token: String) -> void:
	if token == "":
		print("[PBHelper] ABORT: Attempted token login with empty token.")
		return
		
	print("[PBHelper] Client requesting login with token.")
	if multiplayer.is_server():
		PersistenceManager.login_with_token(token)
	else:
		rpc_id(1, "server_request_login_with_token", token)

func request_sync_inventory(player_db_id: String, inventory: Dictionary) -> void:
	if player_db_id == "": return
	
	if multiplayer.is_server():
		PersistenceManager.update_record(COL_PLAYERS, player_db_id, {"inventory": inventory})
	else:
		rpc_id(1, "server_request_sync_inventory", player_db_id, inventory)

func request_register(username: String, email: String, password: String) -> void:
	if username == "" or email == "" or password == "":
		print("[PBHelper] ABORT: Attempted registration with empty credentials.")
		return
		
	if multiplayer.is_server():
		PersistenceManager.register(username, email, password)
	else:
		rpc_id(1, "server_request_register", username, email, password)

# --- RPC Methods ---

@rpc("any_peer", "call_remote", "reliable")
func server_request_register(username: String, email: String, password: String, force_sender_id: int = -1) -> void:
	var sender_id = force_sender_id if force_sender_id != -1 else multiplayer.get_remote_sender_id()
	if not is_server_authenticated:
		pending_requests.append({"type": "register", "username": username, "email": email, "password": password, "sender_id": sender_id})
		return
	PersistenceManager.register(username, email, password, sender_id)

@rpc("any_peer", "call_remote", "reliable")
func server_request_login(username: String, password: String, force_sender_id: int = -1) -> void:
	var sender_id = force_sender_id if force_sender_id != -1 else multiplayer.get_remote_sender_id()
	if not is_server_authenticated:
		pending_requests.append({"type": "login", "username": username, "password": password, "sender_id": sender_id})
		return
	PersistenceManager.login(username, password, sender_id)

@rpc("any_peer", "call_remote", "reliable")
func server_request_login_with_token(token: String, force_sender_id: int = -1) -> void:
	var sender_id = force_sender_id if force_sender_id != -1 else multiplayer.get_remote_sender_id()
	if not is_server_authenticated:
		pending_requests.append({"type": "login_token", "token": token, "sender_id": sender_id})
		return
	PersistenceManager.login_with_token(token, sender_id)

@rpc("any_peer", "call_remote", "reliable")
func server_request_sync_inventory(player_db_id: String, inventory: Dictionary, force_sender_id: int = -1) -> void:
	var sender_id = force_sender_id if force_sender_id != -1 else multiplayer.get_remote_sender_id()
	if not is_server_authenticated:
		pending_requests.append({"type": "sync", "db_id": player_db_id, "inventory": inventory, "sender_id": sender_id})
		return
	PersistenceManager.update_record(COL_PLAYERS, player_db_id, {"inventory": inventory}, sender_id)

## CLIENT SIDE: Deliver full profile (triggers spawning logic)
@rpc("authority", "call_remote", "reliable")
func fulfill_login(data: Dictionary) -> void:
	print("[PBHelper] Client received login data.")
	PersistenceManager.current_player_id = data["id"]
	PersistenceManager.current_player_name = data["name"]
	
	# Cache the token for shard handoffs
	if data.has("auth_token"):
		SceneManager.cached_token = data["auth_token"]
		print("[PBHelper] Cached session token for shard handoffs.")
		
	player_data_loaded.emit(data)
	InventoryManager.load_inventory(data["id"], data.get("inventory", {}))

## CLIENT SIDE: Deliver updated data (silent sync)
@rpc("authority", "call_remote", "reliable")
func fulfill_update(data: Dictionary) -> void:
	print("[PBHelper] Client received sync update.")
	# Just update inventory without triggering a "login" event
	InventoryManager.load_inventory(data["id"], data.get("inventory", {}))

@rpc("authority", "call_remote", "reliable")
func fulfill_login_failure(reason: String) -> void:
	player_data_sync_failed.emit(reason)

# --- Server Internal ---

func relay_login_success(peer_id: int, data: Dictionary) -> void:
	server_player_login_completed.emit(peer_id, data)
	if peer_id == 1: fulfill_login(data)
	else: rpc_id(peer_id, "fulfill_login", data)

func relay_update_success(peer_id: int, data: Dictionary) -> void:
	if peer_id == 1: fulfill_update(data)
	else: rpc_id(peer_id, "fulfill_update", data)

func relay_login_failure(peer_id: int, reason: String) -> void:
	if peer_id == 1: fulfill_login_failure(reason)
	else: rpc_id(peer_id, "fulfill_login_failure", reason)

func _on_server_request_completed(collection: String, method: String, response_code: int, result: Variant) -> void:
	if response_code >= 400:
		printerr("[PBHelper] Server-side PB Error: ", response_code, " Result: ", result)
