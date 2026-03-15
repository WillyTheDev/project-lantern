extends Resource
class_name StashData

signal inventory_updated

const STASH_SIZE = 30

@export var items: Array[ItemStackData] = []

func _init() -> void:
	pass

func _initialize_slots() -> void:
	items.clear()
	items.resize(STASH_SIZE)
	items.fill(null)

func load_from_dict(data: Dictionary) -> void:
	# Support both old format (if it was nested InventoryData) and new 'items' format
	var source = []
	if data.has("items"):
		source = data["items"]
	elif data.has("bag"): # Legacy fallback
		source = data["bag"]
		
	for i in range(min(source.size(), STASH_SIZE)):
		if source[i] != null and source[i] is Dictionary:
			items[i] = ItemStackData.from_dict(source[i])
		else:
			items[i] = null
			
	inventory_updated.emit()

func to_dict() -> Dictionary:
	return {
		"items": items.map(func(i): return i.to_dict() if i else null)
	}
