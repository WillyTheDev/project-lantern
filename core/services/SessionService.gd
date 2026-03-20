extends Node

## SessionService
## High-level facade for User Authentication and Session Management.
## Coordinates login, registration, and global state reset.


var session: SessionData = SessionData.new()

func _ready() -> void:
	# Listen for lower-level auth results from PocketBaseRPCManager
	PocketBaseRPCManager.player_data_loaded.connect(_on_auth_success)
	PocketBaseRPCManager.player_data_sync_failed.connect(_on_auth_failed)

## Initiates a login request to the PocketBase backend using an identity (email/username) and password.
## 
## @param identity: The user's username or email address.
## @param password: The plain-text password for the account.
func login(identity: String, password: String) -> void:
	print("[SessionService] Attempting login for: ", identity)
	PocketBaseRPCManager.request_login(identity, password)

## Re-authenticates a user using a previously cached JWT auth token.
## Useful for seamless transitions between game shards (e.g., Hub to Dungeon).
## 
## @param token: The JWT authentication token.
func login_with_token(token: String) -> void:
	print("[SessionService] Attempting token re-auth.")
	PocketBaseRPCManager.request_login_with_token(token)

## Registers a new user account on the PocketBase backend.
## 
## @param username: The desired display name (must be unique).
## @param email: The user's email address.
## @param password: The plain-text password for the new account.
func register(username: String, email: String, password: String) -> void:
	print("[SessionService] Attempting registration for: ", username)
	PocketBaseRPCManager.request_register(username, email, password)

## Logs the current user out, clearing local session data and emitting a global session_ended event.
func logout() -> void:
	print("[SessionService] Logging out.")
	_clear_all_systems()
	EventBus.session_ended.emit()

func _on_auth_success(data: Dictionary) -> void:
	session.user_id = data.get("id", "")
	session.username = data.get("name", "")
	session.auth_token = data.get("auth_token", "")
	session.is_authenticated = true
	
	print("[SessionService] Session started for: ", session.username)
	NotificationService.send_success("Welcome back, " + session.username + "!")
	EventBus.session_started.emit(data)

func _on_auth_failed(reason: String) -> void:
	print("[SessionService] Auth failed: ", reason)
	NotificationService.send_error("Authentication Failed: " + reason)
	_clear_all_systems()
	EventBus.auth_failed.emit(reason)

## Internal helper that clears the local SessionData resource.
func _clear_all_systems() -> void:
	session.clear()
	print("[SessionService] Base session cleared. Emitting session_ended for other systems.")
