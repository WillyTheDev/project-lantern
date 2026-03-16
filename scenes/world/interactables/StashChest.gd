extends StaticBody3D

## StashChest
## An interactable chest that opens the player's persistent personal stash.

func interact(player: Node3D) -> void:
	if not NetworkService.is_server(): return

	var peer_id = player.player_id if "player_id" in player else 1

	# Register this interaction on the server's InventoryService
	InventoryService.register_external_interaction(peer_id, get_path())

	_open_stash_ui.rpc_id(peer_id)
@rpc("authority", "call_local", "reliable")
func _open_stash_ui() -> void:
	# On client, we open the stash using the special 'stash' type
	var s = InventoryService.stash
	if not s:
		print("[StashChest] ABORT: Stash not available.")
		return
		
	InventoryService.open_external_inventory(s.items, get_path(), "stash")

	if InventoryService.has_signal("stash_opened"):
		InventoryService.emit_signal("stash_opened", true)


