extends CharacterBody3D

@export var speed: float = 2.0
@export var damage_amount: float = 15.0
@export var attack_cooldown: float = 1.5
@export var detection_range: float = 15.0
@export var attack_range: float = 1.5

# Health
@export var max_health: float = 50.0
@export var current_health: float = 50.0

@export var sync_position: Vector3
@export var sync_rotation: float

var target_player: Node3D = null
var last_attack_time: float = 0.0

func _ready() -> void:
	# Only the server runs the AI logic
	if not multiplayer.is_server():
		set_physics_process(false)
		return
	
	print("[Guardian] Initialized on Server.")

func _physics_process(delta: float) -> void:
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
			
		move_and_slide()
		sync_position = global_position
	else:
		# Idle/Patrol logic could go here
		pass

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
		print("[Guardian] Targeted player: ", target_player.name)

func _try_attack() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time >= attack_cooldown:
		if target_player and target_player.has_method("take_damage"):
			print("[Guardian] Attacking player!")
			target_player.take_damage(damage_amount)
			last_attack_time = current_time

func take_damage(amount: float) -> void:
	if not multiplayer.is_server(): return
	
	current_health -= amount
	print("[Guardian] Took damage: ", amount, ". Remaining health: ", current_health)
	
	# Play effects on all clients
	_play_damage_fx.rpc(amount)
	
	if current_health <= 0:
		_die()

@rpc("any_peer", "call_local", "reliable")
func _play_damage_fx(amount: float) -> void:
	# 1. Floating Text
	var text_scene = preload("res://scenes/effects/DamageText.tscn")
	var text_instance = text_scene.instantiate()
	get_tree().root.add_child(text_instance)
	
	# Position at enemy head level with slight random offset
	var offset = Vector3(randf_range(-0.5, 0.5), 1.8, randf_range(-0.5, 0.5))
	text_instance.global_position = global_position + offset
	if text_instance.has_method("setup"):
		text_instance.setup(amount)
		
	# 2. Hit Flash
	var mesh = $MeshInstance3D
	if mesh:
		var mat = mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			var tween = create_tween()
			tween.tween_method(func(v): mat.set_shader_parameter("hit_intensity", v), 1.0, 0.0, 0.2)

func _die() -> void:
	# 1. Spawn loot on the server
	_spawn_loot()
	
	# 2. Sync removal to clients
	_sync_death.rpc()

func _spawn_loot() -> void:
	if not multiplayer.is_server(): return
	
	# Find the spawner in the scene
	var spawner = get_tree().root.find_child("MultiplayerPlayerSpawner", true, false)
	if not spawner:
		print("[Guardian] ERROR: Could not find MultiplayerPlayerSpawner to drop loot.")
		return
		
	# Random loot generation
	var possible_items = ["lantern", "rusty_sword", "leather_cap"]
	var item_id = possible_items[randi() % possible_items.size()]
	var loot_data = {
		"type": "loot",
		"items": [{"id": item_id, "quantity": 1}],
		"pos": global_position
	}
	
	spawner.spawn(loot_data)
	print("[Guardian] Dropped loot via spawner: ", item_id)

@rpc("authority", "call_local", "reliable")
func _sync_death() -> void:
	print("[Guardian] Defeated and removed.")
	queue_free()

func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer(): return
	
	if not multiplayer.is_server():
		# Clients just interpolate to the synced position/rotation
		global_position = global_position.lerp(sync_position, 10 * delta)
		rotation.y = lerp_angle(rotation.y, sync_rotation, 10 * delta)
