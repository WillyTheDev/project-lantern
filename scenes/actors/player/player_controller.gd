extends CharacterBody3D
class_name PlayerController

# --- COMPONENTS ---
var movement: PlayerMovement
var combat: PlayerCombat
var interaction: PlayerInteraction
var animations: PlayerAnimationManager
var voip: PlayerVOIP

# --- NETWORK STATE ---
@export var sync_position: Vector3
@export var sync_rotation: float
@export var sync_camera_rotation_y: float
@export var sync_pivot_rotation: float 
@export var sync_is_on_floor: bool = true

@onready var anim_player: AnimationPlayer = $Model/MainAnimationPlayer
@onready var anim_tree: AnimationTree = $Model/AnimationTree

@export var player_id: int = 1
@export var player_name: String = ""

# --- DATA OWNERSHIP ---
@export var stats: PlayerStatsData = PlayerStatsData.new()
@export var inventory: InventoryData = InventoryData.new()
@export var stash: StashData = StashData.new()

@export var display_name: String = "": 
	set(v): 
		display_name = v
		_update_nametag()
@export var name_color: Color = Color.WHITE: 
	set(v): 
		name_color = v
		_update_nametag()

# Vitality
@export var max_health: float = 100.0
@export var current_health: float = 100.0:
	set(value):
		current_health = value
		# Sync local stats resource for UI (both on server and client when synced)
		if stats:
			stats.current_health = value
		
		if is_inside_tree():
			_update_health_ui()
			# IMPORTANT: Only the server should trigger the death sequence
			if NetworkService.is_server() and current_health <= 0 and not is_dead:
				_on_death()

@export var shared_velocity: Vector3 = Vector3.ZERO
@export var is_rolling: bool = false
@export var is_blocking: bool = false
var _was_blocking_local: bool = false
@export var is_aiming: bool = false
var _was_aiming_local: bool = false
@export var is_shooting: bool = false
var _was_shooting_local: bool = false
var attack_cooldown: float = 0.0
var interact_ray: RayCast3D
var is_dead: bool = false
var knockback_velocity: Vector3 = Vector3.ZERO

const MOUSE_SENSIBILITY = 0.002

## The cooldown duration (in seconds) applied after firing a ranged or magic weapon.
## This prevents spamming and syncs redrawing with the weapon's animation pacing.
const RANGED_ATTACK_COOLDOWN: float = 1.0

@export var active_slot_index: int = 0:
	set(v):
		if active_slot_index != v:
			is_aiming = false
			_was_aiming_local = false
			is_blocking = false
			_was_blocking_local = false
			
			active_slot_index = v
			if inventory:
				inventory.set_active_slot(v) # Triggers signals for UI
			if is_inside_tree():
				refresh_held_item()

@export var use_item_state: bool = false:
	set(v):
		if use_item_state != v:
			use_item_state = v
			_sync_held_item_state()

var _current_held_item_node: Node3D = null
var _offhand_item_node: Node3D = null

@rpc("any_peer", "call_remote", "reliable")
func sync_inventory_to_clients(inventory_data: Dictionary, stash_data: Dictionary) -> void:
	# Only allow the server to push these updates
	if multiplayer.get_remote_sender_id() != 1: return
	
	# This is called on all clients to synchronize remote player nodes
	# We don't want to override our own local data if we are the authority
	if is_multiplayer_authority(): return
	
	print("[Player] Remote player sync for: ", player_name)
	inventory.load_from_dict(inventory_data)
	stash.load_from_dict(stash_data)
	refresh_held_item()

func _enter_tree() -> void:
	set_multiplayer_authority(player_id)
	if has_node("StateSynchronizer"):
		$StateSynchronizer.set_multiplayer_authority(1)

func _exit_tree() -> void:
	if NetworkService.is_server():
		print("[Player] Peer ", player_id, " leaving scene. Performing final sync for: ", player_name)
		InventoryService._sync_and_emit(self)

