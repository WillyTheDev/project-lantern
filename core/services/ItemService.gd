extends Node

## ItemService
## Central registry for all items in the game.

var items: Dictionary = {}

func _ready() -> void:
	_register_items()

func _register_items() -> void:
	var default_icon = load("res://icon.svg")

	# --- UTILITIES ---
	var lantern = ItemData.new()
	lantern.id = "lantern"
	lantern.name = "Old Lantern"
	lantern.description = "Provides light in the dark. Left-Click to toggle."
	lantern.type = ItemData.Type.UTILITY
	lantern.item_icon_texture = default_icon
	lantern.stackable = false
	# Load the clean scene from disk
	lantern.item_scene = load("res://scenes/items/lantern/Lantern.tscn")
	_add_item(lantern)

	# --- WEAPONS ---
	var sword = ItemData.new()
	sword.id = "rusty_sword"
	sword.name = "Rusty Sword"
	sword.description = "A basic blade."
	sword.type = ItemData.Type.WEAPON
	sword.item_icon_texture = default_icon
	sword.item_scene = load("res://scenes/items/weapons/RustySword.tscn")
	sword.stat_modifiers["strength"] = 2
	sword.stackable = false
	_add_item(sword)

	var bow = ItemData.new()
	bow.id = "wooden_bow"
	bow.name = "Wooden Bow"
	bow.description = "A simple bow."
	bow.type = ItemData.Type.RANGED
	bow.hand_type = ItemData.HandType.TWO_HANDED
	bow.item_icon_texture = default_icon
	bow.item_scene = load("res://scenes/items/weapons/WoodenBow.tscn")
	bow.projectile_scene = load("res://scenes/items/weapons/DumbProjectile.tscn")
	bow.attachment_bone = "RangedBoneAttachment"
	bow.stackable = false
	_add_item(bow)

	var shield = ItemData.new()
	shield.id = "wooden_shield"
	shield.name = "Wooden Shield"
	shield.description = "A basic wooden shield."
	shield.type = ItemData.Type.ARMOR
	shield.armor_slot = ItemData.ArmorSlot.OFFHAND
	shield.item_icon_texture = default_icon
	shield.item_scene = load("res://scenes/items/weapons/Shield.tscn")
	shield.attachment_bone = "ShieldBoneAttachment"
	shield.stat_modifiers["stamina"] = 5
	shield.stackable = false
	_add_item(shield)

	var staff = ItemData.new()
	staff.id = "magic_staff"
	staff.name = "Magic Staff"
	staff.description = "A mysterious staff."
	staff.type = ItemData.Type.MAGIC
	staff.hand_type = ItemData.HandType.TWO_HANDED
	staff.item_icon_texture = default_icon
	staff.item_scene = load("res://scenes/items/weapons/MagicStaff.tscn")
	staff.projectile_scene = load("res://scenes/items/weapons/MagicMissile.tscn")
	staff.attachment_bone = "RangedBoneAttachment"
	staff.stackable = false
	_add_item(staff)

	# --- ARMOR ---
	var helm = ItemData.new()
	helm.id = "leather_cap"
	helm.name = "Leather Cap"
	helm.type = ItemData.Type.ARMOR
	helm.armor_slot = ItemData.ArmorSlot.HEAD
	helm.item_icon_texture = default_icon
	helm.stat_modifiers["stamina"] = 5
	helm.stackable = false
	# --- PROCEDURAL BASES ---
	_register_procedural_base("base_head", "Helmet", ItemData.ArmorSlot.HEAD)
	_register_procedural_base("base_chest", "Chestplate", ItemData.ArmorSlot.CHEST)
	_register_procedural_base("base_legs", "Leggings", ItemData.ArmorSlot.LEGS)
	_register_procedural_base("base_feet", "Boots", ItemData.ArmorSlot.FEET)

func _register_procedural_base(p_id: String, p_name: String, p_slot: ItemData.ArmorSlot) -> void:
	var item = ItemData.new()
	item.id = p_id
	item.name = p_name
	item.type = ItemData.Type.ARMOR
	item.armor_slot = p_slot
	item.item_icon_texture = load("res://icon.svg") # Placeholder
	item.stackable = false
	_add_item(item)

func _add_item(item: ItemData) -> void:
	items[item.id] = item

func get_item(id: String) -> ItemData:
	return items.get(id, null)

## Returns a filtered list of all registered item IDs that match a specific type.
## Useful for category-based random loot generation.
##
## @param type: The ItemData.Type enum value to filter by.
## @return: An Array of String IDs.
func get_item_ids_by_type(type: ItemData.Type) -> Array[String]:
	var result: Array[String] = []
	for id in items:
		var item = items[id]
		if item.type == type:
			result.append(id)
	return result
