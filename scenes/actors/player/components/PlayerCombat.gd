extends Node
class_name PlayerCombat

var animations: PlayerAnimationManager

var player: CharacterBody3D

func _init(_player: CharacterBody3D) -> void:
	player = _player

func request_attack(damage: float, range: float) -> void:
	if not player.is_multiplayer_authority() and not NetworkService.is_server(): return
	player.play_attack_animation.rpc()
	# Call the RPC on this node
	rpc_id(1, "_perform_attack_rpc", damage, range)

@rpc("any_peer", "call_remote", "reliable")
func _perform_attack_rpc(damage: float, range: float) -> void:
	if not NetworkService.is_server() or not is_instance_valid(player): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != player.player_id: return
	
	# Cleave System: Use a sphere check in front of the player
	var space_state = player.get_world_3d().direct_space_state
	var forward = -player.global_transform.basis.z
	var attack_pos = player.global_position + (forward * (range / 2.0))
	
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = range # Large enough to catch multiple targets in front
	query.shape = sphere
	query.transform = Transform3D(Basis(), attack_pos)
	query.collision_mask = 3 # Layers 1 (Players) and 2 (Enemies)
	
	var results = space_state.intersect_shape(query)
	var hit_something = false
	
	for result in results:
		var collider = result.collider
		if collider == player: continue
		
		var target = collider
		if not target.has_method("take_damage") and target.get_parent() and target.get_parent().has_method("take_damage"):
			target = target.get_parent()
			
		if target.has_method("take_damage") and target != player:
			target.take_damage(damage)
			hit_something = true
			
			# Apply knockback
			if target.has_method("apply_knockback"):
				target.apply_knockback(player.global_position, 4.0)
	
	# Feedback for the attacker (visuals or sounds can be added here)
	if hit_something:
		pass
