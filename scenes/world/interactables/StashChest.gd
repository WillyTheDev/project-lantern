extends StaticBody3D

## StashChest
## An interactable chest that opens the player's persistent personal stash.

func interact(player: Node3D) -> void:
	if not multiplayer.is_server(): return
	
	var peer_id = player.player_id if "player_id" in player else 1
	_open_stash_ui.rpc_id(peer_id)

@rpc("authority", "call_local", "reliable")
func _open_stash_ui() -> void:
	# On client, we open the stash using the special 'stash' type
	var s = InventoryService.stash
	if not s:
		print("[StashChest] ABORT: Stash not available.")
		return
		
	InventoryService.open_external_inventory(s.bag, get_path())
	
	# We need to tell the UI that this is specifically a STASH to use the correct type in slots
	# For simplicity, we can just use the path or a signal.
	# But let's modify open_external_inventory to accept a type.
	
	# Actually, let's just use a signal to tell InventoryUI to use 'stash' type for external slots.
	if InventoryService.has_signal("stash_opened"):
		InventoryService.emit_signal("stash_opened", true)

func request_remove_item(slot_index: int) -> void:
	# This is called by move_item when moving FROM external to player.
	# For stash, InventoryService handles it internally since it's just another InventoryData.
	pass

