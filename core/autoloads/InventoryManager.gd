extends Node

## InventoryManager
## Manages slot-based inventory and player stats using Resource models.

signal inventory_updated
signal active_slot_changed(index: int)
signal stats_updated(stats: PlayerStats)

var data: InventoryData = InventoryData.new()
var player_stats: PlayerStats = PlayerStats.new()

var player_db_id: String = ""

# External Inventory (for Loot/Chests)
var external_inventory: Array[ItemStack] = []
var current_external_path: String = ""
signal external_inventory_updated

func _ready() -> void:
	data.inventory_updated.connect(func(): inventory_updated.emit())
	data.active_slot_changed.connect(func(idx): active_slot_changed.emit(idx))
	player_stats.stats_changed.connect(func(): stats_updated.emit(player_stats))
	recalculate_stats()

func reset() -> void:
	player_db_id = ""
	data._initialize_slots()
	data.active_hotbar_index = 0
	player_stats.reset()
	recalculate_stats()
	inventory_updated.emit()
	active_slot_changed.emit(0)
	print("[InventoryManager] Inventory reset.")

func load_inventory(db_id: String, initial_data: Dictionary) -> void:
	player_db_id = db_id
	data.load_from_dict(initial_data)
	recalculate_stats()
	active_slot_changed.emit(data.active_hotbar_index)
	print("[InventoryManager] Loaded inventory for: ", db_id)

func set_active_slot(index: int) -> void:
	data.set_active_slot(index)

func get_active_item() -> ItemStack:
	return data.get_active_item()

func add_item(item_id: String, quantity: int = 1) -> bool:
	var item_def = ItemDB.get_item(item_id)
	if not item_def: return false

	# Try hotbar first, then bag
	if _add_to_array(data.hotbar, item_id, quantity, item_def.stackable):
		_sync_and_emit()
		return true
		
	if _add_to_array(data.bag, item_id, quantity, item_def.stackable):
		_sync_and_emit()
		return true

	return false 

func _add_to_array(arr: Array[ItemStack], item_id: String, quantity: int, stackable: bool) -> bool:
	if stackable:
		for item in arr:
			if item and item.id == item_id:
				item.quantity += quantity
				return true
				
	for i in range(arr.size()):
		if arr[i] == null:
			arr[i] = ItemStack.new(item_id, quantity)
			return true
	return false

func recalculate_stats() -> void:
	var new_agility = 10
	var new_strength = 10
	var new_intellect = 10
	var new_stamina = 10
	
	for slot in data.armor:
		if slot:
			var item_def = ItemDB.get_item(slot.id)
			if item_def:
				new_agility += item_def.stats.get("agility", 0)
				new_strength += item_def.stats.get("strength", 0)
				new_intellect += item_def.stats.get("intellect", 0)
				new_stamina += item_def.stats.get("stamina", 0)
				
	player_stats.agility = new_agility
	player_stats.strength = new_strength
	player_stats.intellect = new_intellect
	player_stats.stamina = new_stamina
	# Note: stamina setter automatically updates max_health

func _sync_and_emit() -> void:
	inventory_updated.emit()
	if player_db_id != "" and multiplayer.is_server():
		PBHelper.request_sync_inventory(player_db_id, data.to_dict())

func move_item(from_type: String, from_idx: int, to_type: String, to_idx: int) -> void:
	var from_arr = _get_array_by_type(from_type)
	var to_arr = _get_array_by_type(to_type)
	if from_arr == null or to_arr == null: return
	
	var item_to_move = from_arr[from_idx]
	var item_at_dest = to_arr[to_idx]
	
	to_arr[to_idx] = item_to_move
	from_arr[from_idx] = item_at_dest
	
	if from_type == "armor" or to_type == "armor":
		recalculate_stats()
		
	if from_type == "external" or to_type == "external":
		external_inventory_updated.emit()
		if from_type == "external" and current_external_path != "" and multiplayer.is_server():
			var target_node = get_tree().root.get_node_or_null(current_external_path)
			if target_node and target_node.has_method("request_remove_item"):
				target_node.request_remove_item.rpc_id(1, from_idx)
		
	_sync_and_emit()
	
	if (from_type == "hotbar" and from_idx == data.active_hotbar_index) or \
	   (to_type == "hotbar" and to_idx == data.active_hotbar_index):
		active_slot_changed.emit(data.active_hotbar_index)

func open_external_inventory(items: Array, path: NodePath = "") -> void:
	external_inventory.clear()
	for item in items:
		if item is Dictionary:
			external_inventory.append(ItemStack.from_dict(item))
		else:
			external_inventory.append(item)
	current_external_path = path
	external_inventory_updated.emit()

func close_external_inventory() -> void:
	external_inventory = []
	current_external_path = ""
	external_inventory_updated.emit()

func _get_array_by_type(type: String) -> Variant:
	match type:
		"hotbar": return data.hotbar
		"bag": return data.bag
		"armor": return data.armor
		"external": return external_inventory
	return null
