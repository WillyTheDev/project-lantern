extends PanelContainer

@onready var icon_rect: TextureRect = %Icon
@onready var quantity_label: Label = %QuantityLabel

var slot_index: int = -1
var inventory_type: String = "" # "hotbar", "bag", or "armor"
var is_highlighted: bool = false

func set_item(item_id: String, quantity: int) -> void:
	if item_id == "":
		icon_rect.texture = null
		quantity_label.text = ""
		return
		
	var data = ItemDB.get_item(item_id)
	if data:
		icon_rect.texture = data.item_icon_texture
		quantity_label.text = str(quantity) if quantity > 1 else ""
	else:
		icon_rect.texture = null
		quantity_label.text = ""

func highlight(enabled: bool) -> void:
	is_highlighted = enabled
	# We use a custom style override to ensure we don't modify the shared resource
	var sb = get_theme_stylebox("panel").duplicate()
	if sb is StyleBoxFlat:
		if enabled:
			sb.border_color = Color(0.92, 0.63, 0.26, 1.0) # Golden
			sb.set_border_width_all(4)
			# We add content margin so the icon shrinks inside the border instead of being covered
			sb.content_margin_left = 4
			sb.content_margin_top = 4
			sb.content_margin_right = 4
			sb.content_margin_bottom = 4
		else:
			remove_theme_stylebox_override("panel")
			return
			
		add_theme_stylebox_override("panel", sb)

func clear() -> void:
	icon_rect.texture = null
	quantity_label.text = ""

# --- Drag and Drop Implementation ---

func _get_drag_data(_at_position: Vector2) -> Variant:
	var item = _get_my_item_data()
	if not item: return null
	
	# Create visual preview
	var preview = TextureRect.new()
	var data = ItemDB.get_item(item.id)
	preview.texture = data.item_icon_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(64, 64)
	set_drag_preview(preview)
	
	return {
		"origin_slot": slot_index,
		"origin_type": inventory_type,
		"item_id": item.id,
		"quantity": item.quantity
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary: return false
	
	# Check for armor slot compatibility
	if inventory_type == "armor":
		var item_data = ItemDB.get_item(data.item_id)
		if not item_data or item_data.type != ItemData.Type.ARMOR:
			return false
		
		# Map slot index to ItemData.ArmorSlot
		# 0: Head, 1: Chest, 2: Legs, 3: Feet
		var required_slot = ItemData.ArmorSlot.NONE
		match slot_index:
			0: required_slot = ItemData.ArmorSlot.HEAD
			1: required_slot = ItemData.ArmorSlot.CHEST
			2: required_slot = ItemData.ArmorSlot.LEGS
			3: required_slot = ItemData.ArmorSlot.FEET
			
		if item_data.armor_slot != required_slot:
			return false
			
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	InventoryManager.move_item(
		data.origin_type, data.origin_slot,
		inventory_type, slot_index
	)

func _get_my_item_data() -> Variant:
	match inventory_type:
		"hotbar": return InventoryManager.hotbar[slot_index]
		"bag": return InventoryManager.bag[slot_index]
		"armor": return InventoryManager.armor[slot_index]
	return null
