extends CharacterBody3D

# --- COMPONENTS ---
var movement: PlayerMovement
var combat: PlayerCombat
var interaction: PlayerInteraction
var voip: PlayerVOIP
var animations: PlayerAnimationManager

@export var interpolation_speed = 15.0
@export var sync_position: Vector3
@export var sync_rotation: float
@export var sync_pivot_rotation: float 

@onready var anim_player: AnimationPlayer = $Model/MainAnimationPlayer

@export var player_id: int = 1
@export var player_name: String = ""
@export var display_name: String = "": set = _set_display_name
@export var name_color: Color = Color.WHITE: set = _set_name_color

# Vitality (REQUIRED by MultiplayerSynchronizer)
@export var max_health: float = 100.0
@export var current_health: float = 100.0:
	set(value):
		current_health = value
		if is_multiplayer_authority():
			InventoryManager.player_stats.current_health = value
		
		if is_inside_tree():
			_update_health_ui()
			# Only the server should trigger the death sequence
			if multiplayer.is_server() and current_health <= 0 and not is_dead:
				_on_death()

@export var shared_velocity: Vector3 = Vector3.ZERO
var interact_ray: RayCast3D
var is_dead: bool = false

const MOUSE_SENSIBILITY = 0.002

@export var active_slot_index: int = 0:
	set(v):
		active_slot_index = v
		if is_inside_tree():
			refresh_held_item()

# Server-only storage for remote player inventories to allow item spawning
var server_inventory: InventoryData = null

func _enter_tree() -> void:
	set_multiplayer_authority(player_id)

func _ready() -> void:
	scale = Vector3(0.3, 0.3, 0.3)
	add_to_group("players")
	$CameraPivot/SpringArm3D.add_excluded_object(get_rid())

	# Raycast Setup
	interact_ray = %RayCast3D
	interact_ray.enabled = true
	interact_ray.add_exception(self)

	# Initialize Components
	movement = PlayerMovement.new(self)
	combat = PlayerCombat.new(self)
	combat.name = "Combat"
	interaction = PlayerInteraction.new(self, interact_ray)
	interaction.name = "Interaction"
	voip = PlayerVOIP.new(self)
	animations = PlayerAnimationManager.new(self, anim_player)
	
	add_child(combat) # For RPCs
	add_child(interaction) # For RPCs

	if is_multiplayer_authority():
		_setup_local_player()
	else:
		_setup_remote_player()
	
	_update_nametag()

func _setup_local_player() -> void:
	var camera = $CameraPivot/SpringArm3D/Camera3D
	camera.make_current()
	SceneManager.show_loading_screen(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	display_name = PersistenceManager.current_player_name
	
	var inv_ui = get_node_or_null("GUILayer/InventoryUI")
	if inv_ui:
		inv_ui.is_local_authority = true
		inv_ui.visible = true 
	
	InventoryManager.active_slot_changed.connect(refresh_held_item)
	InventoryManager.stats_updated.connect(_on_stats_updated)
	
	voip.setup_local()
	_on_stats_updated(InventoryManager.player_stats)
	
	# Initial refresh
	await get_tree().create_timer(0.2).timeout
	refresh_held_item()

func _setup_remote_player() -> void:
	$CameraPivot/SpringArm3D/Camera3D.current = false
	voip.setup_remote()

func refresh_held_item(_index: int = -1) -> void:
	if not is_inside_tree(): return
	var hand = get_node_or_null("Model/%HandPoint")
	if not hand: return
		
	# Immediate removal of old children to prevent name conflicts
	for child in hand.get_children():
		child.name = "ToBeRemoved" # Rename to avoid conflict
		hand.remove_child(child)
		child.queue_free()
	
	# Wait one frame for engine to settle
	await get_tree().process_frame
	if not is_inside_tree(): return

	var item = null
	if is_multiplayer_authority():
		item = InventoryManager.get_active_item()
	elif multiplayer.is_server() and server_inventory:
		server_inventory.active_hotbar_index = active_slot_index
		item = server_inventory.get_active_item()
	
	if not item: return
	
	var data = ItemDB.get_item(item.id)
	if data and data.item_scene:
		var instance = data.item_scene.instantiate()
		# Use a constant name for the held item to ensure deterministic paths for RPCs
		instance.name = "HeldItem"
		hand.add_child(instance)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx = event.keycode - KEY_1
			InventoryManager.set_active_slot(idx)
			active_slot_index = idx # Triggers sync and local refresh
		elif event.keycode == KEY_0:
			InventoryManager.set_active_slot(9)
			active_slot_index = 9

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSIBILITY)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_settings_menu()

	if event.is_action_pressed("interact"):
		interaction.try_interact()
		
	if event.is_action_pressed("use_item"):
		_use_held_item()

