extends Node

## PocketBaseRESTManager
## Handles generic REST interactions with PocketBase (Server-Side only).
## Refactored to use PBRequest objects for cleaner lifecycle management.

signal request_completed(collection: String, method: String, response_code: int, result: Variant)

var base_url: String = "http://127.0.0.1:8090"
var auth_token: String = ""

var auth_retry_count: int = 0
const MAX_AUTH_RETRIES: int = 2
const AUTH_RETRY_DELAY: float = 1.0

# Session data
var current_player_id: String = ""
var current_player_name: String = ""

# Maps to track names and user_ids per peer during login process
var pending_logins: Dictionary = {} 
var pending_user_ids: Dictionary = {}

func _ready() -> void:
	if OS.has_environment("POCKETBASE_URL"):
		base_url = OS.get_environment("POCKETBASE_URL")
	print("[PocketBaseRESTManager] Initialized with Base URL: ", base_url)
	
	if NetworkService.is_server():
		auth_system_server()
		
	EventBus.session_ended.connect(reset_session)

## Authenticate the Server as a System User
func auth_system_server() -> void:
	var identity = OS.get_environment("PB_SYSTEM_USER")
	var password = OS.get_environment("PB_SYSTEM_PASSWORD")
	
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pb_user="): identity = arg.split("=")[1]
		if arg.begins_with("--pb_pass="): password = arg.split("=")[1]
	
	if identity == "" or password == "":
		printerr("[PocketBaseRESTManager] PB_SYSTEM_USER/PASSWORD not set.")
		PocketBaseRPCManager.server_auth_complete.emit(false)
		return
	
	var url = base_url + "/api/collections/system_accounts/auth-with-password"
	var body = {"identity": identity, "password": password}
	
	_send_request(url, HTTPClient.METHOD_POST, body, func(code, res):
		if code == 200 and res is Dictionary and res.has("token"):
			auth_token = "Bearer " + res["token"]
			print("[PocketBaseRESTManager] System Authentication SUCCESS.")
			auth_retry_count = 0
			PocketBaseRPCManager.server_auth_complete.emit(true)
		else:
			printerr("[PocketBaseRESTManager] System Authentication FAILED (code: ", code, ")")
			if auth_retry_count < MAX_AUTH_RETRIES:
				auth_retry_count += 1
				await get_tree().create_timer(AUTH_RETRY_DELAY).timeout
				auth_system_server()
			else:
				PocketBaseRPCManager.server_auth_complete.emit(false)
	)

## Core wrapper for constructing and queueing asynchronous PBHTTPRequest objects.
## Automates headers, JSON stringification, and callback hooking.
##
## @param url: Total destination URL.
## @param method: HTTPClient Method constant.
## @param body_dict: Dictionary to serialize into JSON.
## @param callback: The Callable to execute on completion.
## @param custom_headers: (Optional) Array of extra strings.
## @param requester_id: (Optional) Associated peer ID to track asynchronous origin.
func _send_request(url: String, method: int, body_dict: Dictionary, callback: Callable, custom_headers: Array = [], requester_id: int = 1) -> void:
	var headers = ["Content-Type: application/json"]
	headers.append_array(custom_headers)
	if auth_token != "" and not "Authorization" in "".join(custom_headers):
		headers.append("Authorization: " + auth_token)
	
	var body_str = JSON.stringify(body_dict) if not body_dict.is_empty() else ""
	var request = PBRequest.new(url, method, headers, body_str, requester_id)
	request.completed.connect(callback)
	request.execute(self)

## Register a new User and Player record
func register(username: String, email: String, password: String, requester_id: int = 1) -> void:
	var url = base_url + "/api/collections/users/records"
	var body = {
		"username": username,
		"email": email,
		"password": password,
		"passwordConfirm": password,
		"name": username
	}
	
	print("[PocketBaseRESTManager] Registering new user: ", username)
	_send_request(url, HTTPClient.METHOD_POST, body, func(code, res):
		if (code == 200 or code == 204) and res is Dictionary:
			var user_id = res.get("id", "")
			if user_id != "":
				var initial_inv = InventoryData.new().to_dict()
				initial_inv["stash"] = InventoryData.new().to_dict()
				initial_inv["stats"] = PlayerStatsData.new().to_dict()
				create_record("players", {"name": username, "user": user_id, "inventory": initial_inv}, requester_id)
				return
		
		var msg = res.get("message", "Registration failed.") if res is Dictionary else "Registration failed."
		PocketBaseRPCManager.relay_login_failure(requester_id, msg)
	)

## Login / Authenticate Player
func login(identity: String, password: String, requester_id: int = 1) -> void:
	pending_logins[requester_id] = identity
	var url = base_url + "/api/collections/users/auth-with-password"
	var body = {"identity": identity, "password": password}
	
	print("[PocketBaseRESTManager] Authenticating user: ", identity, " (peer: ", requester_id, ")")
	_send_request(url, HTTPClient.METHOD_POST, body, func(code, res):
		if code == 200 and res is Dictionary and res.has("record"):
			var user_id = res["record"]["id"]
			var token = res["token"]
			pending_user_ids[requester_id] = user_id
			_get_player_record(user_id, token, requester_id)
		else:
			var msg = res.get("message", "Invalid username or password.") if res is Dictionary else "Invalid credentials."
			PocketBaseRPCManager.relay_login_failure(requester_id, msg)
			_cleanup_pending(requester_id)
	)

