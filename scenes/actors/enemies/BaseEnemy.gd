extends CharacterBody3D

@export var config: BaseEnemyData

# State
var current_health: float = 100.0

@export var sync_position: Vector3
@export var sync_rotation: float

var target_player: Node3D = null
var last_attack_time: float = 0.0
var knockback_velocity: Vector3 = Vector3.ZERO
var _damage_contributors: Dictionary = {}

func _ready() -> void:
	if not config:
		config = BaseEnemyData.new() # Fallback
	current_health = config.health
	
	add_to_group("enemies")
	
	# Only the server runs the AI logic
	if not NetworkService.is_server():
		set_physics_process(false)
		return
	
	print("[Guardian] Initialized on Server: ", name)

func _physics_process(delta: float) -> void:
	# Decay knockback
	if knockback_velocity.length() > 0.1:
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, 5 * delta) # Slower decay
	else:
		knockback_velocity = Vector3.ZERO

	if not target_player:
		_find_closest_player()
	
	if target_player:
		var dist = global_position.distance_to(target_player.global_position)
		
		# Lost target?
		if dist > 15.0 * 1.2: # Using fixed detection radius for now logic-wise
			target_player = null
			return
			
		# Move towards player
		if dist > 1.5: # attack_range
			var direction = (target_player.global_position - global_position).normalized()
			velocity.x = direction.x * config.movement_speed
			velocity.z = direction.z * config.movement_speed
			
			# Face the player
			look_at(Vector3(target_player.global_position.x, global_position.y, target_player.global_position.z), Vector3.UP)
			sync_rotation = rotation.y
		else:
			velocity.x = 0
			velocity.z = 0
			_try_attack()
			
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		else:
			velocity.y = 0
			
		velocity += knockback_velocity
		move_and_slide()
		sync_position = global_position
	else:
		# Idle/Patrol logic could go here
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		else:
			velocity.y = 0
		
		velocity.x = 0
		velocity.z = 0
		velocity += knockback_velocity
		move_and_slide()
		sync_position = global_position

