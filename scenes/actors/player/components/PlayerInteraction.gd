extends Node
class_name PlayerInteraction

var player: CharacterBody3D
var interact_ray: RayCast3D

func _init(_player: CharacterBody3D, _ray: RayCast3D) -> void:
	player = _player
	interact_ray = _ray

func try_interact() -> void:
	if interact_ray:
		interact_ray.force_raycast_update()
		if interact_ray.is_colliding():
			var collider = interact_ray.get_collider()
			if collider:
				var target = collider
				if not target.has_method("interact") and target.get_parent() and target.get_parent().has_method("interact"):
					target = target.get_parent()

				if target.name.contains("LootDrop"):
					player.play_general_animation.rpc("general/PickUp")
				else:
					player.play_general_animation.rpc("general/Interact")
				
				# Call the RPC on this node
				rpc_id(1, "_request_interact_rpc", player.get_path_to(collider))

@rpc("any_peer", "call_remote", "reliable")
func _request_interact_rpc(object_path: NodePath) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != player.player_id: return
	
	var target = player.get_node_or_null(object_path)
	if target:
		var dist = player.global_position.distance_to(target.global_position)
		if dist <= 5.0:
			if target.has_method("interact"):
				target.interact(player)
			elif target.get_parent() and target.get_parent().has_method("interact"):
				target.get_parent().interact(player)

@rpc("any_peer", "call_remote", "reliable")
func request_move_item(from_type: String, from_idx: int, to_type: String, to_idx: int) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != player.player_id: return
	
	print("[PlayerInteraction] Server executing move for peer: ", sender_id)
	InventoryService.move_item(player, from_type, from_idx, to_type, to_idx)
