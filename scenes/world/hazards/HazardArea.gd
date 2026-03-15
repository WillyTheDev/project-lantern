extends Area3D

@export var damage_per_second: float = 20.0
@export var damage_interval: float = 0.5 # Apply damage twice per second
@export var hazard_name: String = "Hazard"

var overlapping_players: Array = []
var _damage_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		overlapping_players.append(body)
		print("[Hazard] ", hazard_name, ": Player entered: ", body.name)

func _on_body_exited(body: Node) -> void:
	overlapping_players.erase(body)
	print("[Hazard] ", hazard_name, ": Player exited: ", body.name)

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server(): return
	
	if overlapping_players.size() > 0:
		_damage_timer += delta
		if _damage_timer >= damage_interval:
			_damage_timer = 0.0
			var damage = damage_per_second * damage_interval
			for player in overlapping_players:
				if is_instance_valid(player):
					player.take_damage(damage)
					if player.has_method("apply_knockback"):
						player.apply_knockback(global_position, 3.0)
