extends Node

const HUB_SCENE = "res://scenes/levels/hub/Hub.tscn"
const DUNGEON_SCENE = "res://scenes/levels/dungeon/Dungeon.tscn"

const MENU_SCENE = "res://ui/MainMenu.tscn"
const LOADING_SCREEN_PATH = "res://ui/LoadingScreen.tscn"

var loading_screen_instance: Node = null

# Persistent cache for shard handoffs
var cached_username: String = ""
var cached_password: String = "" # Keep for initial login retry if needed
var cached_token: String = ""
var is_switching_shard: bool = false # NEW FLAG

func _ready() -> void:
	await get_tree().process_frame
	if not is_inside_tree(): return
	
	# Listen for failures to clear loading screen
	PocketBaseRPCManager.player_data_sync_failed.connect(_on_critical_failure)
	NetworkService.multiplayer.connection_failed.connect(func(): _on_critical_failure("Connection failed"))
	NetworkService.multiplayer.server_disconnected.connect(func(): _on_critical_failure("Server disconnected"))
	EventBus.session_ended.connect(reset_credentials)

	match NetworkService.current_role:
		NetworkService.Role.HUB_SERVER:
			_load_scene.call_deferred(HUB_SCENE)
		NetworkService.Role.DUNGEON_SERVER:
			_load_scene.call_deferred(DUNGEON_SCENE)
		NetworkService.Role.CLIENT:
			_load_scene.call_deferred(MENU_SCENE)

## Internal callback triggered when a critical connection failure occurs (e.g., server disconnect).
## Dismisses the loading screen if active.
##
## @param _reason: The error message or reason for the failure.
func _on_critical_failure(_reason: String) -> void:
	if loading_screen_instance:
		print("[SceneService] Critical failure detected while loading screen active. Hiding.")
		show_loading_screen(false)

## Asynchronously loads a new scene using ResourceLoader in a background thread.
## Can also cache user credentials if provided during the initial Hub login.
##
## @param path: The absolute `res://` path to the `.tscn` file.
## @param username: (Optional) The username to cache for handoffs.
## @param password: (Optional) The password to cache for handoffs.
func _load_scene(path: String, username: String = "", password: String = "") -> void:
	if not is_inside_tree(): return
	var tree = get_tree()
	if not tree: return

	# 1. Update Credentials if provided (usually only from MainMenu)
	if username != "":
		print("[SceneService] Updating username cache for: ", username)
		cached_username = username
	if password != "":
		cached_password = password

	# 2. Check if scene is already there
	if tree.current_scene and tree.current_scene.scene_file_path == path:
		print("[SceneService] Scene already loaded: ", path)
		if is_switching_shard:
			_wait_and_reauth()
			is_switching_shard = false
		return

	# 3. Perform Asynchronous Load
	print("[SceneService] Loading new scene asynchronously: ", path)
	var scene_name = "Hub" if "Hub" in path else ("Dungeon" if "Dungeon" in path else "Game")
	show_loading_screen(true, "Preparing " + scene_name + "...")

	var err = ResourceLoader.load_threaded_request(path)
	if err != OK:
		printerr("[SceneService] Failed to request threaded load: ", path)
		return

	var progress = []
	while true:
		var status = ResourceLoader.load_threaded_get_status(path, progress)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# Finished!
			update_status("Finalizing " + scene_name + "...")
			var new_scene_resource = ResourceLoader.load_threaded_get(path)
			tree.change_scene_to_packed(new_scene_resource)
			print("[SceneService] Scene loaded successfully: ", path)
			
			# NEW: Trigger Session Login if we are a client entering a game scene
			if path != MENU_SCENE and NetworkService.current_role == NetworkService.Role.CLIENT:
				_wait_and_reauth()
			
			break
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# Update progress bar
			if loading_screen_instance and loading_screen_instance.has_method("update_progress"):
				loading_screen_instance.update_progress(progress[0])
				if progress[0] > 0.9:
					update_status("Almost there...")
				elif progress[0] > 0.5:
					update_status("Streaming World Data...")
		else:
			# Error (Failed or Invalid Resource)
			printerr("[SceneService] Error during threaded load: ", status)
			show_loading_screen(false)
			return

		await tree.process_frame

## Coroutine that waits for the low-level ENet connection to establish, then requests
## re-authentication via the SessionService using cached credentials or tokens.
func _wait_and_reauth() -> void:
	print("[SceneService] Post-transition: Waiting for connection before session synchronization.")
	update_status("Connecting to Server...")
	
	var mp = NetworkService.multiplayer
	
	# If not connected yet, wait for the signal
	if mp.multiplayer_peer == null or mp.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await mp.connected_to_server
		
	print("[SceneService] Connection established. Triggering re-auth.")
	update_status("Synchronizing Session...")
	
	if cached_token != "":
		SessionService.login_with_token(cached_token)
	elif cached_username != "" and cached_password != "":
		SessionService.login(cached_username, cached_password)

## Clears the persistent credential cache used for shard handoffs.
func reset_credentials() -> void:
	cached_username = ""
	cached_password = ""
	cached_token = ""
	is_switching_shard = false
	print("[SceneService] Credential cache cleared.")

## Instantiates and displays the global Loading Screen UI over the current scene.
##
## @param show: Whether to show or hide the loading screen.
## @param initial_status: The text to display immediately on showing.
func show_loading_screen(show: bool, initial_status: String = "Loading...") -> void:
	if show:
		if not loading_screen_instance:
			var scene = load(LOADING_SCREEN_PATH)
			loading_screen_instance = scene.instantiate()
			get_tree().root.add_child(loading_screen_instance)
			if loading_screen_instance.has_method("set_status"):
				loading_screen_instance.set_status(initial_status)
			print("[SceneService] Loading screen visible.")
		else:
			update_status(initial_status)
	else:
		if loading_screen_instance:
			if loading_screen_instance.has_method("fade_out"):
				loading_screen_instance.fade_out()
			else:
				loading_screen_instance.queue_free()
			loading_screen_instance = null
			print("[SceneService] Loading screen removal initiated (fade out).")

## Updates the progress text on the active loading screen instance.
##
## @param text: The status string to display (e.g., "Downloading Map...").
func update_status(text: String) -> void:
	if loading_screen_instance and loading_screen_instance.has_method("set_status"):
		loading_screen_instance.set_status(text)
