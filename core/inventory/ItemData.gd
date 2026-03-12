extends Resource
class_name ItemData

enum Type { WEAPON, ARMOR, CONSUMABLE, UTILITY, LOOT }
enum ArmorSlot { NONE, HEAD, CHEST, LEGS, FEET }

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var type: Type = Type.LOOT
@export var armor_slot: ArmorSlot = ArmorSlot.NONE
@export var item_icon_texture: Texture2D
@export var item_scene: PackedScene # Scene to spawn when dropped or equipped
@export var stackable: bool = true
@export var max_stack: int = 99

## Stats: agility, strength, intellect, stamina
@export var stats: Dictionary = {
	"agility": 0,
	"strength": 0,
	"intellect": 0,
	"stamina": 0
}
