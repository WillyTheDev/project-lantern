extends Node

## InventoryManager
## Manages slot-based inventory: Hotbar, Bag, and Armor.

signal inventory_updated
signal active_slot_changed(index: int)

# Constants for slot counts
const HOTBAR_SIZE = 10
const BAG_SIZE = 30
const ARMOR_SIZE = 4 # 0: Head, 1: Chest, 2: Legs, 3: Feet

# Inventory Data
var hotbar: Array = []
var bag: Array = []
var armor: Array = []
var active_hotbar_index: int = 0

var player_db_id: String = ""

# Player Stats
var base_stats: Dictionary = {
	"agility": 10,
	"strength": 10,
	"intellect": 10,
	"stamina": 10
}
var total_stats: Dictionary = {}

func _ready() -> void:
	_initialize_slots()
	recalculate_stats()

func _initialize_slots() -> void:
	hotbar.clear()
	for i in range(HOTBAR_SIZE): hotbar.append(null)
	
	bag.clear()
	for i in range(BAG_SIZE): bag.append(null)
	
	armor.clear()
	for i in range(ARMOR_SIZE): armor.append(null)

func reset() -> void:
	player_db_id = ""
	active_hotbar_index = 0
	_initialize_slots()
	recalculate_stats()
	inventory_updated.emit()
	active_slot_changed.emit(active_hotbar_index)
	print("[InventoryManager] Inventory reset.")

func load_inventory(db_id: String, initial_data: Dictionary) -> void:
	player_db_id = db_id
	
	if initial_data.has("hotbar"): hotbar = initial_data["hotbar"]
	if initial_data.has("bag"): bag = initial_data["bag"]
	if initial_data.has("armor"): armor = initial_data["armor"]
	
	if hotbar.size() != HOTBAR_SIZE: _initialize_slots()
	
	recalculate_stats()
	inventory_updated.emit()
	active_slot_changed.emit(active_hotbar_index)
	print("[InventoryManager] Loaded slot-based inventory for: ", db_id)

func set_active_slot(index: int) -> void:
	if index >= 0 and index < HOTBAR_SIZE:
		active_hotbar_index = index
		active_slot_changed.emit(active_hotbar_index)

func get_active_item() -> Variant:
	return hotbar[active_hotbar_index]

## Attempts to add an item to the first available slot (Hotbar then Bag)
func add_item(item_id: String, quantity: int = 1) -> bool:
	var item_data = ItemDB.get_item(item_id)
	if not item_data: return false

	if item_data.stackable:
		for i in range(HOTBAR_SIZE):
			if hotbar[i] and hotbar[i].id == item_id:
				hotbar[i].quantity += quantity
				_sync_and_emit()
				return true
				
	for i in range(HOTBAR_SIZE):
		if hotbar[i] == null:
			hotbar[i] = {"id": item_id, "quantity": quantity}
			_sync_and_emit()
			return true

	if item_data.stackable:
		for i in range(BAG_SIZE):
			if bag[i] and bag[i].id == item_id:
				bag[i].quantity += quantity
				_sync_and_emit()
				return true

	for i in range(BAG_SIZE):
		if bag[i] == null:
			bag[i] = {"id": item_id, "quantity": quantity}
			_sync_and_emit()
			return true

	return false 

func recalculate_stats() -> void:
	total_stats = base_stats.duplicate()
	for slot in armor:
		if slot:
			var data = ItemDB.get_item(slot.id)
			if data:
				for stat in data.stats:
					total_stats[stat] += data.stats[stat]
	print("[InventoryManager] Stats recalculated: ", total_stats)

func _sync_and_emit() -> void:
	inventory_updated.emit()
	if player_db_id != "":
		PBHelper.request_sync_inventory(player_db_id, {
			"hotbar": hotbar,
			"bag": bag,
			"armor": armor
		})

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
		
	_sync_and_emit()
	
	# If we moved something in/out of the active slot, notify systems
	if (from_type == "hotbar" and from_idx == active_hotbar_index) or \
	   (to_type == "hotbar" and to_idx == active_hotbar_index):
		active_slot_changed.emit(active_hotbar_index)

func _get_array_by_type(type: String) -> Variant:
	match type:
		"hotbar": return hotbar
		"bag": return bag
		"armor": return armor
	return null
