extends Node
class_name PlayerAnimationManager

var player: CharacterBody3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var playback_base: AnimationNodeStateMachinePlayback
var playback_upper: AnimationNodeStateMachinePlayback
var was_on_floor: bool = true
var last_node: String = ""

func _init(_player: CharacterBody3D, _anim_player: AnimationPlayer, _anim_tree: AnimationTree) -> void:
	player = _player
	anim_player = _anim_player
	anim_tree = _anim_tree
	
	if anim_tree:
		anim_tree.active = true
		playback_base = anim_tree.get("parameters/BaseMovement/playback")
		playback_upper = anim_tree.get("parameters/UpperBody/playback")

func update_animations(shared_velocity: Vector3) -> void:
	if not anim_tree or not playback_base or not playback_upper:
		_fallback_manual_animations(shared_velocity)
		return
	
	var current_upper = playback_upper.get_current_node()
	
	# --- ATTACK STATE RESETS (UpperBody) ---
	# Remove manual Bow/Magic reset triggers entirely
	if current_upper == "SwordAttack":
		anim_tree.set("parameters/UpperBody/conditions/wants_to_sword", false)
		var combo_playback = anim_tree.get("parameters/UpperBody/SwordAttack/playback")
		if combo_playback:
			var current_swing = combo_playback.get_current_node()
			if current_swing != last_node:
				anim_tree.set("parameters/UpperBody/SwordAttack/conditions/wants_to_sword", false)
				last_node = current_swing
	elif current_upper == "Roll":
		anim_tree.set("parameters/BaseMovement/conditions/roll", false)
		anim_tree.set("parameters/UpperBody/conditions/roll", false)
		last_node = current_upper
	else:
		last_node = current_upper

	# --- LOCOMOTION & JUMP ---
	var horizontal_velocity = Vector2(shared_velocity.x, shared_velocity.z)
	
	var is_on_floor = player.is_on_floor()
	if "sync_is_on_floor" in player:
		is_on_floor = player.sync_is_on_floor
	
	# Top level conditions for both machines
	anim_tree.set("parameters/BaseMovement/conditions/is_air", not is_on_floor)
	anim_tree.set("parameters/BaseMovement/conditions/is_on_floor", is_on_floor)
	anim_tree.set("parameters/UpperBody/conditions/is_air", not is_on_floor)
	anim_tree.set("parameters/UpperBody/conditions/is_on_floor", is_on_floor)
	
	var is_blocking = player.get("is_blocking") == true
	anim_tree.set("parameters/UpperBody/conditions/is_blocking", is_blocking)
	anim_tree.set("parameters/UpperBody/conditions/not_blocking", not is_blocking)
	
	# Explicit boolean mappings for continuous aiming and shooting attacks
	var is_aiming = player.get("is_aiming") == true
	var is_shooting = player.get("is_shooting") == true
	
	var is_aiming_bow = false
	var is_aiming_magic = false
	if is_aiming and player.inventory:
		var item = player.inventory.get_active_item()
		if item:
			var data = ItemService.get_item(item.id)
			if data:
				is_aiming_bow = (data.type == ItemData.Type.RANGED)
				is_aiming_magic = (data.type == ItemData.Type.MAGIC)
	
	# Top level UpperBody
	anim_tree.set("parameters/UpperBody/conditions/is_aiming_bow", is_aiming_bow)
	anim_tree.set("parameters/UpperBody/conditions/not_is_aiming_bow", not is_aiming_bow)
	anim_tree.set("parameters/UpperBody/conditions/is_aiming_magic", is_aiming_magic)
	anim_tree.set("parameters/UpperBody/conditions/not_is_aiming_magic", not is_aiming_magic)
	anim_tree.set("parameters/UpperBody/conditions/is_shooting", is_shooting)
	anim_tree.set("parameters/UpperBody/conditions/not_is_shooting", not is_shooting)
	
	# Nested BowAttack State Machine
	anim_tree.set("parameters/UpperBody/BowAttack/conditions/is_aiming_bow", is_aiming_bow)
	anim_tree.set("parameters/UpperBody/BowAttack/conditions/not_is_aiming_bow", not is_aiming_bow)
	anim_tree.set("parameters/UpperBody/BowAttack/conditions/is_shooting", is_shooting)
	anim_tree.set("parameters/UpperBody/BowAttack/conditions/not_is_shooting", not is_shooting)
	
	# Nested MagicSpell State Machine
	anim_tree.set("parameters/UpperBody/MagicSpell/conditions/is_aiming_magic", is_aiming_magic)
	anim_tree.set("parameters/UpperBody/MagicSpell/conditions/not_is_aiming_magic", not is_aiming_magic)
	anim_tree.set("parameters/UpperBody/MagicSpell/conditions/is_shooting", is_shooting)
	anim_tree.set("parameters/UpperBody/MagicSpell/conditions/not_is_shooting", not is_shooting)
	
	# Locomotion BlendSpace1D
	# 0.0 = Idle, 0.4 = Walk, 1.0 = Sprint (based on speed = 4.5 in PlayerMovement)
	var speed_ratio: float = 0.0
	if horizontal_velocity.length_squared() > 0.01:
		var max_speed = 4.5 # Default speed from PlayerMovement
		speed_ratio = clamp(horizontal_velocity.length() / max_speed, 0.0, 1.0)
	
	# Smoothly apply the blend position so animations transition beautifully
	var current_blend: float = anim_tree.get("parameters/BaseMovement/Locomotion/blend_position") if anim_tree.get("parameters/BaseMovement/Locomotion/blend_position") != null else 0.0
	var new_blend = lerpf(current_blend, speed_ratio, 12.0 * player.get_physics_process_delta_time())
	
	anim_tree.set("parameters/BaseMovement/Locomotion/blend_position", new_blend)
	anim_tree.set("parameters/UpperBody/Locomotion/blend_position", new_blend)
	
	# Jump machine (Base & Upper)
	anim_tree.set("parameters/BaseMovement/Jump/conditions/is_on_floor", is_on_floor)
	anim_tree.set("parameters/UpperBody/Jump/conditions/is_on_floor", is_on_floor)
	
	# AUTOMATIC TRIGGERS
	if was_on_floor and not is_on_floor:
		playback_base.travel("Jump")
		playback_upper.travel("Jump")
	
	was_on_floor = is_on_floor

