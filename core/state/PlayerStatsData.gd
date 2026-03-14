extends Resource
class_name PlayerStatsData

signal stats_changed
signal leveled_up(new_level: int)

@export var agility: int = 10: set = _set_agility
@export var strength: int = 10: set = _set_strength
@export var intellect: int = 10: set = _set_intellect
@export var stamina: int = 10: set = _set_stamina

@export var level: int = 1: set = _set_level
@export var experience: int = 0: set = _set_experience

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

func _set_level(val: int) -> void:
	level = val
	stats_changed.emit()

func _set_experience(val: int) -> void:
	experience = val
	var xp_needed = get_experience_for_level(level + 1)
	while experience >= xp_needed:
		level_up()
		xp_needed = get_experience_for_level(level + 1)
	stats_changed.emit()

func get_experience_for_level(target_level: int) -> int:
	return int(pow(target_level, 1.5) * 100)

func level_up() -> void:
	level += 1
	# Automatic stat increases on level up
	agility += 2
	strength += 2
	intellect += 2
	stamina += 2
	current_health = max_health
	leveled_up.emit(level)
	print("[PlayerStatsData] Level Up! Now level ", level)

func to_dict() -> Dictionary:
	return {
		"agility": agility,
		"strength": strength,
		"intellect": intellect,
		"stamina": stamina,
		"level": level,
		"experience": experience
	}

func from_dict(data: Dictionary) -> void:
	agility = data.get("agility", 10)
	strength = data.get("strength", 10)
	intellect = data.get("intellect", 10)
	stamina = data.get("stamina", 10)
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	current_health = max_health

func reset() -> void:
	agility = 10
	strength = 10
	intellect = 10
	stamina = 10
	level = 1
	experience = 0
	current_health = max_health