## Token-based authentication endpoint wrapper.
## Attempts to refresh the provided JWT and fetch player profiles on success.
func login_with_token(token: String, requester_id: int = 1) -> void:
	var url = base_url + "/api/collections/users/auth-refresh"
	var headers = ["Authorization: Bearer " + token]
	
	print("[PocketBaseRESTManager] Authenticating with Token (peer: ", requester_id, ")")
	_send_request(url, HTTPClient.METHOD_POST, {}, func(code, res):
		if code == 200 and res is Dictionary and res.has("record"):
			var user_id = res["record"]["id"]
			var new_token = res["token"]
			pending_user_ids[requester_id] = user_id
			pending_logins[requester_id] = res["record"].get("username", "Unknown")
			_get_player_record(user_id, new_token, requester_id)
		else:
			var msg = res.get("message", "Session expired.") if res is Dictionary else "Invalid token."
			PocketBaseRPCManager.relay_login_failure(requester_id, msg)
			_cleanup_pending(requester_id)
	, headers)

func _get_player_record(user_id: String, token: String, requester_id: int) -> void:
	var url = base_url + "/api/collections/players/records?filter=(user='" + user_id + "')"
	_send_request(url, HTTPClient.METHOD_GET, {}, func(code, res):
		if code >= 200 and code < 300 and res is Dictionary:
			if res.has("items") and res["items"].size() > 0:
				var player_data = res["items"][0]
				player_data["auth_token"] = token
				_finalize_login(requester_id, player_data)
			else:
				_create_new_player(requester_id, token)
		else:
			PocketBaseRPCManager.relay_login_failure(requester_id, "Failed to load player record.")
			_cleanup_pending(requester_id)
	)

## Helper to issue a raw creation POST request to an arbitrary collection.
func create_record(collection: String, data: Dictionary, requester_id: int = 1) -> void:
	_make_request(collection, HTTPClient.METHOD_POST, data, "", requester_id)

## Helper to issue a raw modification PATCH request against an arbitrary collection.
func update_record(collection: String, id: String, data: Dictionary, requester_id: int = 1) -> void:
	_make_request(collection, HTTPClient.METHOD_PATCH, data, "/" + id, requester_id)

func _make_request(collection: String, method: int, data: Dictionary, url_suffix: String, requester_id: int) -> void:
	var url = base_url + "/api/collections/" + collection + "/records" + url_suffix
	_send_request(url, method, data, func(code, res):
		var method_str = _get_method_string(method)
		_on_request_completed(collection, method_str, code, res, requester_id)
		request_completed.emit(collection, method_str, code, res)
	)

func _on_request_completed(collection: String, method: String, response_code: int, result: Variant, requester_id: int) -> void:
	if collection == "players":
		if response_code >= 200 and response_code < 300 and result is Dictionary:
			if method == "POST": _finalize_login(requester_id, result)
			elif method == "PATCH": PocketBaseRPCManager.relay_update_success(requester_id, result)
		else:
			var msg = result.get("message", "Database error.") if result is Dictionary else "DB Error."
			PocketBaseRPCManager.relay_login_failure(requester_id, msg)
			_cleanup_pending(requester_id)

func _create_new_player(requester_id: int, token: String = "") -> void:
	var username = pending_logins.get(requester_id, "UnknownPlayer")
	var user_id = pending_user_ids.get(requester_id, "")
	
	var initial_inv = InventoryData.new().to_dict()
	initial_inv["stash"] = InventoryData.new().to_dict()
	initial_inv["stats"] = PlayerStatsData.new().to_dict()
	
	var initial_data = {"name": username, "user": user_id, "inventory": initial_inv}
	
	var url = base_url + "/api/collections/players/records"
	_send_request(url, HTTPClient.METHOD_POST, initial_data, func(code, res):
		if code >= 200 and code < 300 and res is Dictionary:
			res["auth_token"] = token
			_finalize_login(requester_id, res)
		else:
			PocketBaseRPCManager.relay_login_failure(requester_id, "Failed to create player record.")
			_cleanup_pending(requester_id)
	)

func _finalize_login(requester_id: int, data: Dictionary) -> void:
	_cleanup_pending(requester_id)
	PocketBaseRPCManager.relay_login_success(requester_id, data)

## Triggers clearance of sensitive memory properties via EventBus bindings on logout.
func reset_session() -> void:
	current_player_id = ""
	current_player_name = ""
	pending_logins.clear()
	pending_user_ids.clear()
	print("[PocketBaseRESTManager] Session reset.")

func _cleanup_pending(requester_id: int) -> void:
	pending_logins.erase(requester_id)
	pending_user_ids.erase(requester_id)

func _get_method_string(method: int) -> String:
	match method:
		HTTPClient.METHOD_GET: return "GET"
		HTTPClient.METHOD_POST: return "POST"
		HTTPClient.METHOD_PATCH: return "PATCH"
		HTTPClient.METHOD_DELETE: return "DELETE"
		_: return "UNKNOWN"
