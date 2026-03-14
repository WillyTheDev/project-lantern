extends Node

## InventoryService (Facade)
## Provides a high-level API for inventory operations.
## Coordinates logic via InventoryManager and syncing via PocketBaseRPCManager.

signal inventory_updated
signal active_slot_changed(index: int)
signal stats_updated(stats: PlayerStatsData)
signal total_stats_updated(total_stats: Dictionary)
signal stash_updated
signal external_inventory_updated
signal stash_opened(is_open: bool)

# External Inventory (for Loot/Chests)
var external_inventory: Array[ItemStackData] = []
var current_external_path: String = ""
var current_external_type: String = "external"

# Convenience access to local player
func get_local_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p.is_multiplayer_authority():
			return p
	return null

# Legacy compatibility / Shorthand
var data: InventoryData: get = _get_local_inventory
var stash: InventoryData: get = _get_local_stash
var player_stats: PlayerStatsData: get = _get_local_stats

func _get_local_inventory(): 
	var p = get_local_player()
	return p.inventory if p else null

func _get_local_stash():
	var p = get_local_player()
	return p.stash if p else null

func _get_local_stats():
	var p = get_local_player()
	return p.stats if p else null

## Called by PocketBaseRPCManager when profile is loaded
func load_inventory_for_player(player: Node3D, db_id: String, initial_data: Dictionary) -> void:
	if not player: return
	player.player_name = db_id
	
	player.inventory.load_from_dict(initial_data)
	
	if initial_data.has("stash"):
		player.stash.load_from_dict(initial_data["stash"])
	else:
		player.stash._initialize_slots()
	
	if initial_data.has("stats"):
		player.stats.from_dict(initial_data["stats"])
	else:
		player.stats.reset()
	
	recalculate_stats(player)
	
	if player.is_multiplayer_authority():
		inventory_updated.emit()
		active_slot_changed.emit(player.inventory.active_hotbar_index)
		print("[InventoryService] Loaded local inventory for: ", db_id)

func set_active_slot(index: int) -> void:
	var p = get_local_player()
	if p:
		p.inventory.set_active_slot(index)
		active_slot_changed.emit(index)

func get_active_item() -> ItemStackData:
	var p = get_local_player()
	return p.inventory.get_active_item() if p else null

func add_item(item_id: String, quantity: int = 1) -> bool:
	var p = get_local_player()
	if not p: return false
	
	var item_def = ItemService.get_item(item_id)
	if not item_def: return false

	if InventoryManager.add_item_to_arrays(p.inventory.hotbar, p.inventory.bag, item_id, quantity, item_def.stackable):
		_sync_and_emit(p)
		return true

	return false 

func add_experience_to_player(player: Node3D, amount: int) -> void:
	player.stats.experience += amount
	_sync_and_emit(player)

func handle_death_for_player(player: Node3D) -> void:
	if not multiplayer.is_server(): return
	
	print("[InventoryService] Handling permadeath for player.")
	player.inventory._initialize_slots()
	player.inventory.active_hotbar_index = 0
	player.stats.reset()
	
	recalculate_stats(player)
	_sync_and_emit(player)

func recalculate_stats(player: Node3D) -> void:
	var total_stats = InventoryManager.recalculate_stats(player)
	if player.is_multiplayer_authority():
		total_stats_updated.emit(total_stats)

# Helpers for UI
func get_total_agility() -> int:
	var p = get_local_player()
	return InventoryManager.recalculate_stats(p)["agility"] if p else 10

func get_total_strength() -> int:
	var p = get_local_player()
	return InventoryManager.recalculate_stats(p)["strength"] if p else 10

func get_total_intellect() -> int:
	var p = get_local_player()
	return InventoryManager.recalculate_stats(p)["intellect"] if p else 10

func get_total_stamina() -> int:
	var p = get_local_player()
	return InventoryManager.recalculate_stats(p)["stamina"] if p else 10

func _sync_and_emit(player: Node3D) -> void:
	if player.is_multiplayer_authority():
		inventory_updated.emit()
		
	if multiplayer.is_server():
		var sync_data = player.inventory.to_dict()
		sync_data["stash"] = player.stash.to_dict()
		sync_data["stats"] = player.stats.to_dict()
		PocketBaseRPCManager.request_sync_inventory(player.player_name, sync_data)

func move_item(from_type: String, from_idx: int, to_type: String, to_idx: int) -> void:
	var p = get_local_player()
	if not p: return
	
	var from_arr = _get_array_by_type(p, from_type)
	var to_arr = _get_array_by_type(p, to_type)
	if from_arr == null or to_arr == null: return
	
	InventoryManager.move_item(from_arr, from_idx, to_arr, to_idx)
	
	if from_type == "armor" or to_type == "armor":
		recalculate_stats(p)
		
	if (from_type == "external" or from_type == "stash") or (to_type == "external" or to_type == "stash"):
		external_inventory_updated.emit()
		if from_type == "external" and current_external_path != "" and multiplayer.is_server():
			var target_node = get_tree().root.get_node_or_null(current_external_path)
			if target_node and target_node.has_method("request_remove_item"):
				target_node.request_remove_item.rpc_id(1, from_idx)
		
	_sync_and_emit(p)
	
	if (from_type == "hotbar" and from_idx == p.inventory.active_hotbar_index) or \
	   (to_type == "hotbar" and to_idx == p.inventory.active_hotbar_index):
		active_slot_changed.emit(p.inventory.active_hotbar_index)

func open_external_inventory(items: Array, path: NodePath = "", type: String = "external") -> void:
	external_inventory.clear()
	for item in items:
		if item is Dictionary:
			external_inventory.append(ItemStackData.from_dict(item))
		else:
			external_inventory.append(item)
	current_external_path = path
	current_external_type = type
	external_inventory_updated.emit()
	if type == "stash": stash_opened.emit(true)

func close_external_inventory() -> void:
	external_inventory = []
	current_external_path = ""
	current_external_type = "external"
	external_inventory_updated.emit()
	stash_opened.emit(false)

func reset() -> void:
	external_inventory.clear()
	current_external_path = ""
	current_external_type = "external"
	external_inventory_updated.emit()
	stash_opened.emit(false)
	print("[InventoryService] Service state reset.")

func _get_array_by_type(player: Node3D, type: String) -> Variant:
	match type:
		"hotbar": return player.inventory.hotbar if player.inventory else null
		"bag": return player.inventory.bag if player.inventory else null
		"armor": return player.inventory.armor if player.inventory else null
		"stash": return player.stash.bag if player.stash else null
		"external": return external_inventory
	return null
