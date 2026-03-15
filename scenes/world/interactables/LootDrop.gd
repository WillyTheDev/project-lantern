extends StaticBody3D

@export var items: Array = [] # Array of {"id": "...", "quantity": 1}
var is_open: bool = false

func _ready() -> void:
	pass

func interact(player: Node3D) -> void:
	if not multiplayer.is_server(): return
	
	if items.size() == 0:
		print("[Loot] Drop is empty, removing.")
		_sync_empty.rpc()
		return
		
	var peer_id = player.player_id if "player_id" in player else 1
	print("[Loot] Server processing interaction for Peer: ", peer_id)
	
	# Register this interaction on the server's InventoryService
	InventoryService.register_external_interaction(peer_id, get_path())
	
	# Always use RPC to ensure it triggers correctly on the targeted client
	_open_loot_ui.rpc_id(peer_id, items, get_path())

@rpc("authority", "call_local", "reliable")
func _open_loot_ui(loot_items: Array, path: NodePath) -> void:
	print("[Loot] Client received RPC to open loot UI.")
	InventoryService.open_external_inventory(loot_items, path)

@rpc("any_peer", "call_remote", "reliable")
func request_remove_item(slot_index: int) -> void:
	if not multiplayer.is_server(): return

	var sender_id = multiplayer.get_remote_sender_id()
	# (Future: add distance check here)

	if slot_index >= 0 and slot_index < items.size():
		print("[Loot] Peer ", sender_id, " took item from slot ", slot_index)
		items[slot_index] = null

@rpc("authority", "call_local", "reliable")
func _sync_empty() -> void:
	queue_free()

func _process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer(): return
	if not multiplayer.is_server(): return
	
	# If items are empty (moved by player), remove the drop
	var all_empty = true
	for item in items:
		if item != null:
			all_empty = false
			break
			
	if all_empty:
		_sync_empty.rpc()

