extends Node

## SessionService
## High-level facade for User Authentication and Session Management.
## Coordinates login, registration, and global state reset.

signal session_started(user_data: Dictionary)
signal session_ended
signal auth_failed(reason: String)

var session: SessionData = SessionData.new()

func _ready() -> void:
	# Listen for lower-level auth results from PocketBaseRPCManager
	PocketBaseRPCManager.player_data_loaded.connect(_on_auth_success)
	PocketBaseRPCManager.player_data_sync_failed.connect(_on_auth_failed)

func login(identity: String, password: String) -> void:
	print("[SessionService] Attempting login for: ", identity)
	PocketBaseRPCManager.request_login(identity, password)

func login_with_token(token: String) -> void:
	print("[SessionService] Attempting token re-auth.")
	PocketBaseRPCManager.request_login_with_token(token)

func register(username: String, email: String, password: String) -> void:
	print("[SessionService] Attempting registration for: ", username)
	PocketBaseRPCManager.request_register(username, email, password)

func logout() -> void:
	print("[SessionService] Logging out.")
	_clear_all_systems()
	session_ended.emit()

func _on_auth_success(data: Dictionary) -> void:
	session.user_id = data.get("id", "")
	session.username = data.get("name", "")
	session.auth_token = data.get("auth_token", "")
	session.is_authenticated = true
	
	print("[SessionService] Session started for: ", session.username)
	session_started.emit(data)

func _on_auth_failed(reason: String) -> void:
	print("[SessionService] Auth failed: ", reason)
	_clear_all_systems()
	auth_failed.emit(reason)

func _clear_all_systems() -> void:
	session.clear()
	
	# Coordinate reset across other services
	if InventoryService.has_method("reset"):
		InventoryService.reset()
	
	if PocketBaseRESTManager.has_method("reset_session"):
		PocketBaseRESTManager.reset_session()
	
	if SceneService.has_method("reset_credentials"):
		SceneService.reset_credentials()
	
	print("[SessionService] Global state cleared.")
