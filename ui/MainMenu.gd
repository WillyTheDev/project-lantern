extends Control

@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel
@onready var username_input: LineEdit = %UsernameInput

var pending_username: String = ""

func _ready() -> void:
	join_button.pressed.connect(_on_join_pressed)
	
	# Listen for connection success
	NetworkManager.multiplayer.connected_to_server.connect(_on_connected)
	NetworkManager.multiplayer.connection_failed.connect(_on_failed)

func _on_join_pressed() -> void:
	var username = username_input.text.strip_edges()
	if username == "":
		status_label.text = "Please enter a username!"
		return
		
	pending_username = username
	status_label.text = "Connecting to Hub..."
	join_button.disabled = true
	username_input.editable = false
	
	# 1. Connect to Hub Server first (Server must be the gateway to PocketBase)
	NetworkManager.join_server(NetworkManager.server_address, NetworkManager.hub_server_port)

func _on_connected() -> void:
	status_label.text = "Loading Hub..."
	# 2. Tell SceneManager to load scene AND remember username for the login
	# Use call_deferred to avoid tree state issues during signal callback
	SceneManager.call_deferred("_load_scene", SceneManager.HUB_SCENE, pending_username)

func _on_failed() -> void:
	status_label.text = "Connection Failed. Is the Hub Server running?"
	join_button.disabled = false
	username_input.editable = true