func _ready() -> void:
	# Explicitly initialize slots for new objects
	inventory._initialize_slots()
	stash._initialize_slots()
	
	scale = Vector3(0.3, 0.3, 0.3)
	add_to_group("players")
	$CameraPivot/SpringArm3D.add_excluded_object(get_rid())

	# Raycast Setup
	interact_ray = %RayCast3D
	interact_ray.enabled = true
	interact_ray.add_exception(self)

	# Initialize Components
	movement = PlayerMovement.new(self)
	movement.name = "Movement"
	add_child(movement)
	
	combat = PlayerCombat.new(self)
	combat.name = "Combat"
	add_child(combat)
	
	interaction = PlayerInteraction.new(self, interact_ray)
	interaction.name = "Interaction"
	add_child(interaction)
	
	voip = PlayerVOIP.new(self)
	voip.name = "VOIP"
	add_child(voip)
	
	animations = PlayerAnimationManager.new(self, anim_player, anim_tree)
	animations.name = "Animations"
	add_child(animations)

	if is_multiplayer_authority():
		_setup_local_player()
	else:
		_setup_remote_player()
	
	# Initial held item refresh
	refresh_held_item()
	
	_update_nametag()
	
	# Small delay to ensure networked data has arrived for remote players
	if not is_multiplayer_authority():
		get_tree().create_timer(0.5).timeout.connect(_update_nametag)

