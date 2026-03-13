extends Node
class_name PlayerAnimationManager

var player: CharacterBody3D
var anim_player: AnimationPlayer

func _init(_player: CharacterBody3D, _anim_player: AnimationPlayer) -> void:
	player = _player
	anim_player = _anim_player

func update_animations(shared_velocity: Vector3) -> void:
	if not anim_player: return
	
	var horizontal_velocity = Vector2(shared_velocity.x, shared_velocity.z)
	var speed_sq = horizontal_velocity.length_squared()
	
	var current = anim_player.current_animation
	var one_shots = [
		"general/Interact", 
		"general/PickUp", 
		"melee/Attack_1", 
		"melee/Attack_2", 
		"melee/Attack_3", 
		"general/Death_A", 
		"general/Spawn_Air"
	]
	
	if current in one_shots and anim_player.is_playing():
		return
	
	if not player.is_on_floor():
		if anim_player.has_animation("movement/Jump_Full_Long") and current != "movement/Jump_Full_Long":
			anim_player.play("movement/Jump_Full_Long", 0.1)
	elif speed_sq > 0.1:
		var walk_anim = "movement/Walking_A"
		if anim_player.has_animation("movement/Running_A"):
			walk_anim = "movement/Running_A"
			
		if anim_player.has_animation(walk_anim) and current != walk_anim:
			anim_player.play(walk_anim, 0.2)
	else:
		if anim_player.has_animation("general/Idle_A") and current != "general/Idle_A":
			anim_player.play("general/Idle_A", 0.3)

func play_general(anim_name: String, blend: float = 0.1):
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name, blend)
		if not "Idle_A" in anim_name:
			anim_player.queue("general/Idle_A")

func play_attack():
	if anim_player:
		var atk_name = "melee/Attack_1"
		if not anim_player.has_animation(atk_name):
			for anim in anim_player.get_animation_list():
				if "Attack" in anim:
					atk_name = anim
					break
		if anim_player.has_animation(atk_name):
			anim_player.play(atk_name, 0.1)
