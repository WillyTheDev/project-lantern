class_name InventoryManager
extends Object

## InventoryManager (Manager)
## Stateless implementation of inventory rules and calculations.

static func recalculate_stats(player: Node3D) -> Dictionary:
	var total_stats = {
		"agility": player.stats.agility,
		"strength": player.stats.strength,
		"intellect": player.stats.intellect,
		"stamina": player.stats.stamina,
		"max_health": player.stats.max_health
	}
	
	for slot in player.inventory.armor:
		if slot:
			var item_def = ItemService.get_item(slot.id)
			if item_def:
				total_stats["agility"] += item_def.stats.get("agility", 0)
				total_stats["strength"] += item_def.stats.get("strength", 0)
				total_stats["intellect"] += item_def.stats.get("intellect", 0)
				total_stats["stamina"] += item_def.stats.get("stamina", 0)
				
	total_stats["max_health"] = 100.0 + (total_stats["stamina"] - 10) * 10.0
	return total_stats

static func add_item_to_arrays(hotbar: Array[ItemStackData], bag: Array[ItemStackData], item_id: String, quantity: int, stackable: bool) -> bool:
	if _add_to_array(hotbar, item_id, quantity, stackable):
		return true
	if _add_to_array(bag, item_id, quantity, stackable):
		return true
	return false

static func _add_to_array(arr: Array[ItemStackData], item_id: String, quantity: int, stackable: bool) -> bool:
	if stackable:
		for item in arr:
			if item and item.id == item_id:
				item.quantity += quantity
				return true
				
	for i in range(arr.size()):
		if arr[i] == null:
			arr[i] = ItemStackData.new(item_id, quantity)
			return true
	return false

static func move_item(from_arr: Array, from_idx: int, to_arr: Array, to_idx: int) -> void:
	var item_to_move = from_arr[from_idx]
	var item_at_dest = to_arr[to_idx]
	
	# Convert item_to_move to the format expected by to_arr
	var processed_to_move = item_to_move
	if to_arr is Array[ItemStackData]:
		if item_to_move is Dictionary:
			processed_to_move = ItemStackData.from_dict(item_to_move)
	else: # Mixed array or Dictionary array (external)
		if item_to_move is ItemStackData:
			processed_to_move = item_to_move.to_dict()

	# Convert item_at_dest to the format expected by from_arr
	var processed_at_dest = item_at_dest
	if from_arr is Array[ItemStackData]:
		if item_at_dest is Dictionary:
			processed_at_dest = ItemStackData.from_dict(item_at_dest)
	else: # Mixed array or Dictionary array (external)
		if item_at_dest is ItemStackData:
			processed_at_dest = item_at_dest.to_dict()

	to_arr[to_idx] = processed_to_move
	from_arr[from_idx] = processed_at_dest
