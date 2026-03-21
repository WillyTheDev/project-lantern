class_name InventoryManager
extends Object

## InventoryManager (Manager)
## Stateless implementation of inventory rules and calculations.

## Calculates the player's total cumulative stats by summing base values and equipped armor modifiers.
##
## @param player: The player node to analyze.
## @return: A dictionary containing the final calculated stat values.
static func recalculate_stats(player: Node3D) -> Dictionary:
	var total_stats = {
		"agility": player.stats.agility,
		"strength": player.stats.strength,
		"intellect": player.stats.intellect,
		"stamina": player.stats.stamina,
		"max_health": player.stats.max_health,
		"max_mana": player.stats.max_mana,
		"vampirism": 0.0,
		"scale_multiplier": 1.0,
		"speed": 1.0,
		"knockback_bonus": 1.0,
		"extra_jumps": 0,
		"mana_regen": 0.0,
		"health_regen": 0.0,
		"thorns": 0.0,
		"luck": 0.0,
		"crit_multiplier": 1.5,
		"cdr": 0.0,
		"cleave": 1.0,
		"evasion": 0.0,
		"multishot": 0
	}
	
	for slot in player.inventory.armor:
		if slot:
			var item_def = ItemService.get_item(slot.id)
			if item_def and item_def.stat_modifiers:
				total_stats["agility"] += item_def.stat_modifiers.get("agility", 0)
				total_stats["strength"] += item_def.stat_modifiers.get("strength", 0)
				total_stats["intellect"] += item_def.stat_modifiers.get("intellect", 0)
				total_stats["stamina"] += item_def.stat_modifiers.get("stamina", 0)
			
			if slot.custom_data.has("modifiers"):
				var mods = slot.custom_data["modifiers"]
				for mod_name in mods:
					if total_stats.has(mod_name):
						total_stats[mod_name] += mods[mod_name]
				
	total_stats["max_health"] = LevelManager.calculate_max_hp(total_stats["stamina"])
	total_stats["max_mana"] = 100.0 + (total_stats["intellect"] - 10) * 10.0
	return total_stats

## Validates if the player meets all stat requirements to equip the item.
static func can_equip(item_def: ItemData, stats: PlayerStatsData) -> bool:
	if not item_def or not stats: return false
	if stats.agility < item_def.required_stats.get("agility", 0): return false
	if stats.strength < item_def.required_stats.get("strength", 0): return false
	if stats.intellect < item_def.required_stats.get("intellect", 0): return false
	if stats.stamina < item_def.required_stats.get("stamina", 0): return false
	return true


## Attempts to insert a new item or stack into the player's hotbar or bag inventories.
##
## @param hotbar: The active hotbar array reference.
## @param bag: The active bag array reference.
## @param item_id: The string ID of the item definition.
## @param quantity: The amount to add.
## @param stackable: Whether this item is allowed to merge with existing stacks.
## @return: True if the item was successfully accommodated, False if no space remains.
static func add_item_to_arrays(hotbar: Array[ItemStackData], bag: Array[ItemStackData], item_id: String, quantity: int, stackable: bool) -> bool:
	if _add_to_array(hotbar, item_id, quantity, stackable):
		return true
	if _add_to_array(bag, item_id, quantity, stackable):
		return true
	return false

## Internal helper that seeks an empty or stackable slot within a target inventory array.
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

## Swaps or moves an item between two array indices.
## Handles automatic type conversion between internal `ItemStackData` objects and serialized external `Dictionary` forms.
##
## @param from_arr: The source array.
## @param from_idx: The integer index of the originating slot.
## @param to_arr: The destination array.
## @param to_idx: The integer index of the destination slot.
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
