extends Node
class_name PlayerAnimationManager

var player: CharacterBody3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

var was_on_floor: bool = true
var last_node: String = ""

func _init(_player: CharacterBody3D, _anim_player: AnimationPlayer, _anim_tree: AnimationTree) -> void:
	player = _player
	anim_player = _anim_player
	anim_tree = _anim_tree
	
	if anim_tree:
		anim_tree.active = true
		playback = anim_tree.get("parameters/playback")

func update_animations(shared_velocity: Vector3) -> void:
	if not anim_tree or not playback:
		_fallback_manual_animations(shared_velocity)
		return
	
	var current_root = playback.get_current_node()
	
	# --- ATTACK STATE RESETS ---
	if current_root == "SwordAttack":
		anim_tree.set("parameters/conditions/wants_to_sword", false)
		var combo_playback = anim_tree.get("parameters/SwordAttack/playback")
		if combo_playback:
			var current_swing = combo_playback.get_current_node()
			if current_swing != last_node:
				anim_tree.set("parameters/SwordAttack/conditions/wants_to_sword", false)
				last_node = current_swing
	elif current_root == "BowAttack":
		anim_tree.set("parameters/conditions/wants_to_bow", false)
		last_node = current_root
	elif current_root == "MagicSpell":
		anim_tree.set("parameters/conditions/wants_to_magic", false)
		last_node = current_root
	elif current_root == "Roll":
		anim_tree.set("parameters/conditions/roll", false)
		last_node = current_root
	else:
		last_node = current_root

	# --- LOCOMOTION & JUMP ---
	var horizontal_velocity = Vector2(shared_velocity.x, shared_velocity.z)
	var speed = horizontal_velocity.length()
	var is_moving = speed > 0.1
	
	var is_on_floor = player.is_on_floor()
	if "sync_is_on_floor" in player:
		is_on_floor = player.sync_is_on_floor
	
	# Top level conditions
	anim_tree.set("parameters/conditions/is_air", not is_on_floor)
	anim_tree.set("parameters/conditions/is_on_floor", is_on_floor)
	
	# Locomotion machine
	anim_tree.set("parameters/Locomotion/conditions/is_moving", is_on_floor and is_moving)
	anim_tree.set("parameters/Locomotion/conditions/is_idle", is_on_floor and not is_moving)
	
	# Jump machine
	anim_tree.set("parameters/Jump/conditions/is_on_floor", is_on_floor)
	
	# AUTOMATIC TRIGGERS
	if was_on_floor and not is_on_floor:
		playback.travel("Jump")
	
	was_on_floor = is_on_floor

func play_jump():
	if playback:
		playback.travel("Jump")

func play_roll():
	if playback:
		anim_tree.set("parameters/conditions/roll", true)
		playback.travel("Roll")

func play_attack(item_type: int):
	if not anim_tree or not playback: return
	
	match item_type:
		ItemData.Type.WEAPON: # Sword
			anim_tree.set("parameters/conditions/wants_to_sword", true)
			anim_tree.set("parameters/SwordAttack/conditions/wants_to_sword", true)
			if playback.get_current_node() == "Locomotion":
				playback.travel("SwordAttack")
				
		ItemData.Type.RANGED: # Bow
			# Reset release flag so we can Aim
			anim_tree.set("parameters/BowAttack/conditions/on_release", false)
			anim_tree.set("parameters/conditions/on_release", false)
			anim_tree.set("parameters/conditions/wants_to_bow", true)
			if playback.get_current_node() == "Locomotion":
				playback.travel("BowAttack")
			
		ItemData.Type.MAGIC: # Spell
			# Reset release flag so we can Charge
			anim_tree.set("parameters/MagicSpell/conditions/on_release", false)
			anim_tree.set("parameters/conditions/on_release", false)
			anim_tree.set("parameters/conditions/wants_to_magic", true)
			if playback.get_current_node() == "Locomotion":
				playback.travel("MagicSpell")

func stop_attack(item_type: int):
	if not anim_tree: return
	
	match item_type:
		ItemData.Type.RANGED:
			print("[DEBUG] RELEASE BOW - Setting on_release to true")
			anim_tree.set("parameters/BowAttack/conditions/on_release", true)
			anim_tree.set("parameters/conditions/on_release", true)
			anim_tree["parameters/BowAttack/conditions/on_release"] = true
			anim_tree.set("parameters/conditions/wants_to_bow", false)
			
		ItemData.Type.MAGIC:
			print("[DEBUG] RELEASE MAGIC - Setting on_release to true")
			anim_tree.set("parameters/MagicSpell/conditions/on_release", true)
			anim_tree.set("parameters/conditions/on_release", true)
			anim_tree["parameters/MagicSpell/conditions/on_release"] = true
			anim_tree.set("parameters/conditions/wants_to_magic", false)

func play_general(anim_name: String, _blend: float = 0.1):
	if playback and anim_tree:
		var state_name = anim_name.split("/")[-1]
		if state_name == "Death_A": state_name = "Death01"
		
		var root_machine = anim_tree.tree_root as AnimationNodeStateMachine
		if root_machine and root_machine.has_node(state_name):
			playback.travel(state_name)
		else:
			if anim_player and anim_player.has_animation(anim_name):
				anim_player.play(anim_name, _blend)

func play_melee_one_hand_attack():
	play_attack(ItemData.Type.WEAPON)

func is_attacking() -> bool:
	if playback:
		var current = playback.get_current_node()
		return current == "SwordAttack" or current == "BowAttack" or current == "MagicSpell" or current.to_lower().contains("attack")
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
