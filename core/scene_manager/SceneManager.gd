extends Node

const HUB_SCENE = "res://scenes/levels/hub/Hub.tscn"
const DUNGEON_SCENE = "res://scenes/levels/dungeon/Dungeon.tscn"

const MENU_SCENE = "res://ui/MainMenu.tscn"
const LOADING_SCREEN_PATH = "res://ui/LoadingScreen.tscn"

var loading_screen_instance: Node = null
var pending_username: String = ""
var pending_password: String = ""

func _ready() -> void:
	# Wait for NetworkManager to finish its _ready
	await get_tree().process_frame
	
	# Only the root instance (Autoload) should run this logic
	if not is_inside_tree(): return

	match NetworkManager.current_role:
		NetworkManager.Role.HUB_SERVER:
			_load_scene.call_deferred(HUB_SCENE)
		NetworkManager.Role.DUNGEON_SERVER:
			_load_scene.call_deferred(DUNGEON_SCENE)
		NetworkManager.Role.CLIENT:
			# Clients start in the Main Menu
			_load_scene.call_deferred(MENU_SCENE)

func _load_scene(path: String, username: String = "", password: String = "") -> void:
	if not is_inside_tree():
		print("[SceneManager] ERROR: SceneManager not in tree when trying to load: ", path)
		return
		
	var tree = get_tree()
	if not tree:
		return

	# Don't reload the same scene if it's already active
	if tree.current_scene and tree.current_scene.scene_file_path == path:
		print("[SceneManager] Scene already loaded: ", path)
		# Still request login if username is provided
		if username != "":
			PBHelper.request_login(username, password)
		return

	if username != "":
		pending_username = username
		pending_password = password

	print("[SceneManager] Loading scene: ", path)
	var err = tree.change_scene_to_file(path)
	if err != OK:
		printerr("[SceneManager] Failed to load scene: ", path, " Error: ", err)
		return
	
	# If we have a username, we need to request login ONCE the new scene is ready
	if pending_username != "":
		# Wait for the next frame so the new scene is the 'current_scene'
		await tree.process_frame
		print("[SceneManager] New scene ready, requesting login for: ", pending_username)
		PBHelper.request_login(pending_username, pending_password)
		pending_username = ""
		pending_password = ""

func show_loading_screen(show: bool) -> void:
	if show:
		if not loading_screen_instance:
			var scene = load(LOADING_SCREEN_PATH)
			loading_screen_instance = scene.instantiate()
			get_tree().root.add_child(loading_screen_instance)
	else:
		if loading_screen_instance:
			loading_screen_instance.queue_free()
			loading_screen_instance = null
