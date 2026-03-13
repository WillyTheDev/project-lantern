extends Node
class_name PlayerCombat

var player: CharacterBody3D

func _init(_player: CharacterBody3D) -> void:
	player = _player

func request_attack(damage: float, range: float) -> void:
	if not player.is_multiplayer_authority(): return
	player.play_attack_animation.rpc()
	# Call the RPC on this node
	rpc_id(1, "_perform_attack_rpc", damage, range)

@rpc("any_peer", "call_remote", "reliable")
func _perform_attack_rpc(damage: float, range: float) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != player.player_id: return
	
	if player.interact_ray:
		player.interact_ray.force_raycast_update()
		if player.interact_ray.is_colliding():
			var collider = player.interact_ray.get_collider()
			if collider:
				var target = collider
				if not target.has_method("take_damage") and target.get_parent() and target.get_parent().has_method("take_damage"):
					target = target.get_parent()
				
				if target.has_method("take_damage"):
					var dist = player.global_position.distance_to(collider.global_position)
					if dist <= range + 3.0:
						target.take_damage(damage)
