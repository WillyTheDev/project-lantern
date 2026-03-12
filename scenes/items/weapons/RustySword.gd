extends Node3D

@export var damage: float = 10.0
@export var range: float = 2.0

func use() -> void:
	print("[Sword] use() called.")
	# Get the player controller
	var player = get_parent().get_parent().get_parent() # HandPoint -> MeshInstance3D -> Player
	if player:
		print("[Sword] Found player: ", player.name)
		if player.has_method("request_attack"):
			player.request_attack(damage, range)
		else:
			print("[Sword] ERROR: Player has no request_attack method.")
	else:
		print("[Sword] ERROR: Could not find player node from hierarchy.")
