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
	sword.description = "A basic blade. Left-click to attack."
	sword.type = ItemData.Type.WEAPON
	sword.item_icon_texture = default_icon
	sword.item_scene = load("res://scenes/items/weapons/RustySword.tscn")
	sword.stats["strength"] = 2
	sword.stackable = false
	_add_item(sword)

	var bow = ItemData.new()
	bow.id = "wooden_bow"
	bow.name = "Wooden Bow"
	bow.description = "A simple bow. Hold Left-click to aim, release to shoot."
	bow.type = ItemData.Type.RANGED
	bow.item_icon_texture = default_icon
	bow.item_scene = load("res://scenes/items/weapons/WoodenBow.tscn")
	bow.projectile_scene = load("res://scenes/items/weapons/DumbProjectile.tscn")
	bow.attachment_bone = "RangedBoneAttachment"
	bow.stackable = false
	_add_item(bow)

	var staff = ItemData.new()
	staff.id = "magic_staff"
	staff.name = "Magic Staff"
	staff.description = "A mysterious staff. Hold Left-click to charge a spell."
	staff.type = ItemData.Type.MAGIC
	staff.item_icon_texture = default_icon
	staff.item_scene = load("res://scenes/items/weapons/MagicStaff.tscn")
	staff.projectile_scene = load("res://scenes/items/weapons/DumbProjectile.tscn")
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
	helm.stats["stamina"] = 5
	helm.stackable = false
	_add_item(helm)

func _add_item(item: ItemData) -> void:
	items[item.id] = item

func get_item(id: String) -> ItemData:
	return items.get(id)
