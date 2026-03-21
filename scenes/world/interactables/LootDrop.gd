extends StaticBody3D

@export var items: Array = [] # Array of {"id": "...", "quantity": 1}
var sync_items: Array:
	set(val):
		sync_items = val
		items = val
		_update_visuals()

var sync_position: Vector3:
	set(val):
		sync_position = val
		global_position = val

var is_open: bool = false

func _ready() -> void:
	_update_visuals()

func _update_visuals() -> void:
	var label = get_node_or_null("Label3D")
	if label:
		if items.size() > 0:
			label.text = "LOOT [E]\n(%d items)" % items.size()
		else:
			label.text = ""

func interact(player: Node3D) -> void:
	print("[LootDrop] Interaction started at: ", get_path(), " Server: ", NetworkService.is_server())
	if not NetworkService.is_server(): return
	
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
	print("[LootDrop] Client received _open_loot_ui with ", loot_items.size(), " items.")
	for i in range(loot_items.size()):
		print("  - Item ", i, ": ", loot_items[i])
	InventoryService.open_external_inventory(loot_items, path)

@rpc("any_peer", "call_remote", "reliable")
func request_remove_item(slot_index: int) -> void:
	if not NetworkService.is_server(): return

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
	if not NetworkService.is_server(): return
	
	# If items are empty (moved by player), remove the drop
	var all_empty = true
	for item in items:
		if item != null:
			all_empty = false
			break
			
	if all_empty:
		_sync_empty.rpc()

