extends Node

## InventoryManager
## Manages the local player's inventory and syncs with PersistenceManager.

signal inventory_updated

# Local inventory: { "item_id": quantity }
var inventory: Dictionary = {}
var player_db_id: String = ""

func _ready() -> void:
	# Listen for PocketBase responses if needed
	PersistenceManager.request_completed.connect(_on_persistence_completed)

func load_inventory(db_id: String, initial_inventory: Dictionary) -> void:
	player_db_id = db_id
	inventory = initial_inventory
	inventory_updated.emit()
	print("[InventoryManager] Loaded inventory for: ", player_db_id)

func add_item(item_id: String, quantity: int = 1) -> void:
	if inventory.has(item_id):
		inventory[item_id] += quantity
	else:
		inventory[item_id] = quantity
	
	inventory_updated.emit()
	_sync_to_db()

func remove_item(item_id: String, quantity: int = 1) -> void:
	if inventory.has(item_id):
		inventory[item_id] -= quantity
		if inventory[item_id] <= 0:
			inventory.erase(item_id)
		
		inventory_updated.emit()
		_sync_to_db()

func has_item(item_id: String) -> bool:
	return inventory.has(item_id) and inventory[item_id] > 0

func _sync_to_db() -> void:
	if player_db_id == "":
		return
	
	# Persist to PocketBase via the Helper (requests the server to do it)
	PBHelper.request_sync_inventory(player_db_id, inventory)

func _on_persistence_completed(collection: String, method: String, response_code: int, result: Variant) -> void:
	if collection == "players" and method == "PATCH":
		if response_code == 200:
			print("[InventoryManager] Successfully synced inventory to DB.")
		else:
			printerr("[InventoryManager] Failed to sync inventory. Code: ", response_code)
