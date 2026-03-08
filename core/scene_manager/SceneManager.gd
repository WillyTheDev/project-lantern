extends Node

const HUB_SCENE = "res://scenes/levels/hub/Hub.tscn"
const DUNGEON_SCENE = "res://scenes/levels/dungeon/Dungeon.tscn"

const MENU_SCENE = "res://ui/MainMenu.tscn"
const LOADING_SCREEN_PATH = "res://ui/LoadingScreen.tscn"

var loading_screen_instance: Node = null

func _ready() -> void:
	# ... (keep existing _ready logic)
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

func _load_scene(path: String) -> void:
	# Don't reload the same scene if it's already active
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == path:
		print("[SceneManager] Scene already loaded: ", path)
		return

	print("[SceneManager] Loading scene: ", path)
	var err = get_tree().change_scene_to_file(path)
	if err != OK:
		printerr("[SceneManager] Failed to load scene: ", path, " Error: ", err)

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
