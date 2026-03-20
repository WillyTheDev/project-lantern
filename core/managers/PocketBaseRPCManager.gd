extends Node

## PocketBaseRPCManager
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
	if NetworkService.is_server():
		PocketBaseRESTManager.request_completed.connect(_on_server_request_completed)
		server_auth_complete.connect(_on_server_auth_complete)

func _on_server_auth_complete(success: bool) -> void:
	is_server_authenticated = success
	if success:
		print("[PocketBaseRPCManager] Server ready. Processing ", pending_requests.size(), " pending requests.")
		for req in pending_requests:
			match req.type:
				"login": server_request_login(req.username, req.password, req.sender_id)
				"login_token": server_request_login_with_token(req.token, req.sender_id)
				"sync": server_request_sync_inventory(req.db_id, req.inventory, req.sender_id)
				"register": server_request_register(req.username, req.email, req.password, req.sender_id)
		pending_requests.clear()
	else:
		printerr("[PocketBaseRPCManager] Server authentication FAILED. Failing ", pending_requests.size(), " pending requests.")
		for req in pending_requests:
			relay_login_failure(req.sender_id, "Server initialization failed (Database unreachable).")
		pending_requests.clear()

# --- Client Facing Methods ---

## Client-side request to log into the game.
## If called on the server, executes the REST call directly.
## If on a client, forwards the request via RPC to the server.
##
## @param username: The identity (email/username) string.
## @param password: The plain-text password.
func request_login(username: String, password: String) -> void:
	if username == "" or password == "":
		print("[PocketBaseRPCManager] ABORT: Attempted login with empty credentials.")
		return
		
	if NetworkService.is_server():
		PocketBaseRESTManager.login(username, password)
	elif multiplayer.has_multiplayer_peer():
		rpc_id(1, "server_request_login", username, password)
	else:
		printerr("[PocketBaseRPCManager] ABORT: Cannot request login, no multiplayer peer assigned.")

## Client-side request to log in using a cached JWT token.
## Bypasses password entry for seamless shard transitions.
##
## @param token: The valid JWT string.
func request_login_with_token(token: String) -> void:
	if token == "":
		print("[PocketBaseRPCManager] ABORT: Attempted token login with empty token.")
		return
		
	print("[PocketBaseRPCManager] Client requesting login with token.")
	if NetworkService.is_server():
		PocketBaseRESTManager.login_with_token(token)
	elif multiplayer.has_multiplayer_peer():
		rpc_id(1, "server_request_login_with_token", token)
	else:
		printerr("[PocketBaseRPCManager] ABORT: Cannot request token login, no multiplayer peer assigned.")

## Client-side request to sync the player's local inventory dictionary to PocketBase.
##
## @param player_db_id: The unique ID string of the player record.
## @param inventory: The serialized dictionary of the inventory resource.
## @param requester_id: Internal network peer ID.
func request_sync_inventory(player_db_id: String, inventory: Dictionary, requester_id: int = 1) -> void:
	if player_db_id == "": 
		printerr("[PocketBaseRPCManager] FAILED: Attempted to sync inventory with empty player_db_id (peer: ", requester_id, ")")
		return
	
	if NetworkService.is_server():
		print("[PocketBaseRPCManager] Syncing inventory for player: ", player_db_id, " (peer: ", requester_id, ")")
		if not is_server_authenticated:
			print("[PocketBaseRPCManager] Queuing sync request for ", player_db_id, " (peer: ", requester_id, ")")
			pending_requests.append({"type": "sync", "db_id": player_db_id, "inventory": inventory, "sender_id": requester_id})
			return
		PocketBaseRESTManager.update_record(COL_PLAYERS, player_db_id, {"inventory": inventory}, requester_id)
	elif multiplayer.has_multiplayer_peer():
		rpc_id(1, "server_request_sync_inventory", player_db_id, inventory)
	else:
		printerr("[PocketBaseRPCManager] ABORT: Cannot request sync, no multiplayer peer assigned.")

## Client-side request to register a new user account.
##
## @param username: The desired display name.
## @param email: User email address.
## @param password: The plain-text password.
func request_register(username: String, email: String, password: String) -> void:
	if username == "" or email == "" or password == "":
		print("[PocketBaseRPCManager] ABORT: Attempted registration with empty credentials.")
		return
		
	if NetworkService.is_server():
		PocketBaseRESTManager.register(username, email, password)
	elif multiplayer.has_multiplayer_peer():
		rpc_id(1, "server_request_register", username, email, password)
	else:
		printerr("[PocketBaseRPCManager] ABORT: Cannot request registration, no multiplayer peer assigned.")

# --- RPC Methods ---

@rpc("any_peer", "call_remote", "reliable")
func server_request_register(username: String, email: String, password: String, force_sender_id: int = -1) -> void:
	var sender_id = force_sender_id if force_sender_id != -1 else multiplayer.get_remote_sender_id()
	if not is_server_authenticated:
		pending_requests.append({"type": "register", "username": username, "email": email, "password": password, "sender_id": sender_id})
		rpc_id(sender_id, "notify_client_status", "Waiting for server database initialization...")
		return
	PocketBaseRESTManager.register(username, email, password, sender_id)

