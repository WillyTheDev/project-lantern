extends Resource
class_name PlayerStats

signal stats_changed

@export var agility: int = 10: set = _set_agility
@export var strength: int = 10: set = _set_strength
@export var intellect: int = 10: set = _set_intellect
@export var stamina: int = 10: set = _set_stamina

@export var max_health: float = 100.0
@export var current_health: float = 100.0: set = _set_health

func _set_agility(val: int) -> void: agility = val; stats_changed.emit()
func _set_strength(val: int) -> void: strength = val; stats_changed.emit()
func _set_intellect(val: int) -> void: intellect = val; stats_changed.emit()
func _set_stamina(val: int) -> void: 
	stamina = val
	max_health = 100.0 + (stamina - 10) * 10.0
	stats_changed.emit()

func _set_health(val: float) -> void:
	current_health = clamp(val, 0, max_health)
	stats_changed.emit()

func to_dict() -> Dictionary:
	return {
		"agility": agility,
		"strength": strength,
		"intellect": intellect,
		"stamina": stamina
	}

func reset() -> void:
	agility = 10
	strength = 10
	intellect = 10
	stamina = 10
	current_health = max_health
