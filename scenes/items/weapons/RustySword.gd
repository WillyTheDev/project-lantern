extends Node3D

@export var damage: float = 10.0
@export var range: float = 2.0

func use() -> void:
	# Robust way to find the player root (which is in the "players" group)
	var player = owner
	if not player or not player.is_in_group("players"):
		# Fallback: search up the tree
		player = self
		while player != null and not player.is_in_group("players"):
			player = player.get_parent()
	
	if player:
		if player.has_method("request_attack"):
			player.request_attack(damage, range)
		else:
			print("[Sword] ERROR: Player node found but has no request_attack method.")
	else:
		print("[Sword] ERROR: Could not find player root node.")