func play_jump():
	if playback_base:
		playback_base.travel("Jump")
	if playback_upper:
		playback_upper.travel("Jump")

func play_roll():
	if playback_base:
		anim_tree.set("parameters/BaseMovement/conditions/roll", true)
		playback_base.travel("Roll")
	if playback_upper:
		anim_tree.set("parameters/UpperBody/conditions/roll", true)
		playback_upper.travel("Roll")

func play_attack(item_type: int):
	if not anim_tree or not playback_upper: return
	
	match item_type:
		ItemData.Type.WEAPON: # Sword
			anim_tree.set("parameters/UpperBody/conditions/wants_to_sword", true)
			anim_tree.set("parameters/UpperBody/SwordAttack/conditions/wants_to_sword", true)
			if playback_upper.get_current_node() == "Locomotion":
				playback_upper.travel("SwordAttack")
			
		ItemData.Type.RANGED: # Bow
			# Reset release flag so we can Aim
			anim_tree.set("parameters/UpperBody/BowAttack/conditions/on_release", false)
			anim_tree.set("parameters/UpperBody/conditions/on_release", false)
			anim_tree.set("parameters/UpperBody/conditions/wants_to_bow", true)
			if playback_upper.get_current_node() == "Locomotion":
				playback_upper.travel("BowAttack")
			
		ItemData.Type.MAGIC: # Spell
			# Reset release flag so we can Charge
			anim_tree.set("parameters/UpperBody/MagicSpell/conditions/on_release", false)
			anim_tree.set("parameters/UpperBody/conditions/on_release", false)
			anim_tree.set("parameters/UpperBody/conditions/wants_to_magic", true)
			if playback_upper.get_current_node() == "Locomotion":
				playback_upper.travel("MagicSpell")

func stop_attack(_item_type: int):
	# Removed because Bow/Magic are natively driven by player parameters and don't need manual stops
	pass

func play_general(anim_name: String, _blend: float = 0.1):
	if playback_base and playback_upper and anim_tree:
		var state_name = anim_name.split("/")[-1]
		if state_name == "Death_A": state_name = "Death01"
		
		
		var base_sm = anim_tree.tree_root.get_node("BaseMovement") as AnimationNodeStateMachine
		if base_sm and base_sm.has_node(state_name):
			playback_base.travel(state_name)
			
		var upper_sm = anim_tree.tree_root.get_node("UpperBody") as AnimationNodeStateMachine
		if upper_sm and upper_sm.has_node(state_name):
			playback_upper.travel(state_name)

func play_melee_one_hand_attack():
	play_attack(ItemData.Type.WEAPON)

func is_attacking() -> bool:
	if player and (player.get("is_aiming") or player.get("is_shooting")):
		return true
	if playback_upper:
		var current = playback_upper.get_current_node()
		return current == "SwordAttack" or current.to_lower().contains("attack")
	return false

func _fallback_manual_animations(shared_velocity: Vector3) -> void:
	var horizontal_velocity = Vector2(shared_velocity.x, shared_velocity.z)
	var speed_sq = horizontal_velocity.length_squared()
	var current = anim_player.current_animation
	
	var is_on_floor = player.is_on_floor()
	if "sync_is_on_floor" in player:
		is_on_floor = player.sync_is_on_floor
		
	if not is_on_floor:
		if was_on_floor:
			if anim_player.has_animation("Jump_Start"):
				anim_player.play("Jump_Start", 0.1)
				anim_player.queue("Jump")
		elif current != "Jump" and current != "Jump_Start":
			if anim_player.has_animation("Jump"):
				anim_player.play("Jump", 0.2)
	else:
		if not was_on_floor:
			if anim_player.has_animation("Jump_Land"):
				anim_player.play("Jump_Land", 0.05)
				anim_player.queue("Sprint" if speed_sq > 0.1 else "Idle")
		elif speed_sq > 0.1:
			var walk_anim = "Sprint" if anim_player.has_animation("Sprint") else "movement/Walking_A"
			if anim_player.has_animation(walk_anim) and current != walk_anim:
				anim_player.play(walk_anim, 0.2)
		else:
			if anim_player.has_animation("Idle") and current != "Idle":
				anim_player.play("Idle", 0.3)
	
	was_on_floor = is_on_floor
