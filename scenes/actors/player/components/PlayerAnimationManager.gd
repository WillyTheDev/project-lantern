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
	
	# --- REACTIVE COMBO LOGIC ---
	# This part resets the 'wants_to_attack' flag inside the AnimationTree
	var current_root = playback.get_current_node()
	if current_root == "SwordAttack":
		var combo_playback = anim_tree.get("parameters/SwordAttack/playback")
		if combo_playback:
			var current_swing = combo_playback.get_current_node()
			if current_swing != last_node:
				# Reset the condition so the player has to click again for the next part
				anim_tree.set("parameters/SwordAttack/conditions/wants_to_attack", false)
				last_node = current_swing
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
	
	# Locomotion machine (inside)
	anim_tree.set("parameters/Locomotion/conditions/is_moving", is_on_floor and is_moving)
	anim_tree.set("parameters/Locomotion/conditions/is_idle", is_on_floor and not is_moving)
	
	# Jump machine (inside)
	anim_tree.set("parameters/Jump/conditions/is_on_floor", is_on_floor)
	
	# AUTOMATIC FALL TRIGGER
	if was_on_floor and not is_on_floor:
		playback.travel("Jump")
	
	was_on_floor = is_on_floor

func play_jump():
	if playback:
		playback.travel("Jump")

func play_roll():
	if playback:
		playback.travel("Roll")

func play_attack():
	if not anim_tree or not playback: return
	
	# Simply set the condition. The AnimationTree transitions will use this!
	anim_tree.set("parameters/SwordAttack/conditions/wants_to_attack", true)
	
	# If we aren't in the attack state machine yet, enter it.
	if playback.get_current_node() != "SwordAttack":
		playback.travel("SwordAttack")

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
	play_attack()

func is_attacking() -> bool:
	if playback:
		var current = playback.get_current_node()
		return current == "SwordAttack"
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
