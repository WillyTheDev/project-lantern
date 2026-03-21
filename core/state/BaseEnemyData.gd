extends Resource
class_name BaseEnemyData

@export var name: String = "Enemy"
@export var health: float = 100.0
@export var damage: float = 10.0
@export var movement_speed: float = 3.0
@export var experience_reward: int = 50

## Array of Dictionaries defining possible loot.
## Format: {"item_id": String, "drop_chance": float} OR {"item_type": ItemData.Type, "drop_chance": float} OR {"is_procedural": true, "drop_chance": float}
## Example Types: 0 = WEAPON, 1 = ARMOR, 2 = CONSUMABLE
@export var loot_table: Array[Dictionary] = [
	{"item_type": ItemData.Type.WEAPON, "drop_chance": 0.4, "min_quantity": 1, "max_quantity": 1},
	{"is_procedural": true, "drop_chance": 0.4},
	{"item_id": "lantern", "drop_chance": 0.1, "min_quantity": 1, "max_quantity": 1}
]
