extends Node
class_name PlayerCombat

var animations: PlayerAnimationManager

var player: CharacterBody3D

func _init(_player: CharacterBody3D) -> void:
	player = _player

## Client-side request to perform an attack.
## Validates authority, triggers local animations, and forwards the request to the server via RPC.
## 
## @param damage: The base damage value of the current weapon or attack.
## @param range: The maximum forward distance of the attack's hitbox.
func request_attack(damage: float, range: float) -> void:
	if not player.is_multiplayer_authority() and not NetworkService.is_server(): return

	# Determine weapon type for animation
	var item_type = ItemData.Type.WEAPON
	if player.inventory:
		var item = player.inventory.get_active_item()
		if item:
			var data = ItemService.get_item(item.id)
			if data:
				item_type = data.type

	player.play_attack_animation.rpc(item_type)

	if NetworkService.is_server():
		_perform_attack_rpc(damage, range)
	else:
		# Call the RPC on this node
		rpc_id(1, "_perform_attack_rpc", damage, range)

## Server-Authoritative RPC that executes the attack logic, calculates area-of-effect (cleave), 
## and applies damage/knockback to valid targets using a physics sphere sweep.
## 
## @param damage: The calculated damage to apply to hit targets.
## @param range: The radius of the physics shape cast in front of the player.
@rpc("any_peer", "call_remote", "reliable")
func _perform_attack_rpc(damage: float, range: float) -> void:
	if not NetworkService.is_server() or not is_instance_valid(player): return

	var sender_id = multiplayer.get_remote_sender_id()
	# sender_id is 0 for local calls, which is valid on the server
	if sender_id != 0 and sender_id != player.player_id: return

	
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

## Ranged/Magic Server Hit Detection
func request_shoot(item_id: String) -> void:
	if not player.is_multiplayer_authority() and not NetworkService.is_server(): return

	# Determine REAL target crosshair direction from client camera
	var shoot_dir = -player.global_transform.basis.z
	var camera = player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
	if camera and camera.current:
		var viewport = camera.get_viewport()
		if viewport:
			var center = viewport.get_visible_rect().size / 2.0
			var crosshair_origin = camera.project_ray_origin(center)
			var crosshair_dir = camera.project_ray_normal(center)
			
			var space_state = player.get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(crosshair_origin, crosshair_origin + (crosshair_dir * 100.0), 3)
			query.exclude = [player.get_rid()]
			var result = space_state.intersect_ray(query)
			
			var target_pos = crosshair_origin + (crosshair_dir * 100.0)
			if result:
				target_pos = result.position
			
			var origin = player.global_position + Vector3(0, 1.5, 0)
			var skeleton = player.get_node_or_null("Model/rig_deform/GeneralSkeleton")
			if skeleton and player.inventory:
				var item = player.inventory.get_active_item()
				if item:
					var data = ItemService.get_item(item.id)
					if data and data.get("attachment_bone"):
						var bone = skeleton.get_node_or_null(data.attachment_bone)
						if bone: origin = bone.global_position
			
			shoot_dir = (target_pos - origin).normalized()
			if shoot_dir.length_squared() < 0.01:
				shoot_dir = -player.global_transform.basis.z

	if NetworkService.is_server():
		_perform_shoot_rpc(item_id, shoot_dir)
	else:
		rpc_id(1, "_perform_shoot_rpc", item_id, shoot_dir)

@rpc("any_peer", "call_remote", "reliable")
func _perform_shoot_rpc(item_id: String, shoot_dir: Vector3 = Vector3.ZERO) -> void:
	if not NetworkService.is_server() or not is_instance_valid(player): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != player.player_id: return

	var data = ItemService.get_item(item_id)
	if not data: return
	
	if shoot_dir == Vector3.ZERO:
		shoot_dir = -player.global_transform.basis.z
	
	# Origin is the attachment bone
	var origin = player.global_position + Vector3(0, 1.5, 0)
	var skeleton = player.get_node_or_null("Model/rig_deform/GeneralSkeleton")
	if skeleton and data.get("attachment_bone"):
		var bone = skeleton.get_node_or_null(data.attachment_bone)
		if bone: origin = bone.global_position
			
	# Server calculates actual hit completely instantly using RayCast
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + (shoot_dir * 100.0), 3) # Mask 1&2
	query.exclude = [player.get_rid()]
	var result = space_state.intersect_ray(query)
	var hit_pos = origin + (shoot_dir * 100.0)
	
	var target_path = NodePath()
	
	if result:
		hit_pos = result.position
		var target = result.collider
		if not target.has_method("take_damage") and target.get_parent() and target.get_parent().has_method("take_damage"):
			target = target.get_parent()
		if target.has_method("take_damage") and target != player:
			target_path = target.get_path()
			var damage = 25.0
			if data.get("stats") and data.stats.has("strength"):
				damage += data.stats.strength
			target.take_damage(damage)
			if target.has_method("apply_knockback"):
				target.apply_knockback(player.global_position, 2.0)
	
	# Tell all clients to spawn the purely visual projectile.
	var speed = data.get("projectile_speed") if data.get("projectile_speed") != null else 25.0
	_spawn_visual_projectile_rpc.rpc(item_id, origin, hit_pos, speed, target_path)

@rpc("any_peer", "call_local", "reliable")
func _spawn_visual_projectile_rpc(item_id: String, start_pos: Vector3, target_pos: Vector3, speed: float, target_path: NodePath = NodePath()) -> void:
	if multiplayer.get_remote_sender_id() != 1 and not NetworkService.is_server(): return
	var data = ItemService.get_item(item_id)
	if not data or not data.get("projectile_scene") or data.projectile_scene == null: return
	
	var proj = data.projectile_scene.instantiate()
	player.get_tree().current_scene.add_child(proj)
	
	if proj.has_method("fire_homing") and not target_path.is_empty():
		var target_node = player.get_node_or_null(target_path)
		if target_node:
			proj.fire_homing(start_pos, target_node, target_pos, speed)
		else:
			proj.fire(start_pos, target_pos, speed)
	elif proj.has_method("fire"):
		proj.fire(start_pos, target_pos, speed)
	else:
		proj.global_position = start_pos
		proj.look_at(target_pos, Vector3.UP)
