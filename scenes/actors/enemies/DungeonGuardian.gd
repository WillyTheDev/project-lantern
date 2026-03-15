extends CharacterBody3D

@export var speed: float = 2.0
@export var damage_amount: float = 15.0
@export var attack_cooldown: float = 1.5
@export var detection_range: float = 15.0
@export var attack_range: float = 1.5
@export var attack_windup: float = 0.4

# Health
@export var max_health: float = 50.0
@export var current_health: float = 50.0

@export var sync_position: Vector3
@export var sync_rotation: float

var target_player: Node3D = null
var last_attack_time: float = 0.0
var knockback_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("enemies")
	
	# Only the server runs the AI logic
	if not multiplayer.is_server():
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
		if dist > detection_range * 1.2:
			target_player = null
			return
			
		# Move towards player
		if dist > attack_range:
			var direction = (target_player.global_position - global_position).normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			
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
	var closest_dist = detection_range
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
	if current_time - last_attack_time >= attack_cooldown:
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
	tween.tween_property(mesh, "scale", Vector3(base_scale.x * 0.9, base_scale.y * 1.2, base_scale.z * 0.9), attack_windup)
	tween.chain().tween_property(mesh, "scale", base_scale, 0.1)

func _perform_attack_logic() -> void:
	await get_tree().create_timer(attack_windup).timeout
	
	# Damage Application (Cleave) - Server Only
	if not multiplayer.is_server() or not is_inside_tree(): return
	
	var space_state = get_world_3d().direct_space_state
	var forward = -global_transform.basis.z
	var attack_pos = global_position + (forward * (attack_range / 2.0))
	
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = attack_range
	query.shape = sphere
	query.transform = Transform3D(Basis(), attack_pos)
	query.collision_mask = 1 # Players are usually on layer 1
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider.has_method("take_damage") and collider.is_in_group("players"):
			collider.take_damage(damage_amount)
			if collider.has_method("apply_knockback"):
				collider.apply_knockback(global_position, 12.0) # Increased to 12.0

func take_damage(amount: float) -> void:
	if not multiplayer.is_server(): return
	
	current_health -= amount
	
	# Play effects on all clients
	_play_damage_fx.rpc(amount)
	
	if current_health <= 0:
		_die()

func apply_knockback(source_position: Vector3, force: float) -> void:
	if not multiplayer.is_server(): return
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
	# 1. Spawn loot on the server
	_spawn_loot()
	# 2. Server-side removal (Synchronizer will handle it for clients)
	queue_free()

func _spawn_loot() -> void:
	if not multiplayer.is_server(): return
	
	var spawner = get_tree().root.find_child("MultiplayerPlayerSpawner", true, false)
	if not spawner: return
		
	var possible_items = ["lantern", "rusty_sword", "leather_cap"]
	var item_id = possible_items[randi() % possible_items.size()]
	var loot_data = {
		"type": "loot",
		"items": [{"id": item_id, "quantity": 1}],
		"pos": global_position
	}
	spawner.spawn(loot_data)

func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server(): return
	
	# Clients interpolate (with snapping for large distances/spawn)
	if global_position.distance_to(sync_position) > 2.0:
		global_position = sync_position
	else:
		global_position = global_position.lerp(sync_position, 10 * delta)
		
	rotation.y = lerp_angle(rotation.y, sync_rotation, 10 * delta)
