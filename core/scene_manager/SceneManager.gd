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

	match NetworkManager.current_role:
		NetworkManager.Role.HUB_SERVER:
			_load_scene.call_deferred(HUB_SCENE)
		NetworkManager.Role.DUNGEON_SERVER:
			_load_scene.call_deferred(DUNGEON_SCENE)
		NetworkManager.Role.CLIENT:
			_load_scene.call_deferred(MENU_SCENE)

func _load_scene(path: String, username: String = "", password: String = "") -> void:
	if not is_inside_tree(): return
	var tree = get_tree()
	if not tree: return

	# 1. Update Credentials if provided (usually only from MainMenu)
	if username != "":
		print("[SceneManager] Updating username cache for: ", username)
		cached_username = username
	if password != "":
		cached_password = password

	# 2. Check if scene is already there
	if tree.current_scene and tree.current_scene.scene_file_path == path:
		print("[SceneManager] Scene already loaded: ", path)
		if is_switching_shard:
			print("[SceneManager] Re-triggering shard login for existing scene type.")
			if cached_token != "":
				PBHelper.request_login_with_token(cached_token)
			elif cached_username != "" and cached_password != "":
				PBHelper.request_login(cached_username, cached_password)
			is_switching_shard = false
		return

	# 3. Perform Asynchronous Load
	print("[SceneManager] Loading new scene asynchronously: ", path)
	show_loading_screen(true)

	var err = ResourceLoader.load_threaded_request(path)
	if err != OK:
		printerr("[SceneManager] Failed to request threaded load: ", path)
		return

	var progress = []
	while true:
		var status = ResourceLoader.load_threaded_get_status(path, progress)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# Finished!
			var new_scene_resource = ResourceLoader.load_threaded_get(path)
			tree.change_scene_to_packed(new_scene_resource)
			print("[SceneManager] Scene loaded successfully: ", path)
			break
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# Update progress bar
			if loading_screen_instance and loading_screen_instance.has_method("update_progress"):
				loading_screen_instance.update_progress(progress[0])
		else:
			# Error (Failed or Invalid Resource)
			printerr("[SceneManager] Error during threaded load: ", status)
			show_loading_screen(false)
			return

		await tree.process_frame

func reset_credentials() -> void:
	cached_username = ""
	cached_password = ""
	cached_token = ""
	is_switching_shard = false
	print("[SceneManager] Credential cache cleared.")

func show_loading_screen(show: bool) -> void:
	if show:
		if not loading_screen_instance:
			var scene = load(LOADING_SCREEN_PATH)
			loading_screen_instance = scene.instantiate()
			get_tree().root.add_child(loading_screen_instance)
			print("[SceneManager] Loading screen visible.")
	else:
		if loading_screen_instance:
			if loading_screen_instance.has_method("fade_out"):
				loading_screen_instance.fade_out()
			else:
				loading_screen_instance.queue_free()
			loading_screen_instance = null
			print("[SceneManager] Loading screen removal initiated (fade out).")
