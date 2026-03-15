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

# External Inventory Tracking
var external_inventory: Array[ItemStackData] = []
var player_external_paths: Dictionary = {} # player_id -> NodePath
var current_external_type: String = "external"

# Convenience access to local player
func get_local_player() -> Node3D:
	if not multiplayer.has_multiplayer_peer(): return null
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED: return null
	
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p.is_inside_tree() and p.is_multiplayer_authority():
			return p
	return null

# Legacy compatibility / Shorthand (Client Side Only)
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
	player.active_slot_index = player.inventory.active_hotbar_index
	
	if initial_data.has("stash"):
		player.stash.load_from_dict(initial_data["stash"])
	else:
		player.stash._initialize_slots()
	
	if initial_data.has("stats"):
		player.stats.from_dict(initial_data["stats"])
	else:
		player.stats.reset()
	
	recalculate_stats(player)
	
	if player.is_inside_tree() and player.is_multiplayer_authority():
		# Force trigger UI refresh on the resource itself
		player.inventory.inventory_updated.emit()
		player.stash.inventory_updated.emit()
		
		inventory_updated.emit()
		active_slot_changed.emit(player.inventory.active_hotbar_index)
		print("[InventoryService] Loaded local inventory for: ", db_id)
		
	# REMOVED: Immediate server broadcast. 
	# Clients now request their own inventory via handshake in player_controller.gd

func set_active_slot(index: int) -> void:
	var p = get_local_player()
	if p:
		p.inventory.set_active_slot(index)
		active_slot_changed.emit(index)
		
		# If this is called on a client with authority, the server needs to know
		# to update its local node and sync to PB
		if p.is_multiplayer_authority() and not multiplayer.is_server():
			if p.has_node("Interaction"):
				# Reuse existing RPC mechanism if possible or add new one
				# For now, we'll assume the client-side change is enough for immediate feedback,
				# but we need to tell the server to update the active slot index too.
				p.active_slot_index = index # This might trigger sync if properly setup
		
		if multiplayer.is_server():
			_sync_and_emit(p)

func get_active_item() -> ItemStackData:
	var p = get_local_player()
	return p.inventory.get_active_item() if p else null

## Server-Authoritative: Only the server should add items
func add_item(player: Node3D, item_id: String, quantity: int = 1) -> bool:
	if not player: return false
	
	var item_def = ItemService.get_item(item_id)
	if not item_def: return false

	if InventoryManager.add_item_to_arrays(player.inventory.hotbar, player.inventory.bag, item_id, quantity, item_def.stackable):
		_sync_and_emit(player)
		return true

	return false 

func add_experience_to_player(player: Node3D, amount: int) -> void:
	if not player: return
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
	if not player: return
	var total_stats = InventoryManager.recalculate_stats(player)
	if player.is_inside_tree() and player.is_multiplayer_authority():
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
	if not player: return
	
	if player.is_multiplayer_authority():
		inventory_updated.emit()
		
	# SERVER ONLY: Sync to the persistence layer (PocketBase).
	if multiplayer.is_server():
		var sync_data = player.inventory.to_dict()
		sync_data["stash"] = player.stash.to_dict()
		sync_data["stats"] = player.stats.to_dict()
		var peer_id = player.player_id if "player_id" in player else 1
		print("[InventoryService] Server Sync for ", player.player_name, " (peer ", peer_id, "): ", JSON.stringify(sync_data).left(100), "...")
		PocketBaseRPCManager.request_sync_inventory(player.player_name, sync_data, peer_id)
		
		# BROADCAST to all clients so they can see each other's items
		if player.has_method("sync_inventory_to_clients"):
			player.sync_inventory_to_clients.rpc(player.inventory.to_dict(), player.stash.to_dict())