@rpc("any_peer", "call_remote", "reliable")
func server_request_login(username: String, password: String, force_sender_id: int = -1) -> void:
	var sender_id = force_sender_id if force_sender_id != -1 else multiplayer.get_remote_sender_id()
	if not is_server_authenticated:
		pending_requests.append({"type": "login", "username": username, "password": password, "sender_id": sender_id})
		rpc_id(sender_id, "notify_client_status", "Waiting for server database initialization...")
		return
	PocketBaseRESTManager.login(username, password, sender_id)

@rpc("any_peer", "call_remote", "reliable")
func server_request_login_with_token(token: String, force_sender_id: int = -1) -> void:
	var sender_id = force_sender_id if force_sender_id != -1 else multiplayer.get_remote_sender_id()
	if not is_server_authenticated:
		pending_requests.append({"type": "login_token", "token": token, "sender_id": sender_id})
		rpc_id(sender_id, "notify_client_status", "Waiting for server database initialization...")
		return
	PocketBaseRESTManager.login_with_token(token, sender_id)

@rpc("authority", "call_remote", "reliable")
func notify_client_status(message: String) -> void:
	print("[PocketBaseRPCManager] Server Notification: ", message)
	SceneService.update_status(message)

@rpc("any_peer", "call_remote", "reliable")
func server_request_sync_inventory(player_db_id: String, inventory: Dictionary, force_sender_id: int = -1) -> void:
	var sender_id = force_sender_id if force_sender_id != -1 else multiplayer.get_remote_sender_id()
	request_sync_inventory(player_db_id, inventory, sender_id)

## CLIENT SIDE: Deliver full profile (triggers spawning logic)
@rpc("authority", "call_remote", "reliable")
func fulfill_login(data: Dictionary) -> void:
	print("[PocketBaseRPCManager] Client received login data.")
	PocketBaseRESTManager.current_player_id = data["id"]
	PocketBaseRESTManager.current_player_name = data["name"]
	
	# Cache the token for shard handoffs
	if data.has("auth_token"):
		SceneService.cached_token = data["auth_token"]
		print("[PocketBaseRPCManager] Cached session token for shard handoffs.")
		
	player_data_loaded.emit(data)
	
	# Load into local player
	var p = InventoryService.get_local_player()
	InventoryService.load_inventory_for_player(p, data["id"], data.get("inventory", {}))

## CLIENT SIDE: Deliver updated data (silent sync)
@rpc("authority", "call_remote", "reliable")
func fulfill_update(data: Dictionary) -> void:
	print("[PocketBaseRPCManager] Client received sync update.")
	# Just update inventory without triggering a "login" event
	var p = InventoryService.get_local_player()
	InventoryService.load_inventory_for_player(p, data["id"], data.get("inventory", {}))

@rpc("authority", "call_remote", "reliable")
func fulfill_login_failure(reason: String) -> void:
	player_data_sync_failed.emit(reason)

# --- Server Internal ---

## Server-side helper to broadcast a successful login back to the requesting client.
## Synchronizes the `players` group node on the server if present.
func relay_login_success(peer_id: int, data: Dictionary) -> void:
	server_player_login_completed.emit(peer_id, data)
	
	# Update the server-side player node's inventory directly
	if NetworkService.is_server():
		var players = get_tree().get_nodes_in_group("players").filter(func(p): return is_instance_valid(p) and p.player_id == peer_id)
		if players.size() > 0:
			InventoryService.load_inventory_for_player(players[0], data["id"], data.get("inventory", {}))
	
	if peer_id == 1: fulfill_login(data)
	else: rpc_id(peer_id, "fulfill_login", data)

## Server-side helper to broadcast a successful inventory sync patch back to the requesting client.
## Triggers held-item visual refreshes on the server representation.
func relay_update_success(peer_id: int, data: Dictionary) -> void:
	# Update the server-side player node's inventory
	if NetworkService.is_server():
		var players = get_tree().get_nodes_in_group("players").filter(func(p): return is_instance_valid(p) and p.player_id == peer_id)
		if players.size() > 0:
			InventoryService.load_inventory_for_player(players[0], data["id"], data.get("inventory", {}))
			players[0].refresh_held_item() # Trigger refresh on server
	
	if peer_id == 1: fulfill_update(data)
	else: rpc_id(peer_id, "fulfill_update", data)

func relay_login_failure(peer_id: int, reason: String) -> void:
	if peer_id == 1: fulfill_login_failure(reason)
	else: rpc_id(peer_id, "fulfill_login_failure", reason)

func _on_server_request_completed(collection: String, method: String, response_code: int, result: Variant) -> void:
	if response_code >= 400:
		printerr("[PocketBaseRPCManager] Server-side PB Error: ", response_code, " Result: ", result)
