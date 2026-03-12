extends Control

@onready var join_button: Button = %JoinButton
@onready var register_toggle: CheckButton = %RegisterToggle # We'll add this
@onready var email_input: LineEdit = %EmailInput # We'll add this
@onready var status_label: Label = %StatusLabel
@onready var username_input: LineEdit = %UsernameInput
@onready var password_input: LineEdit = %PasswordInput

var pending_username: String = ""
var pending_password: String = ""
var pending_email: String = ""

func _ready() -> void:
	join_button.pressed.connect(_on_join_pressed)
	register_toggle.toggled.connect(_on_register_toggled)
	
	# Initial UI state
	email_input.visible = false
	
	# Listen for connection success
	NetworkManager.multiplayer.connected_to_server.connect(_on_connected)
	NetworkManager.multiplayer.connection_failed.connect(_on_failed)
	
	# Listen for Auth results
	PBHelper.player_data_loaded.connect(_on_auth_success)
	PBHelper.player_data_sync_failed.connect(_on_auth_failed)

func _on_register_toggled(is_registering: bool) -> void:
	email_input.visible = is_registering
	join_button.text = "CREATE ACCOUNT" if is_registering else "ENTER THE WORLD"
	status_label.text = "Switching to registration..." if is_registering else "Switching to login..."

func _on_join_pressed() -> void:
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var email = email_input.text.strip_edges()
	
	if username == "" or password == "":
		status_label.text = "Please enter both username and password!"
		return
		
	if register_toggle.button_pressed and email == "":
		status_label.text = "Please enter an email for registration!"
		return
		
	pending_username = username
	pending_password = password
	pending_email = email
	
	status_label.text = "Connecting to Hub..."
	join_button.disabled = true
	username_input.editable = false
	password_input.editable = false
	email_input.editable = false
	
	# Connect to server
	NetworkManager.join_server(NetworkManager.server_address, NetworkManager.hub_server_port)

func _on_connected() -> void:
	if register_toggle.button_pressed:
		status_label.text = "Registering..."
		PBHelper.request_register(pending_username, pending_email, pending_password)
	else:
		status_label.text = "Authenticating..."
		PBHelper.request_login(pending_username, pending_password)

func _on_auth_success(_data: Dictionary) -> void:
	status_label.text = "Success! Entering world..."
	SceneManager.call_deferred("_load_scene", SceneManager.HUB_SCENE)

func _on_auth_failed(reason: String) -> void:
	status_label.text = "Error: " + reason
	join_button.disabled = false
	username_input.editable = true
	password_input.editable = true
	email_input.editable = true
	
	if NetworkManager.multiplayer.multiplayer_peer:
		NetworkManager.multiplayer.multiplayer_peer.close()

func _on_failed() -> void:
	status_label.text = "Connection Failed. Is the Hub Server running?"
	join_button.disabled = false
	username_input.editable = true
	password_input.editable = true
	email_input.editable = true
