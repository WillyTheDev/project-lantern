extends Resource
class_name PlayerStatsData

signal stats_changed

@export var agility: int = 10: set = _set_agility
@export var strength: int = 10: set = _set_strength
@export var intellect: int = 10: set = _set_intellect
@export var stamina: int = 10: set = _set_stamina

@export var level: int = 1: set = _set_level
@export var experience: int = 0: set = _set_experience
@export var available_points: int = 0: set = _set_available_points

@export var max_health: float = 100.0
@export var current_health: float = 100.0: set = _set_health

@export var max_mana: float = 100.0
@export var current_mana: float = 100.0: set = _set_mana

func _set_agility(val: int) -> void: agility = val; stats_changed.emit()
func _set_strength(val: int) -> void: strength = val; stats_changed.emit()
func _set_intellect(val: int) -> void: intellect = val; stats_changed.emit()
func _set_stamina(val: int) -> void: 
	stamina = val
	# Logic delegated to LevelManager but we still update local representation
	max_health = 100.0 + (stamina - 10) * 10.0
	stats_changed.emit()

func _set_available_points(val: int) -> void:
	available_points = val
	stats_changed.emit()

func _set_health(val: float) -> void:
	current_health = clamp(val, 0, max_health)
	stats_changed.emit()

func _set_mana(val: float) -> void:
	current_mana = clamp(val, 0, max_mana)
	stats_changed.emit()

func _set_level(val: int) -> void:
	level = val
	stats_changed.emit()

func _set_experience(val: int) -> void:
	experience = val
	stats_changed.emit()

func to_dict() -> Dictionary:
	return {
		"agility": agility,
		"strength": strength,
		"intellect": intellect,
		"stamina": stamina,
		"level": level,
		"experience": experience,
		"available_points": available_points,
		"current_mana": current_mana
	}

func from_dict(data: Dictionary) -> void:
	agility = data.get("agility", 10)
	strength = data.get("strength", 10)
	intellect = data.get("intellect", 10)
	stamina = data.get("stamina", 10)
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	available_points = data.get("available_points", 0)
	current_health = max_health
	max_mana = 100.0 + (intellect - 10) * 10.0
	current_mana = data.get("current_mana", max_mana)

func reset() -> void:
	agility = 10
	strength = 10
	intellect = 10
	stamina = 10
	level = 1
	experience = 0
	available_points = 0
	current_health = max_health
	max_mana = 100.0
	current_mana = max_mana
