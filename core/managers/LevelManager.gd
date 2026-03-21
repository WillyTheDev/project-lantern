class_name LevelManager
extends Object

## LevelManager (Manager)
## Stateless logic for Leveling, Experience, and Max HP calculations.

const MAX_LEVEL: int = 20
const POINTS_PER_LEVEL: int = 3

static func calculate_max_hp(stamina: int) -> float:
	return 100.0 + (stamina - 10) * 10.0

static func get_experience_for_level(target_level: int) -> int:
	return int(pow(target_level, 1.5) * 100)

## Adds experience to PlayerStatsData. Handles level ups.
## Returns true if a level up occurred.
static func add_experience(stats: PlayerStatsData, amount: int) -> bool:
	if stats.level >= MAX_LEVEL:
		return false
		
	stats.experience += amount
	var leveled_up = false
	
	var xp_needed = get_experience_for_level(stats.level + 1)
	while stats.experience >= xp_needed and stats.level < MAX_LEVEL:
		stats.level += 1
		stats.available_points += POINTS_PER_LEVEL
		leveled_up = true
		if stats.level >= MAX_LEVEL:
			# Prevent overflow past max level
			stats.experience = get_experience_for_level(MAX_LEVEL)
			break
		xp_needed = get_experience_for_level(stats.level + 1)
		
	return leveled_up

## Spends an available attribute point on the requested attribute.
static func spend_attribute_point(stats: PlayerStatsData, attribute: String) -> bool:
	if stats.available_points <= 0:
		return false
		
	match attribute:
		"agility": stats.agility += 1
		"strength": stats.strength += 1
		"intellect": stats.intellect += 1
		"stamina": stats.stamina += 1
		_: return false
		
	stats.available_points -= 1
	return true