func _find_closest_player() -> void:
	var players = get_tree().get_nodes_in_group("players")
	var closest_dist = 15.0
	var closest_player = null
	
	for player in players:
		var dist = global_position.distance_to(player.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_player = player
			
	if closest_player:
		target_player = closest_player

func _try_attack() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time >= 1.5: # attack_cooldown
		last_attack_time = current_time
		# Trigger the sequence for everyone
		_play_attack_fx.rpc()
		_perform_attack_logic()

@rpc("any_peer", "call_local", "reliable")
func _play_attack_fx() -> void:
	# Telegraph/Wind-up (Visual cue for all clients)
	var mesh = $MeshInstance3D
	if not mesh: return
	
	var base_scale = mesh.scale
	var tween = create_tween()
	var _windup = 0.4 # Default fallback if missing from config
	if config and "attack_windup" in config: _windup = config.attack_windup
	tween.tween_property(mesh, "scale", Vector3(base_scale.x * 0.9, base_scale.y * 1.2, base_scale.z * 0.9), _windup)
	tween.chain().tween_property(mesh, "scale", base_scale, 0.1)

func _perform_attack_logic() -> void:
	await get_tree().create_timer(0.4).timeout # attack windup
	
	# Damage Application (Cleave) - Server Only
	if not NetworkService.is_server() or not is_inside_tree(): return
	
	var space_state = get_world_3d().direct_space_state
	var forward = -global_transform.basis.z
	var attack_pos = global_position + (forward * (1.5 / 2.0))
	
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.5
	query.shape = sphere
	query.transform = Transform3D(Basis(), attack_pos)
	query.collision_mask = 1 # Players are usually on layer 1
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider.has_method("take_damage") and collider.is_in_group("players"):
			var target = collider
			# Deal damage back strictly using self (enemy node) to safely enable Thorns logic tracking on the Player
			target.take_damage(config.damage, self)
			if collider.has_method("apply_knockback"):
				collider.apply_knockback(global_position, 12.0)

func take_damage(amount: float, source_node: Node = null) -> void:
	if not NetworkService.is_server() or current_health <= 0: return
	
	var source_id = -1
	if source_node and source_node.has_method("get_instance_id"):
		# In case we need to reflect thorns natively over physics, we identify node refs
		if source_node.get("player_id"):
			source_id = source_node.player_id
	
	current_health -= amount
	
	if source_id != 1 and source_id != 0:
		if not _damage_contributors.has(source_id):
			_damage_contributors[source_id] = 0.0
		_damage_contributors[source_id] += amount
		
	# Play effects on all clients
	_play_damage_fx.rpc(amount)
	
	if current_health <= 0:
		print("[BaseEnemy] %s DIED. Triggering _die()" % name)
		_die()

func apply_knockback(source_position: Vector3, force: float) -> void:
	if not NetworkService.is_server(): return
	var knockback_dir = (global_position - source_position).normalized()
	knockback_dir.y = 0 # Keep it horizontal
	knockback_velocity += knockback_dir * force

var _damage_fx_cooldown: float = 0.0

@rpc("any_peer", "call_local", "reliable")
func _play_damage_fx(amount: float) -> void:
	# Cooldown to avoid breaking animations from rapid damage (e.g. Hazards)
	var now = Time.get_ticks_msec() / 1000.0
	if now < _damage_fx_cooldown:
		return
	_damage_fx_cooldown = now + 0.2
	
	# 1. Floating Text
	var text_scene = preload("res://scenes/effects/DamageText.tscn")
	var text_instance = text_scene.instantiate()
	get_tree().root.add_child(text_instance)
	
	var offset = Vector3(randf_range(-0.5, 0.5), 1.8, randf_range(-0.5, 0.5))
	text_instance.global_position = global_position + offset
	if text_instance.has_method("setup"):
		text_instance.setup(amount)
		
	# 2. Hit Flash & Squash/Stretch
	var mesh = $MeshInstance3D
	if not mesh: return
	
	var base_scale = mesh.scale
	var tween = create_tween().set_parallel(true)
	
	var mat = mesh.get_surface_override_material(0) as ShaderMaterial
	if mat:
		tween.tween_method(func(v): mat.set_shader_parameter("hit_intensity", v), 1.0, 0.0, 0.2)
	
	# Squash and Stretch (Juice)
	tween.tween_property(mesh, "scale", Vector3(base_scale.x * 1.1, base_scale.y * 0.9, base_scale.z * 1.1), 0.05)
	tween.chain().tween_property(mesh, "scale", base_scale, 0.1)

func _die() -> void:
	# Grant XP to all contributors
	var all_players = get_tree().get_nodes_in_group("players")
	for player_id in _damage_contributors.keys():
		for player in all_players:
			if player.player_id == player_id:
				InventoryService.add_experience_to_player(player, config.experience_reward)
				break
				
	# 1. Spawn loot on the server
	_spawn_loot()
	# 2. Server-side removal (Synchronizer will handle it for clients)
	queue_free()

func _spawn_loot() -> void:
	if not NetworkService.is_server(): return

	var spawner = NetworkService.player_spawner
	if not spawner: return
	
	var drops: Array = []
	var loot_list = config.loot_table
	if loot_list.is_empty():
		print("[BaseEnemy] WARNING: config.loot_table is empty! Using testing fallback loot.")
		loot_list = [{"item_id": "rusty_sword", "drop_chance": 1.0, "min_quantity": 1, "max_quantity": 1}]
	
	for entry in loot_list:
		var chance = entry.get("drop_chance", 1.0)
		var roll = randf()
		var identifier = entry.get("item_id", "procedural" if entry.get("is_procedural") else entry.get("item_type", "unknown"))
		print("[BaseEnemy] Rolling for %s: Roll=%f Chance=%f" % [identifier, roll, chance])
		if roll <= chance:
			var q = randi_range(entry.get("min_quantity", 1), entry.get("max_quantity", 1))
			
			var max_luck = 0.0
			# If no damage contributors, just use 0 luck.
			for pid in _damage_contributors.keys():
				var contrib = NetworkService.get_player(pid)
				if is_instance_valid(contrib):
					var stats = InventoryManager.recalculate_stats(contrib)
					var p_luck = stats.get("luck", 0.0)
					if p_luck > max_luck:
						max_luck = p_luck
						
			print("[BaseEnemy] Generating loot for entry: %s with luck: %f" % [entry, max_luck])
			
			var generated_item: ItemStackData
			if entry.get("is_procedural", false):
				generated_item = LootGenerator.generate_procedural_armor(max_luck)
			elif entry.has("item_type"):
				var raw_type = entry["item_type"]
				# Handle both int enum values and potential string names if defined
				generated_item = LootGenerator.generate_random_equipment(raw_type as ItemData.Type, max_luck, q)
			elif entry.has("item_id"):
				generated_item = LootGenerator.generate_equipment(entry["item_id"], max_luck, q)
				
			if generated_item:
				drops.append(generated_item.to_dict())
			
	if drops.is_empty(): return
	
	var loot_data = {
		"type": "loot",
		"items": drops,
		"pos": global_position + Vector3(0, 0.5, 0)
	}
	print("[BaseEnemy] Calling spawner.spawn(loot_data) at pos: ", loot_data.pos)
	spawner.spawn(loot_data)

func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or NetworkService.is_server(): return
	
	# Clients interpolate (with snapping for large distances/spawn)
	if global_position.distance_to(sync_position) > 2.0:
		global_position = sync_position
	else:
		global_position = global_position.lerp(sync_position, 10 * delta)
		
	rotation.y = lerp_angle(rotation.y, sync_rotation, 10 * delta)
