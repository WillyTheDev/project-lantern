extends Node

## PersistenceManager
## Handles generic REST interactions with PocketBase.

signal request_completed(collection: String, method: String, response_code: int, result: Variant)

var base_url: String = "http://127.0.0.1:8090"
var auth_token: String = ""

# Session data
var current_player_id: String = ""
var current_player_name: String = ""

func _ready() -> void:
	# Check for environment variable (useful for Docker/K8s)
	if OS.has_environment("POCKETBASE_URL"):
		base_url = OS.get_environment("POCKETBASE_URL")
	print("[PersistenceManager] Initialized with Base URL: ", base_url)

## Login / Get or Create Player
func login(username: String) -> void:
	current_player_name = username
	# 1. Try to find the player by name
	get_records("players", "name='" + username + "'")

## Generic Create (POST)
func create_record(collection: String, data: Dictionary) -> void:
	_make_request(collection, HTTPClient.METHOD_POST, data)

## Generic Read (GET) with optional filter
func get_records(collection: String, filter: String = "") -> void:
	var url_suffix = ""
	if filter != "":
		url_suffix = "?filter=(" + filter.uri_encode() + ")"
	_make_request(collection, HTTPClient.METHOD_GET, {}, url_suffix)

## Generic Update (PATCH)
func update_record(collection: String, id: String, data: Dictionary) -> void:
	_make_request(collection, HTTPClient.METHOD_PATCH, data, "/" + id)

## Internal request helper
func _make_request(collection: String, method: int, data: Dictionary = {}, url_suffix: String = "") -> void:
	var http = HTTPRequest.new()
	add_child(http)
	
	var url = base_url + "/api/collections/" + collection + "/records" + url_suffix
	var headers = ["Content-Type: application/json"]
	if auth_token != "":
		headers.append("Authorization: " + auth_token)
	
	var body = ""
	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(data)
	
	http.request_completed.connect(func(result, response_code, _headers, _body):
		var json_result = JSON.parse_string(_body.get_string_from_utf8())
		_on_request_completed(collection, _get_method_string(method), response_code, json_result)
		request_completed.emit(collection, _get_method_string(method), response_code, json_result)
		http.queue_free()
	)
	
	var err = http.request(url, headers, method, body)
	if err != OK:
		printerr("[PersistenceManager] Request error: ", err)
		http.queue_free()

func _on_request_completed(collection: String, method: String, response_code: int, result: Variant) -> void:
	if collection == "players":
		if method == "GET" and result.has("items"):
			if result["items"].size() > 0:
				# Player exists
				var data = result["items"][0]
				current_player_id = data["id"]
				print("[PersistenceManager] Logged in as: ", current_player_name, " (ID: ", current_player_id, ")")
				InventoryManager.load_inventory(current_player_id, data.get("inventory", {}))
			else:
				# Create new player
				print("[PersistenceManager] Player not found. Creating: ", current_player_name)
				create_record("players", {"name": current_player_name, "inventory": {}})
		
		elif method == "POST" and result.has("id"):
			# New player created
			current_player_id = result["id"]
			print("[PersistenceManager] Created player: ", current_player_name, " (ID: ", current_player_id, ")")
			InventoryManager.load_inventory(current_player_id, {})

func _get_method_string(method: int) -> String:
	match method:
		HTTPClient.METHOD_GET: return "GET"
		HTTPClient.METHOD_POST: return "POST"
		HTTPClient.METHOD_PATCH: return "PATCH"
		HTTPClient.METHOD_DELETE: return "DELETE"
		_: return "UNKNOWN"
