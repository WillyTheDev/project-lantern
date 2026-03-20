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

var connection_timeout_timer: Timer

func _ready() -> void:
	join_button.pressed.connect(_on_join_pressed)
	register_toggle.toggled.connect(_on_register_toggled)
	
	# Connection timeout timer
	connection_timeout_timer = Timer.new()
	connection_timeout_timer.one_shot = true
	connection_timeout_timer.wait_time = 10.0 # 10 seconds to connect to Hub
	connection_timeout_timer.timeout.connect(_on_connection_timeout)
	add_child(connection_timeout_timer)
	
	# Initial UI state
	email_input.visible = false
	SceneService.show_loading_screen(false)
	
	# Listen for connection success
	NetworkService.multiplayer.connected_to_server.connect(_on_connected)
	NetworkService.multiplayer.connection_failed.connect(_on_failed)
	
	# Listen for Auth results via EventBus
	EventBus.session_started.connect(_on_auth_success)
	EventBus.auth_failed.connect(_on_auth_failed)

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
	
	SceneService.cached_username = username
	
	status_label.text = "Connecting to Hub..."
	join_button.disabled = true
	username_input.editable = false
	password_input.editable = false
	email_input.editable = false
	
	SceneService.show_loading_screen(true, "Searching for Game Server...")
	
	# Start connection timeout
	connection_timeout_timer.start()
	
	NetworkService.join_server(NetworkService.server_address, NetworkService.hub_server_port)

func _on_connected() -> void:
	connection_timeout_timer.stop()
	if not is_inside_tree(): return
	
	if get_tree().current_scene != self: return

	if register_toggle.button_pressed:
		status_label.text = "Registering..."
		SceneService.update_status("Sending Registration Request...")
		SessionService.register(pending_username, pending_email, pending_password)
	else:
		status_label.text = "Authenticating..."
		SceneService.update_status("Sending Authentication Request...")
		SessionService.login(pending_username, pending_password)

func _on_connection_timeout() -> void:
	if NetworkService.multiplayer.multiplayer_peer:
		NetworkService.multiplayer.multiplayer_peer.close()
	_on_failed()
	status_label.text = "Connection Timed Out. Server might be offline."

func _on_register_toggled(is_registering: bool) -> void:
	email_input.visible = is_registering
	join_button.text = "CREATE ACCOUNT" if is_registering else "ENTER THE WORLD"
	status_label.text = "Switching to registration..." if is_registering else "Switching to login..."

func _on_auth_success(_data: Dictionary) -> void:
	# Only proceed if we are actually in the MainMenu scene
	if get_tree().current_scene != self:
		return
		
	status_label.text = "Success! Entering world..."
	SceneService.update_status("Profile Loaded. Entering Hub...")
	SceneService.call_deferred("_load_scene", SceneService.HUB_SCENE)

func _on_auth_failed(reason: String) -> void:
	status_label.text = "Error: " + reason
	join_button.disabled = false
	username_input.editable = true
	password_input.editable = true
	email_input.editable = true
	
	# Hide loading screen so user can see the error
	SceneService.show_loading_screen(false)
	
	if NetworkService.multiplayer.multiplayer_peer:
		NetworkService.multiplayer.multiplayer_peer.close()

func _on_failed() -> void:
	connection_timeout_timer.stop()
	status_label.text = "Connection Failed. Check your internet or server status."
	join_button.disabled = false
	username_input.editable = true
	password_input.editable = true
	email_input.editable = true
	SceneService.show_loading_screen(false)
