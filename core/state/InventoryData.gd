extends Resource
class_name InventoryData

signal inventory_updated
signal active_slot_changed(index: int)

const HOTBAR_SIZE = 10
const BAG_SIZE = 30
const ARMOR_SIZE = 4

@export var hotbar: Array[ItemStackData] = []
@export var bag: Array[ItemStackData] = []
@export var armor: Array[ItemStackData] = []
@export var active_hotbar_index: int = 0

func _init() -> void:
	pass

func _initialize_slots() -> void:
	hotbar.clear()
	hotbar.resize(HOTBAR_SIZE)
	hotbar.fill(null)
	
	bag.clear()
	bag.resize(BAG_SIZE)
	bag.fill(null)
	
	armor.clear()
	armor.resize(ARMOR_SIZE)
	armor.fill(null)

func load_from_dict(data: Dictionary) -> void:
	if data.has("hotbar"): _load_array(hotbar, data["hotbar"], HOTBAR_SIZE)
	if data.has("bag"): _load_array(bag, data["bag"], BAG_SIZE)
	if data.has("armor"): _load_array(armor, data["armor"], ARMOR_SIZE)
	if data.has("active_hotbar_index"): 
		active_hotbar_index = data["active_hotbar_index"]
		active_slot_changed.emit(active_hotbar_index)
	inventory_updated.emit()

func _load_array(target: Array[ItemStackData], source: Array, size: int) -> void:
	for i in range(min(source.size(), size)):
		if source[i] != null and source[i] is Dictionary:
			target[i] = ItemStackData.from_dict(source[i])
		else:
			target[i] = null

func to_dict() -> Dictionary:
	return {
		"hotbar": hotbar.map(func(i): return i.to_dict() if i else null),
		"bag": bag.map(func(i): return i.to_dict() if i else null),
		"armor": armor.map(func(i): return i.to_dict() if i else null),
		"active_hotbar_index": active_hotbar_index
	}

func get_active_item() -> ItemStackData:

	if active_hotbar_index >= 0 and active_hotbar_index < hotbar.size():
		return hotbar[active_hotbar_index]
	return null

func set_active_slot(index: int) -> void:
	if index >= 0 and index < HOTBAR_SIZE:
		active_hotbar_index = index
		active_slot_changed.emit(active_hotbar_index)
