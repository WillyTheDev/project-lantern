extends Resource
class_name ItemStackData

@export var id: String = ""
@export var quantity: int = 1
@export var custom_data: Dictionary = {}

func _init(_id: String = "", _quantity: int = 1, _custom_data: Dictionary = {}) -> void:
	id = _id
	quantity = _quantity
	custom_data = _custom_data

func to_dict() -> Dictionary:
	return {
		"id": id,
		"quantity": quantity,
		"custom_data": custom_data.duplicate(true)
	}

static func from_dict(dict: Dictionary) -> ItemStackData:
	if dict.is_empty() or not dict.has("id"): return null
	return ItemStackData.new(
		dict.get("id", ""),
		dict.get("quantity", 1),
		dict.get("custom_data", {})
	)
