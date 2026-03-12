extends Node

const HUB_SCENE = "res://scenes/levels/hub/Hub.tscn"
const DUNGEON_SCENE = "res://scenes/levels/dungeon/Dungeon.tscn"

const MENU_SCENE = "res://ui/MainMenu.tscn"
const LOADING_SCREEN_PATH = "res://ui/LoadingScreen.tscn"

var loading_screen_instance: Node = null
var pending_username: String = ""
var pending_password: String = ""

# Persistent cache for shard handoffs
var cached_username: String = ""
var cached_password: String = ""
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

	# 1. Update/Restore Credentials
	if username != "":
		print("[SceneManager] Updating credential cache for: ", username)
		cached_username = username
		# Only update password if provided, otherwise keep cached one
		if password != "":
			cached_password = password
		
		pending_username = cached_username
		pending_password = cached_password
	elif cached_username != "":
		print("[SceneManager] Restoring credentials from cache: ", cached_username)
		pending_username = cached_username
		pending_password = cached_password

	# 2. Check if scene is already there
	if tree.current_scene and tree.current_scene.scene_file_path == path:
		print("[SceneManager] Scene already loaded: ", path)
		# If we are already there and have a pending login, do it now
		# (Note: we use PBHelper here because NetworkManager's connected signal might not fire)
		if pending_username != "":
			print("[SceneManager] Triggering re-login for existing scene.")
			PBHelper.request_login(pending_username, pending_password)
			pending_username = ""
			pending_password = ""
		return

	# 3. Perform Load
	print("[SceneManager] Loading new scene: ", path)
	show_loading_screen(true)
	var err = tree.change_scene_to_file(path)
	if err != OK:
		printerr("[SceneManager] Failed to load scene: ", path)
		return
	
	# 4. Cleanup pending login (handled by NetworkManager during shard handoff)
	# If this WASN'T a shard handoff (e.g. initial login), we clear it here 
	# because PBHelper.request_login was already called by the source scene
	pending_username = ""
	pending_password = ""

func reset_credentials() -> void:
	cached_username = ""
	cached_password = ""
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
			loading_screen_instance.queue_free()
			loading_screen_instance = null
			print("[SceneManager] Loading screen removed.")
