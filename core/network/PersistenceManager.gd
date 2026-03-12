extends Node

## PersistenceManager
## Handles generic REST interactions with PocketBase.
## Now modified to be Server-Side only.

signal request_completed(collection: String, method: String, response_code: int, result: Variant)

var base_url: String = "http://127.0.0.1:8090"
var auth_token: String = ""

# Session data
var current_player_id: String = ""
var current_player_name: String = ""

# Maps to track names and user_ids per peer during login process
var pending_logins: Dictionary = {} 
var pending_user_ids: Dictionary = {}

func _ready() -> void:
	# Check for environment variable (useful for Docker/K8s)
	if OS.has_environment("POCKETBASE_URL"):
		base_url = OS.get_environment("POCKETBASE_URL")
	print("[PersistenceManager] Initialized with Base URL: ", base_url)
	
	# Only the server needs to authenticate with the system account
	if multiplayer.is_server():
		auth_system_server()

## Authenticate the Server as a System User (Limited Privileges)
func auth_system_server() -> void:
	var identity = OS.get_environment("PB_SYSTEM_USER")
	var password = OS.get_environment("PB_SYSTEM_PASSWORD")
	
	# Also check command-line arguments (useful for Godot Editor "Main Run Args")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pb_user="):
			identity = arg.split("=")[1]
		if arg.begins_with("--pb_pass="):
			password = arg.split("=")[1]
	
	if identity == "" or password == "":
		printerr("[PersistenceManager] WARNING: PB_SYSTEM_USER or PB_SYSTEM_PASSWORD not set.")
		return
	
	var url = base_url + "/api/collections/system_accounts/auth-with-password"
	var body = {"identity": identity, "password": password}
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(result, response_code, _headers, _body):
		var response_str = _body.get_string_from_utf8()
		var json_result = JSON.parse_string(response_str)
		
		if response_code == 200 and json_result is Dictionary and json_result.has("token"):
			auth_token = "Bearer " + json_result["token"]
			print("[PersistenceManager] [Server] System Authentication SUCCESS.")
			PBHelper.server_auth_complete.emit(true)
		else:
			printerr("[PersistenceManager] [Server] System Authentication FAILED: ", response_code)
			PBHelper.server_auth_complete.emit(false)
		http.queue_free()
	)
	
	var err = http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		printerr("[PersistenceManager] Request error in auth_system_server: ", err)
		http.queue_free()

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
	
	var http = HTTPRequest.new()
	add_child(http)
	
	print("[PersistenceManager] [Server] Registering new user: ", username)
	
	http.request_completed.connect(func(result, response_code, _headers, _body):
		var response_str = _body.get_string_from_utf8()
		var json_result = JSON.parse_string(response_str)
		
		if (response_code == 200 or response_code == 204) and json_result is Dictionary:
			var user_id = json_result.get("id", "")
			if user_id != "":
				var player_data = {"name": username, "user": user_id, "inventory": {"init": true}, "prestige": 0}
				create_record("players", player_data, requester_id)
				http.queue_free()
				return
		
		# Fallthrough: Failure
		var msg = "Registration failed."
		if json_result is Dictionary and json_result.has("message"): msg = json_result["message"]
		PBHelper.relay_login_failure(requester_id, msg)
		http.queue_free()
	)
	
	var headers = ["Content-Type: application/json"]
	if auth_token != "": headers.append("Authorization: " + auth_token)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

## Login / Authenticate Player (Server-Authoritative)
func login(identity: String, password: String, requester_id: int = 1) -> void:
	pending_logins[requester_id] = identity
	var url = base_url + "/api/collections/users/auth-with-password"
	var body = {"identity": identity, "password": password}
	
	var http = HTTPRequest.new()
	add_child(http)
	
	print("[PersistenceManager] [Server] Authenticating user: ", identity, " for peer: ", requester_id)
	
	http.request_completed.connect(func(result, response_code, _headers, _body):
		var response_str = _body.get_string_from_utf8()
		var json_result = JSON.parse_string(response_str)
		
		if response_code == 200 and json_result is Dictionary and json_result.has("record"):
			var user_id = json_result["record"]["id"]
			pending_user_ids[requester_id] = user_id
			get_records("players", "user='" + user_id + "'", requester_id)
		else:
			var msg = "Invalid username or password."
			if json_result is Dictionary and json_result.has("message"): msg = json_result["message"]
			PBHelper.relay_login_failure(requester_id, msg)
			_cleanup_pending(requester_id)
		http.queue_free()
	)
	
	var headers = ["Content-Type: application/json"]
	if auth_token != "": headers.append("Authorization: " + auth_token)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func create_record(collection: String, data: Dictionary, requester_id: int = 1) -> void:
	_make_request(collection, HTTPClient.METHOD_POST, data, "", requester_id)

func get_records(collection: String, filter: String = "", requester_id: int = 1) -> void:
	var url_suffix = ""
	if filter != "": url_suffix = "?filter=(" + filter.uri_encode() + ")"
	_make_request(collection, HTTPClient.METHOD_GET, {}, url_suffix, requester_id)

func update_record(collection: String, id: String, data: Dictionary, requester_id: int = 1) -> void:
	_make_request(collection, HTTPClient.METHOD_PATCH, data, "/" + id, requester_id)

func _make_request(collection: String, method: int, data: Dictionary = {}, url_suffix: String = "", requester_id: int = 1) -> void:
	if not multiplayer.is_server() and not OS.has_feature("dedicated_server"): return
		
	var http = HTTPRequest.new()
	add_child(http)
	
	var url = base_url + "/api/collections/" + collection + "/records" + url_suffix
	var headers = ["Content-Type: application/json"]
	if auth_token != "": headers.append("Authorization: " + auth_token)
	
	var body = ""
	if method != HTTPClient.METHOD_GET: body = JSON.stringify(data)
	
	http.request_completed.connect(func(result, response_code, _headers, _body):
		var response_str = _body.get_string_from_utf8()
		var json_result = JSON.parse_string(response_str)
		_on_request_completed(collection, _get_method_string(method), response_code, json_result, requester_id)
		request_completed.emit(collection, _get_method_string(method), response_code, json_result)
		http.queue_free()
	)
	http.request(url, headers, method, body)

func _on_request_completed(collection: String, method: String, response_code: int, result: Variant, requester_id: int) -> void:
	if collection == "players":
		if response_code >= 200 and response_code < 300 and result is Dictionary:
			if method == "GET" and result.has("items"):
				if result["items"].size() > 0:
					_finalize_login(requester_id, result["items"][0])
				else:
					_create_new_player(requester_id)
			elif method == "POST":
				_finalize_login(requester_id, result)
			elif method == "PATCH":
				_finalize_update(requester_id, result)
		else:
			var msg = "Database error."
			if result is Dictionary and result.has("message"): msg = result["message"]
			PBHelper.relay_login_failure(requester_id, msg)
			_cleanup_pending(requester_id)

func _create_new_player(requester_id: int) -> void:
	var username = pending_logins.get(requester_id, "UnknownPlayer")
	var user_id = pending_user_ids.get(requester_id, "")
	if user_id == "":
		PBHelper.relay_login_failure(requester_id, "Auth state lost. Please try again.")
		return
	var initial_data = {"name": username, "user": user_id, "inventory": {"init": true}, "prestige": 0}
	create_record("players", initial_data, requester_id)

func _finalize_login(requester_id: int, data: Dictionary) -> void:
	_cleanup_pending(requester_id)
	PBHelper.relay_login_success(requester_id, data)

func _finalize_update(requester_id: int, data: Dictionary) -> void:
	PBHelper.relay_update_success(requester_id, data)

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
