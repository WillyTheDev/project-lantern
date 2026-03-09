extends Control

@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel
@onready var username_input: LineEdit = %UsernameInput

func _ready() -> void:
	join_button.pressed.connect(_on_join_pressed)
	
	# Listen for connection success to change scene
	NetworkManager.multiplayer.connected_to_server.connect(_on_connected)
	NetworkManager.multiplayer.connection_failed.connect(_on_failed)

func _on_join_pressed() -> void:
	var username = username_input.text.strip_edges()
	if username == "":
		status_label.text = "Please enter a username!"
		return
		
	status_label.text = "Logging in..."
	join_button.disabled = true
	username_input.editable = false
	
	# 1. Login to PocketBase first
	PersistenceManager.login(username)
	
	# Wait for login to complete (we'll just use a timer or a simple delay for now)
	# In a real app, we'd wait for a signal from PersistenceManager
	await get_tree().create_timer(1.0).timeout
	
	status_label.text = "Connecting to Hub..."
	# 2. Join the Hub Server (Port 9797)
	NetworkManager.join_server(NetworkManager.server_address, NetworkManager.hub_server_port)

func _on_connected() -> void:
	status_label.text = "Connected! Loading Hub..."
	# Tell SceneManager to load the Hub scene
	SceneManager._load_scene(SceneManager.HUB_SCENE)

func _on_failed() -> void:
	status_label.text = "Connection Failed. Is the Hub Server running?"
	join_button.disabled = false
	username_input.editable = true