func _setup_local_player() -> void:
	var camera = $CameraPivot/SpringArm3D/Camera3D
	camera.make_current()
	SceneService.show_loading_screen(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	display_name = PocketBaseRESTManager.current_player_name
	
	var inv_ui = get_node_or_null("GUILayer/InventoryUI")
	if inv_ui:
		inv_ui.is_local_authority = true
		inv_ui.visible = true 
		inv_ui.initialize_for_player(self) # Bind UI to THIS player
	
	inventory.active_slot_changed.connect(refresh_held_item)
	inventory.inventory_updated.connect(_on_inventory_updated)
	stats.stats_changed.connect(_on_stats_updated)
	
	voip.setup_local()
	_on_stats_updated()
	
	# Initial refresh
	await get_tree().create_timer(0.2).timeout
	refresh_held_item()
	
	# Handshake: Request inventory from server once we are fully ready
	if not NetworkService.is_server():
		print("[Player] Requesting initial inventory sync from server...")
		server_request_inventory_sync.rpc_id(1)

func _setup_remote_player() -> void:
	$CameraPivot/SpringArm3D/Camera3D.current = false
	voip.setup_remote()
	
	# Hide UI for remote players
	var gui = get_node_or_null("GUILayer")
	if gui: gui.visible = false

@rpc("any_peer", "call_remote", "reliable")
func server_request_inventory_sync() -> void:
	if not NetworkService.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == player_id:
		print("[Player] Peer ", sender_id, " requested inventory sync. Sending...")
		# Use the service to broadcast the current state
		InventoryService._sync_and_emit(self)

@rpc("any_peer", "call_remote", "reliable")
func server_set_blocking_rpc(state: bool) -> void:
	if not NetworkService.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != player_id: return
	
	is_blocking = state
	sync_is_blocking_rpc.rpc(is_blocking)

@rpc("any_peer", "call_local", "reliable")
func sync_is_blocking_rpc(state: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1 and not NetworkService.is_server(): return
	is_blocking = state

@rpc("any_peer", "call_remote", "reliable")
func server_set_aiming_rpc(state: bool) -> void:
	if not NetworkService.is_server(): return
	if multiplayer.get_remote_sender_id() != player_id: return
	is_aiming = state
	sync_is_aiming_rpc.rpc(is_aiming)

@rpc("any_peer", "call_local", "reliable")
func sync_is_aiming_rpc(state: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1 and not NetworkService.is_server(): return
	is_aiming = state

@rpc("any_peer", "call_remote", "reliable")
func server_set_shooting_rpc(state: bool) -> void:
	if not NetworkService.is_server(): return
	if multiplayer.get_remote_sender_id() != player_id: return
	is_shooting = state
	sync_is_shooting_rpc.rpc(is_shooting)

@rpc("any_peer", "call_local", "reliable")
func sync_is_shooting_rpc(state: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1 and not NetworkService.is_server(): return
	is_shooting = state

func _sync_held_item_state() -> void:
	if is_instance_valid(_current_held_item_node):
		if _current_held_item_node.has_method("sync_state"):
			_current_held_item_node.sync_state(use_item_state)
	if is_instance_valid(_offhand_item_node):
		if _offhand_item_node.has_method("sync_state"):
			_offhand_item_node.sync_state(use_item_state)

func _spawn_visual_item(data: ItemData) -> Node3D:
	var instance = data.item_scene.instantiate()
	instance.name = "HeldItem_" + data.id
	var bone_name = data.get("attachment_bone") if "attachment_bone" in data and data.attachment_bone != "" else "SwordBoneAttachment"
	var skeleton = get_node_or_null("Model/rig_deform/GeneralSkeleton")
	if skeleton:
		var target_bone = skeleton.get_node_or_null(bone_name)
		if target_bone:
			if target_bone.get_child_count() > 0 and target_bone.get_child(0) is Marker3D:
				target_bone.get_child(0).add_child(instance)
			else:
				target_bone.add_child(instance)
			return instance
	instance.queue_free()
	return null

func _on_inventory_updated() -> void:
	refresh_held_item()

var _equip_sequence: int = 0

func refresh_held_item(_index: int = -1) -> void:
	if not is_inside_tree(): return
		
	_equip_sequence += 1
	var current_sequence = _equip_sequence
	
	if is_instance_valid(_current_held_item_node):
		_current_held_item_node.name = "ToBeRemoved"
		var parent = _current_held_item_node.get_parent()
		if parent: parent.remove_child(_current_held_item_node)
		_current_held_item_node.queue_free()
		_current_held_item_node = null
		
	if is_instance_valid(_offhand_item_node):
		_offhand_item_node.name = "ToBeRemovedOffhand"
		var p2 = _offhand_item_node.get_parent()
		if p2: p2.remove_child(_offhand_item_node)
		_offhand_item_node.queue_free()
		_offhand_item_node = null
	
	await get_tree().process_frame
	if not is_inside_tree(): return
	if current_sequence != _equip_sequence: return

	var item = null
	if inventory:
		inventory.active_hotbar_index = active_slot_index
		item = inventory.get_active_item()
	
	var main_data = null
	if item:
		main_data = ItemService.get_item(item.id)
		if main_data and main_data.item_scene:
			_current_held_item_node = _spawn_visual_item(main_data)
			_sync_held_item_state()

	if inventory and inventory.armor.size() > 4:
		var offhand = inventory.armor[4]
		if offhand:
			var offdata = ItemService.get_item(offhand.id)
			if offdata and offdata.item_scene:
				if not main_data or main_data.get("hand_type") != ItemData.HandType.TWO_HANDED:
					_offhand_item_node = _spawn_visual_item(offdata)
					if _offhand_item_node and _offhand_item_node.has_method("sync_state"):
						_offhand_item_node.sync_state(use_item_state)

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx = event.keycode - KEY_1
			request_slot_change(idx)
		elif event.keycode == KEY_0:
			request_slot_change(9)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Horizontal rotation (Yaw) - Apply to the CameraPivot
		$CameraPivot.rotate_y(-event.relative.x * MOUSE_SENSIBILITY)
		
		# Vertical rotation (Pitch) - Apply to the SpringArm3D to avoid gimbal lock
		var spring_arm = $CameraPivot/SpringArm3D
		if spring_arm:
			spring_arm.rotation.x = clamp(spring_arm.rotation.x - event.relative.y * MOUSE_SENSIBILITY, -1.2, 1.2)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_settings_menu()

	if event.is_action_pressed("interact"):
		interaction.try_interact()
		
	if event.is_action_pressed("use_item"):
		var handled_by_aim = false
		if inventory:
			var item = inventory.get_active_item()
			if item:
				var data = ItemService.get_item(item.id)
				if data:
					# Ranged and Magic trigger shooting logic
					if data.type == ItemData.Type.RANGED or data.type == ItemData.Type.MAGIC:
						handled_by_aim = true
						if is_aiming and attack_cooldown <= 0:
							combat.request_shoot(item.id)
							attack_cooldown = RANGED_ATTACK_COOLDOWN
		
		# Generic item use (Sword, consumables, lantern, etc.)
		if not handled_by_aim and is_multiplayer_authority():
			server_request_use_item_rpc.rpc_id(1)

func request_slot_change(index: int) -> void:
	# Client-side request to switch slots
	if is_multiplayer_authority():
		server_request_slot_change_rpc.rpc_id(1, index)

@rpc("any_peer", "call_remote", "reliable")
func server_request_slot_change_rpc(index: int) -> void:
	if not NetworkService.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != player_id: return
	
	# Validation
	if index >= 0 and index < 10:
		# Force stop any current animation for the OLD item before switching to the new one!
		if inventory:
			var item_stack = inventory.get_active_item()
			if item_stack:
				var data = ItemService.get_item(item_stack.id)
				if data:
					stop_attack_animation.rpc(data.type)
					
		active_slot_index = index
		# Reset use_item_state when changing slots
		use_item_state = false

@rpc("any_peer", "call_remote", "reliable")
func server_request_use_item_rpc() -> void:
	if not NetworkService.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != player_id: return
	
	# Toggle state for continuous items (like lantern)
	use_item_state = !use_item_state
	
	# Play animation
	var item_stack = inventory.get_active_item()
	if item_stack:
		var data = ItemService.get_item(item_stack.id)
		if data:
			if data.type == ItemData.Type.WEAPON:
				play_attack_animation.rpc(data.type)
			elif data.type != ItemData.Type.RANGED and data.type != ItemData.Type.MAGIC:
				var anim_name = data.use_animation
				play_general_animation.rpc(anim_name)
	
	# Specific item logic
	if item_stack:
		var data = ItemService.get_item(item_stack.id)
		if data and data.type == ItemData.Type.CONSUMABLE:
			# Healing Potion
			if data.stats.has("heal_amount"):
				current_health += data.stats["heal_amount"]
				current_health = min(current_health, max_health)
				print("[Player] Healed for: ", data.stats["heal_amount"], " New Health: ", current_health)
			
			# Consume item
			item_stack.quantity -= 1
			if item_stack.quantity <= 0:
				inventory.hotbar[active_slot_index] = null
			
			# Force inventory sync to PocketBase and Clients
			InventoryService._sync_and_emit(self)

	if is_instance_valid(_current_held_item_node) and _current_held_item_node.has_method("use"):
		_current_held_item_node.use()

func _stop_use_held_item() -> void:
	if is_multiplayer_authority():
		if inventory:
			var item_stack = inventory.get_active_item()
			if item_stack:
				var data = ItemService.get_item(item_stack.id)
				if data and (data.type == ItemData.Type.RANGED or data.type == ItemData.Type.MAGIC):
					if is_aiming: # If they let go of Right-Click early, it safely cancels the shot!
						combat.request_shoot(item_stack.id)

@rpc("any_peer", "call_local", "reliable")
func play_general_animation(anim_name: String, blend: float = 0.1):
	animations.play_general(anim_name, blend)

@rpc("any_peer", "call_local", "reliable")
func play_attack_animation(item_type: int = ItemData.Type.WEAPON):
	animations.play_attack(item_type)

@rpc("any_peer", "call_local", "reliable")
func stop_attack_animation(item_type: int):
	animations.stop_attack(item_type)

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
	# Decay knockback
	if knockback_velocity.length() > 0.05:
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, 12 * delta)
		if is_on_wall():
			knockback_velocity = Vector3.ZERO
	else:
		knockback_velocity = Vector3.ZERO

	# State handling
	if NetworkService.is_server() and active_slot_index != last_synced_slot:
		last_synced_slot = active_slot_index
		refresh_held_item()

	if is_dead:
		if anim_player and anim_player.current_animation != "Death01":
			anim_player.play("Death01")
		return

	$VoiceIndicator.visible = voip.process_voip(delta)

	if is_multiplayer_authority():
		rotation = Vector3.ZERO
		
		var wants_to_shoot = false
		if attack_cooldown > 0:
			attack_cooldown -= delta
			wants_to_shoot = true
			
		if wants_to_shoot != _was_shooting_local:
			_was_shooting_local = wants_to_shoot
			is_shooting = wants_to_shoot
			server_set_shooting_rpc.rpc_id(1, wants_to_shoot)
		
		var wants_to_aim = false
		var wants_to_block = false
		var has_two_handed = false
		
		if inventory:
			var item = inventory.get_active_item()
			if item:
				var data = ItemService.get_item(item.id)
				if data:
					if data.get("hand_type") == ItemData.HandType.TWO_HANDED:
						has_two_handed = true
					if Input.is_action_pressed("right_click"):
						if data.type == ItemData.Type.RANGED or data.type == ItemData.Type.MAGIC:
							wants_to_aim = true
						elif data.type == ItemData.Type.WEAPON:
							wants_to_block = true
							
		# Check Offhand for blocking (if not aiming a bow and not hiding offhand)
		if Input.is_action_pressed("right_click") and not wants_to_aim and not has_two_handed:
			if inventory and inventory.armor.size() > 4:
				var offhand = inventory.armor[4]
				if offhand:
					var offdata = ItemService.get_item(offhand.id)
					if offdata and offdata.armor_slot == ItemData.ArmorSlot.OFFHAND:
						wants_to_block = true
						
		if wants_to_block != _was_blocking_local:
			_was_blocking_local = wants_to_block
			server_set_blocking_rpc.rpc_id(1, wants_to_block)
			is_blocking = wants_to_block

		if wants_to_aim != _was_aiming_local:
			_was_aiming_local = wants_to_aim
			is_aiming = wants_to_aim
			server_set_aiming_rpc.rpc_id(1, wants_to_aim)

		var cam = $CameraPivot/SpringArm3D/Camera3D
		if cam and "target_h_offset" in cam:
			cam.target_h_offset = 0.6 if is_aiming else 0.0
			
		var crosshair = get_node_or_null("%Crosshair")
		if crosshair:
			crosshair.visible = is_aiming
		
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		shared_velocity = movement.handle_movement(delta, input_dir)
		velocity = shared_velocity + knockback_velocity
		move_and_slide()
		
		if position.y < -20: sync_respawn.rpc()
			
		shared_velocity = velocity
		sync_position = global_position
		sync_is_on_floor = is_on_floor()
		sync_rotation = $Model.rotation.y
		sync_camera_rotation_y = $CameraPivot.rotation.y
		var spring_arm = $CameraPivot/SpringArm3D
		if spring_arm:
			sync_pivot_rotation = spring_arm.rotation.x
	else:
		rotation = Vector3.ZERO
		$Model.rotation.y = lerp_angle($Model.rotation.y, sync_rotation, 10 * delta)
		$CameraPivot.rotation.y = sync_camera_rotation_y
		var spring_arm = $CameraPivot/SpringArm3D
		if spring_arm:
			spring_arm.rotation.x = sync_pivot_rotation
		
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
	
	var spawn_node = get_tree().current_scene.find_child("SpawnPoint", true, false)
	
	if spawn_node:
		global_position = spawn_node.global_position
		velocity = Vector3.ZERO
		shared_velocity = Vector3.ZERO
		force_update_transform()
	else:
		global_position = Vector3.ZERO
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

# --- COMBAT ---

func request_attack(damage: float, range: float) -> void:
	combat.request_attack(damage, range)

func take_damage(amount: float) -> void:
	if not NetworkService.is_server(): return
	if is_rolling: return # Invulnerable during roll
	
	if is_blocking:
		amount *= 0.25 # Built-in 75% damage block mitigation!
	
	# DIRECT modification on server.
	current_health -= amount
	# Trigger visual effects on all clients
	_play_damage_fx_rpc.rpc(amount)

func apply_knockback(source_position: Vector3, force: float) -> void:
	if not NetworkService.is_server(): return
	_apply_knockback_rpc.rpc(source_position, force)

@rpc("any_peer", "call_local", "reliable")
func _apply_knockback_rpc(source_position: Vector3, force: float) -> void:
	if multiplayer.get_remote_sender_id() != 1 and not NetworkService.is_server(): return
	
	var dir = (global_position - source_position).normalized()
	if dir == Vector3.ZERO: dir = Vector3.UP
	dir.y = 0
	
	knockback_velocity += dir * force
	
	if is_multiplayer_authority():
		var collision = move_and_collide(dir * 0.1)
		if collision:
			knockback_velocity = Vector3.ZERO

var _damage_fx_cooldown: float = 0.0

@rpc("any_peer", "call_local", "reliable")
func _play_damage_fx_rpc(amount: float) -> void:
	# This RPC is now purely visual feedback
	if multiplayer.get_remote_sender_id() != 1 and not NetworkService.is_server(): return
	
	var now = Time.get_ticks_msec() / 1000.0
	if now > _damage_fx_cooldown:
		_damage_fx_cooldown = now + 0.2
		var model = $Model
		if model:
			var base_scale = model.scale
			var tween = create_tween()
			tween.tween_property(model, "scale", Vector3(base_scale.x * 1.1, base_scale.y * 0.9, base_scale.z * 1.1), 0.05)
			tween.tween_property(model, "scale", base_scale, 0.1)
	
	if is_multiplayer_authority():
		var cam = $CameraPivot/SpringArm3D/Camera3D
		if cam and cam.has_method("shake"):
			cam.shake(0.05, 0.1)

func _on_stats_updated() -> void:
	max_health = stats.max_health
	# Server should ensure current_health matches stats on first load
	if NetworkService.is_server() and current_health != stats.current_health:
		current_health = stats.current_health

func _on_death() -> void:
	if not NetworkService.is_server(): return
	if is_dead: return
	is_dead = true
	
	print("[Player] Player died: ", player_name)
	# InventoryService now handles the logic for a specific player's data
	InventoryService.handle_death_for_player(self)
	
	play_general_animation.rpc("Death01")
	await get_tree().create_timer(1.5).timeout
	if NetworkService.current_role == NetworkService.Role.DUNGEON_SERVER:
		_trigger_extraction_fail()
	else:
		sync_respawn.rpc()
		current_health = max_health

func _trigger_extraction_fail() -> void:
	var portal = get_tree().root.find_child("Portal", true, false)
	if portal and portal.has_method("_on_body_entered"):
		portal._on_body_entered(self)

func _update_health_ui() -> void:
	# Only show the HUD health bar for the local player
	if not is_multiplayer_authority(): return
	
	var health_bar = %HealthBar if has_node("%HealthBar") else null
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