## Server-Authoritative: Validates and executes item movement
func _get_array_by_type(player: Node3D, type: String) -> Variant:
	if not is_instance_valid(player): return null
	var p_id = player.player_id if "player_id" in player else 1
	
	match type:
		"hotbar": return player.inventory.hotbar if player.inventory else null
		"bag": return player.inventory.bag if player.inventory else null
		"armor": return player.inventory.armor if player.inventory else null
		"stash": return player.stash.items if player.stash else null
		"external": 
			# On client, we use the global cache for the UI
			if player.is_multiplayer_authority():
				return external_inventory
			
			# On server, we look up the items from the registered path for this specific player
			var path = player_external_paths.get(p_id, NodePath(""))
			if not path.is_empty():
				var node = get_tree().root.get_node_or_null(path)
				if node and "items" in node:
					# Return the DIRECT reference to the items array
					# InventoryManager will now handle the type conversion in move_item
					return node.items
			return null
	return null

## Internal helper to sync back external changes
func _sync_external_back(player: Node3D, type: String, modified_arr: Variant) -> void:
	var p_id = player.player_id if "player_id" in player else 1
	var path = player_external_paths.get(p_id, NodePath(""))
	
	if not multiplayer.is_server() or type != "external" or path.is_empty(): return
	
	var node = get_tree().root.get_node_or_null(path)
	if node and "items" in node:
		# modified_arr IS node.items because it's a reference. 
		# We just need to trigger the UI refresh RPC
		print("[InventoryService] Synced external back to: ", path)
		node._open_loot_ui.rpc_id(p_id, node.items, path)

func move_item(player: Node3D, from_type: String, from_idx: int, to_type: String, to_idx: int) -> void:
	if not player: return
	
	if multiplayer.is_server():
		print("[InventoryService] Server move request: ", from_type, "[", from_idx, "] -> ", to_type, "[", to_idx, "] for player: ", player.player_name)

	var from_arr = _get_array_by_type(player, from_type)
	var to_arr = _get_array_by_type(player, to_type)
	
	# Verify indices to prevent crashes
	if from_arr == null or from_idx < 0 or from_idx >= from_arr.size(): 
		printerr("[InventoryService] Invalid from_arr or index: ", from_type)
		return
	if to_arr == null or to_idx < 0 or to_idx >= to_arr.size(): 
		printerr("[InventoryService] Invalid to_arr or index: ", to_type)
		return
	
	var item_to_move = from_arr[from_idx]
	if item_to_move:
		print("[InventoryService] Moving item: ", item_to_move.id, " x", item_to_move.quantity)
	
	InventoryManager.move_item(from_arr, from_idx, to_arr, to_idx)
	
	# Sync back to external source if needed
	if multiplayer.is_server():
		if from_type == "external": _sync_external_back(player, from_type, from_arr)
		if to_type == "external": _sync_external_back(player, to_type, to_arr)
	
	if from_type == "armor" or to_type == "armor":
		recalculate_stats(player)
		
	if (from_type == "external" or from_type == "stash") or (to_type == "external" or to_type == "stash"):
		if player.is_multiplayer_authority():
			external_inventory_updated.emit()
		
	_sync_and_emit(player)
	
	if player.is_multiplayer_authority():
		if (from_type == "hotbar" and from_idx == player.inventory.active_hotbar_index) or \
		   (to_type == "hotbar" and to_idx == player.inventory.active_hotbar_index):
			active_slot_changed.emit(player.inventory.active_hotbar_index)

func open_external_inventory(items: Array, path: NodePath = "", type: String = "external") -> void:
	external_inventory.clear()
	for item in items:
		if item is Dictionary:
			external_inventory.append(ItemStackData.from_dict(item))
		else:
			external_inventory.append(item)
	
	current_external_type = type
	
	var p = get_local_player()
	if p:
		player_external_paths[p.player_id] = path
		
	external_inventory_updated.emit()
	if type == "stash": stash_opened.emit(true)

## Called by Server to link a player to an external container
func register_external_interaction(player_id: int, path: NodePath) -> void:
	player_external_paths[player_id] = path
	print("[InventoryService] Server linked peer ", player_id, " to ", path)

func close_external_inventory() -> void:
	external_inventory = []
	var p = get_local_player()
	if p:
		player_external_paths.erase(p.player_id)
	current_external_type = "external"
	external_inventory_updated.emit()
	stash_opened.emit(false)

func reset() -> void:
	external_inventory.clear()
	player_external_paths.clear()
	current_external_type = "external"
	external_inventory_updated.emit()
	stash_opened.emit(false)
	print("[InventoryService] Service state reset.")