func _use_held_item() -> void:
	var item_stack = InventoryManager.get_active_item()
	if not item_stack: return
	
	var data = ItemDB.get_item(item_stack.id)
	if data:
		var anim_name = data.use_animation
		if not anim_name.contains("/"): anim_name = "general/" + anim_name
		play_general_animation.rpc(anim_name)

	var hand = get_node_or_null("Model/%HandPoint")
	var held_item = hand.get_child(0) if hand and hand.get_child_count() > 0 else null
	if held_item and held_item.has_method("use"):
		held_item.use()

@rpc("any_peer", "call_local", "reliable")
func play_general_animation(anim_name: String, blend: float = 0.1):
	animations.play_general(anim_name, blend)

@rpc("any_peer", "call_local", "reliable")
func play_attack_animation():
	animations.play_attack()

func _toggle_settings_menu() -> void:
	var settings_scene = preload("res://ui/SettingsMenu.tscn")
	var existing_menu = get_tree().root.get_node_or_null("SettingsMenu")
	
	if existing_menu:
		existing_menu.queue_free()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		var menu = settings_scene.instantiate()
		menu.name = "SettingsMenu"
		get_tree().root.add_child(menu)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

var last_synced_slot: int = -1

func _physics_process(delta: float) -> void:
	# Server-side detection of slot changes (since setters aren't triggered by Synchronizer)
	if multiplayer.is_server() and active_slot_index != last_synced_slot:
		last_synced_slot = active_slot_index
		refresh_held_item()

	if is_dead:
		if anim_player and anim_player.current_animation != "general/Death_A":
			anim_player.play("general/Death_A")
		return

	$VoiceIndicator.visible = voip.process_voip(delta)

	if is_multiplayer_authority():
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		shared_velocity = movement.handle_movement(delta, input_dir)
		velocity = shared_velocity
		move_and_slide()
		
		if position.y < -20: sync_respawn.rpc()
			
		shared_velocity = velocity
		sync_position = global_position
		sync_rotation = rotation.y
		sync_pivot_rotation = $CameraPivot.rotation.x
	else:
		velocity = shared_velocity
		move_and_slide()
		rotation.y = sync_rotation
		$CameraPivot.rotation.x = sync_pivot_rotation
		
		if global_position.distance_to(sync_position) > 2.0:
			global_position = sync_position
		else:
			global_position = global_position.lerp(sync_position, 10 * delta)
			
	animations.update_animations(shared_velocity)

@rpc("any_peer", "call_local", "reliable")
func sync_respawn():
	is_dead = false
	last_synced_slot = -1
	play_general_animation("general/Spawn_Air")
	var spawn_node = get_parent().find_child("SpawnPoint")
	if spawn_node:
		global_position = spawn_node.global_position
		velocity = Vector3.ZERO
		shared_velocity = Vector3.ZERO
		force_update_transform()

func _update_nametag() -> void:
	if not is_inside_tree(): return
	if has_node("NameTag"):
		var nametag = $NameTag
		nametag.text = display_name if display_name != "" else "Player"
		nametag.modulate = name_color
		nametag.visible = not is_multiplayer_authority()

func _set_display_name(v): display_name = v; _update_nametag()
func _set_name_color(v): name_color = v; _update_nametag()

# --- COMBAT ---

func request_attack(damage: float, range: float) -> void:
	combat.request_attack(damage, range)

func take_damage(amount: float) -> void:
	if not multiplayer.is_server(): return
	_apply_damage_rpc.rpc_id(player_id, amount)

@rpc("any_peer", "call_local", "reliable")
func _apply_damage_rpc(amount: float) -> void:
	if multiplayer.get_remote_sender_id() != 1 and not multiplayer.is_server(): return
	current_health -= amount

func _on_stats_updated(stats: PlayerStats) -> void:
	if is_multiplayer_authority():
		max_health = stats.max_health
		# Keep current_health in sync with stats resource for local UI
		if current_health != stats.current_health:
			current_health = stats.current_health
	
	if multiplayer.is_server() and current_health <= 0:
		_on_death()

func _on_death() -> void:
	if not multiplayer.is_server(): return
	if is_dead: return
	is_dead = true
	
	play_general_animation.rpc("general/Death_A")
	await get_tree().create_timer(1.5).timeout
	if NetworkManager.current_role == NetworkManager.Role.DUNGEON_SERVER:
		_trigger_extraction_fail()
	else:
		sync_respawn.rpc()
		current_health = max_health

func _trigger_extraction_fail() -> void:
	var portal = get_tree().root.find_child("Portal", true, false)
	if portal and portal.has_method("_on_body_entered"):
		portal._on_body_entered(self)

func _update_health_ui() -> void:
	var health_bar = %HealthBar if has_node("%HealthBar") else null
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
