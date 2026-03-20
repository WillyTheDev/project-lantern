extends Resource
class_name ItemData

enum Type { WEAPON, ARMOR, CONSUMABLE, UTILITY, LOOT, RANGED, MAGIC }
enum ArmorSlot { NONE, HEAD, CHEST, LEGS, FEET }

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var type: Type = Type.LOOT
@export var armor_slot: ArmorSlot = ArmorSlot.NONE
@export var item_icon_texture: Texture2D
@export var item_scene: PackedScene # Scene to spawn when dropped or equipped
@export var projectile_scene: PackedScene # The visual projectile for ranged/magic attacks
@export var projectile_speed: float = 25.0
@export var attachment_bone: String = "SwordBoneAttachment" # Bone attachment node name to mount the item to
@export var stackable: bool = true
@export var max_stack: int = 99
@export var use_animation: String = "pickUp" # Default animation for using/consuming

## Stats: agility, strength, intellect, stamina
@export var stats: Dictionary = {
	"agility": 0,
	"strength": 0,
	"intellect": 0,
	"stamina": 0
}
