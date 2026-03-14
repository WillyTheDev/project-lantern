extends Resource
class_name ItemStackData

@export var id: String = ""
@export var quantity: int = 1

func _init(_id: String = "", _quantity: int = 1) -> void:
	id = _id
	quantity = _quantity

func to_dict() -> Dictionary:
	return {"id": id, "quantity": quantity}

static func from_dict(dict: Dictionary) -> ItemStackData:
	if dict.is_empty() or not dict.has("id"): return null
	return ItemStackData.new(dict.get("id", ""), dict.get("quantity", 1))
