extends Node3D

@onready var light: OmniLight3D = $Light

# Called by player_controller when the use_item_state changes
func sync_state(is_on: bool) -> void:
	if light:
		light.visible = is_on
		print("[Lantern] Light synced to: ", "ON" if is_on else "OFF")

# Fallback for direct use if needed (e.g. initial setup)
func use() -> void:
	pass
