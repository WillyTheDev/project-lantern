extends Node3D

@onready var light: OmniLight3D = $Light

func use() -> void:
	# Local player triggers the toggle via RPC
	toggle_light.rpc(!light.visible)

@rpc("any_peer", "call_local", "reliable")
func toggle_light(is_on: bool) -> void:
	if light:
		light.visible = is_on
		print("[Lantern] Light is now ", "ON" if is_on else "OFF")
