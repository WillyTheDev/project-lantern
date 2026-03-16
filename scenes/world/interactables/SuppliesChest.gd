extends StaticBody3D

## SuppliesChest
## A simple interactable chest that gives starter items to the player.

@export var item_id: String = "lantern"
@export var quantity: int = 1

# Shared logic with LootDrop for UI opening
var items: Array = []

func _ready() -> void:
	# Pre-fill with some random starter items
	_refill_chest()

func _refill_chest() -> void:
	items = []
	var pool = ["lantern", "rusty_sword", "leather_cap"]
	for i in range(3):
		items.append({"id": pool[i], "quantity": 1})

func interact(player: Node3D) -> void:
	if not NetworkService.is_server(): return

	var peer_id = player.player_id if "player_id" in player else 1

	# Register this interaction on the server's InventoryService
	InventoryService.register_external_interaction(peer_id, get_path())

	_open_loot_ui.rpc_id(peer_id, items, get_path())
@rpc("authority", "call_local", "reliable")
func _open_loot_ui(loot_items: Array, path: NodePath) -> void:
	InventoryService.open_external_inventory(loot_items, path)

@rpc("any_peer", "call_remote", "reliable")
func request_remove_item(slot_index: int) -> void:
	if not NetworkService.is_server(): return
	if slot_index >= 0 and slot_index < items.size():
		items[slot_index] = null
		
		# Optional: Auto-refill after some time?
		if _is_empty():
			get_tree().create_timer(30.0).timeout.connect(_refill_chest)

func _is_empty() -> bool:
	for item in items:
		if item != null: return false
	return true

