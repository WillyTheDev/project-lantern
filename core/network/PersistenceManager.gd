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
# Map to track names per peer during login process
var pending_logins: Dictionary = {} 

func _ready() -> void:
	# Check for environment variable (useful for Docker/K8s)
	if OS.has_environment("POCKETBASE_URL"):
		base_url = OS.get_environment("POCKETBASE_URL")
	print("[PersistenceManager] Initialized with Base URL: ", base_url)

## Login / Get or Create Player
func login(username: String, requester_id: int = 1) -> void:
	pending_logins[requester_id] = username
	# 1. Try to find the player by name
	get_records("players", "name='" + username + "'", requester_id)

## Generic Create (POST)
func create_record(collection: String, data: Dictionary, requester_id: int = 1) -> void:
	_make_request(collection, HTTPClient.METHOD_POST, data, "", requester_id)

## Generic Read (GET) with optional filter
func get_records(collection: String, filter: String = "", requester_id: int = 1) -> void:
	var url_suffix = ""
	if filter != "":
		url_suffix = "?filter=(" + filter.uri_encode() + ")"
	_make_request(collection, HTTPClient.METHOD_GET, {}, url_suffix, requester_id)

## Generic Update (PATCH)
func update_record(collection: String, id: String, data: Dictionary, requester_id: int = 1) -> void:
	_make_request(collection, HTTPClient.METHOD_PATCH, data, "/" + id, requester_id)

## Internal request helper
func _make_request(collection: String, method: int, data: Dictionary = {}, url_suffix: String = "", requester_id: int = 1) -> void:
	# Only the server can talk to PocketBase
	if not multiplayer.is_server() and not OS.has_feature("dedicated_server"):
		return
		
	var http = HTTPRequest.new()
	add_child(http)
	
	var url = base_url + "/api/collections/" + collection + "/records" + url_suffix
	var method_str = _get_method_string(method)
	print("[PersistenceManager] [Server] Sending ", method_str, " to: ", url, " (For Peer: ", requester_id, ")")
	
	var headers = ["Content-Type: application/json"]
	if auth_token != "":
		headers.append("Authorization: " + auth_token)
	
	var body = ""
	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(data)
	
	http.request_completed.connect(func(result, response_code, _headers, _body):
		var response_str = _body.get_string_from_utf8()
		var json_result = JSON.parse_string(response_str)
		
		print("[PersistenceManager] [Server] Response from ", collection, ": Code ", response_code)
		
		_on_request_completed(collection, method_str, response_code, json_result, requester_id)
		request_completed.emit(collection, method_str, response_code, json_result)
		http.queue_free()
	)
	
	var err = http.request(url, headers, method, body)
	if err != OK:
		printerr("[PersistenceManager] Request error: ", err)
		http.queue_free()

func _on_request_completed(collection: String, method: String, response_code: int, result: Variant, requester_id: int) -> void:
	if collection == "players":
		if method == "GET" and result is Dictionary and result.has("items"):
			if result["items"].size() > 0:
				# Player exists
				var data = result["items"][0]
				print("[PersistenceManager] Player found: ", data["name"])
				pending_logins.erase(requester_id)
				PBHelper.relay_login_success(requester_id, data)
			else:
				# Create new player
				var username = pending_logins.get(requester_id, "UnknownPlayer")
				print("[PersistenceManager] Creating new player: ", username, " for peer: ", requester_id)
				var initial_data = {
					"name": username,
					"inventory": {},
					"prestige": 0
				}
				_make_request("players", HTTPClient.METHOD_POST, initial_data, "", requester_id)
		
		elif method == "POST" and result is Dictionary and result.has("id"):
			# New player created, relay to client
			pending_logins.erase(requester_id)
			PBHelper.relay_login_success(requester_id, result)

func _get_method_string(method: int) -> String:
	match method:
		HTTPClient.METHOD_GET: return "GET"
		HTTPClient.METHOD_POST: return "POST"
		HTTPClient.METHOD_PATCH: return "PATCH"
		HTTPClient.METHOD_DELETE: return "DELETE"
		_: return "UNKNOWN"
