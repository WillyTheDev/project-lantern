extends RefCounted
class_name LootGenerator

## LootGenerator
## Responsible for creating items dynamically, considering player Luck,
## and attaching secondary stat modifiers exclusively to Epic items.

## Potential secondary modifiers that can roll on Epic gear
const MODIFIER_POOL = [
	"vampirism",          # percentage life steal on hit
	"scale_multiplier",   # visual/hitbox scale
	"speed",              # movement speed multiplier
	"knockback_bonus",    # extra force multiplier
	"extra_jumps",        # adds double-jump, triple-jump etc.
	"mana_regen",         # flat or percentage mana regenerated per sec
	"health_regen",       # flat or percentage health regenerated per sec
	"thorns",             # reflect damage percentage
	"luck",               # magic find / epic drop odds
	"crit_multiplier",    # increases critical hit damage multiplier
	"cdr",                # cooldown reduction percentage
	"cleave",             # melee radius / hitbox scale
	"evasion",            # dodge chance percentage
	"multishot"           # extra projectiles fired natively
]

## Takes an Item ID and player luck to dynamically generate an ItemStackData
## Randomly assigns rarity based on luck. Modifiers only roll if the item becomes Epic.
##
## @param base_id: String identifier (e.g. "rusty_sword")
## @param luck: Float indicating luck status (increases Epic odds)
## @param quantity: Number of items (stacks)
static func generate_equipment(base_id: String, luck: float = 0.0, quantity: int = 1) -> ItemStackData:
	print("[LootGenerator] Generating equipment for ", base_id, " (Luck: ", luck, ")")
	return _generate_item_stack(base_id, luck, quantity)

## Generates a random item from a specific category (e.g. WEAPON, ARMOR).
##
## @param type: The ItemData.Type category to pick from.
## @param luck: Global luck modifier from the player.
## @param quantity: Stack size.
## @return: A newly generated ItemStackData with random rarity and modifiers.
static func generate_random_equipment(type: ItemData.Type, luck: float = 0.0, quantity: int = 1) -> ItemStackData:
	var ids = ItemService.get_item_ids_by_type(type)
	if ids.is_empty():
		print("[LootGenerator] WARNING: No items found for type ", type)
		# Fallback to a general equipment search if specific type is empty
		return null
		
	var chosen_id = ids[randi() % ids.size()]
	print("[LootGenerator] Selected random item from category ", type, ": ", chosen_id)
	return _generate_item_stack(chosen_id, luck, quantity)

## Completely generates an armor piece from "nothing" (procedural stats and names).
## Uses base_head, base_chest, etc. as visual/slot templates.
static func generate_procedural_armor(luck: float = 0.0) -> ItemStackData:
	var slots = [
		{"id": "base_head", "name": "Helmet"},
		{"id": "base_chest", "name": "Chestplate"},
		{"id": "base_legs", "name": "Leggings"},
		{"id": "base_feet", "name": "Boots"}
	]
	var base = slots[randi() % slots.size()]
	
	# 1. Roll Rarity
	var roll = randf() + (luck * 0.1)
	var chosen_rarity = ItemData.Rarity.COMMON
	var rarity_label = "Common"
	var stat_mult = 1.0
	
	if roll > 0.95:
		chosen_rarity = ItemData.Rarity.EPIC
		rarity_label = "Epic"
		stat_mult = 2.5
	elif roll > 0.70:
		chosen_rarity = ItemData.Rarity.RARE
		rarity_label = "Rare"
		stat_mult = 1.5
		
	# 2. Generate Procedural Name
	var prefixes = ["Ancient", "Rusty", "Shiny", "Heavy", "Light", "Enchanted", "Dark", "Holy"]
	var suffixes = ["the Bear", "the Eagle", "Protection", "Might", "Shadows", "the Void", "Stamina"]
	var p_name = "%s %s of %s" % [prefixes[randi() % prefixes.size()], base["name"], suffixes[randi() % suffixes.size()]]
	
	# 3. Generate Main Stats
	var custom_data = {
		"rarity": chosen_rarity,
		"name": p_name,
		"modifiers": {}
	}
	
	# Assign 1-2 primary stats focused on the slot (Stamina usually, plus a random offensive)
	var primary_pool = ["stamina", "strength", "agility", "intellect"]
	var num_primaries = 1 if chosen_rarity == ItemData.Rarity.COMMON else 2
	
	for i in range(num_primaries):
		var stat = primary_pool[i if i < primary_pool.size() else 0]
		var base_val = randi_range(2, 6)
		custom_data["modifiers"][stat] = int(base_val * stat_mult)
		
	# 4. Add Secondary Modifiers if Epic
	if chosen_rarity == ItemData.Rarity.EPIC:
		var secondary_mods = _generate_epic_modifiers()
		for mod in secondary_mods:
			custom_data["modifiers"][mod] = secondary_mods[mod]
			
	print("[LootGenerator] Generated Procedural Armor: ", p_name, " (", rarity_label, ")")
	return ItemStackData.new(base["id"], 1, custom_data)

## Internal shared logic for creating a stack from a base ID.
static func _generate_item_stack(base_id: String, luck: float, quantity: int) -> ItemStackData:
	var item_def = ItemService.get_item(base_id)
	if not item_def: 
		return null
		
	var custom_data = {}
	
	# Only equippable items roll rarity and stats
	if item_def.type in [ItemData.Type.WEAPON, ItemData.Type.ARMOR, ItemData.Type.RANGED, ItemData.Type.MAGIC]:
		var roll = randf() + (luck * 0.01) # Every point of luck is +1% chance for better rolls roughly
		
		var chosen_rarity = ItemData.Rarity.COMMON
		
		if roll > 0.95:
			chosen_rarity = ItemData.Rarity.EPIC
		elif roll > 0.70:
			chosen_rarity = ItemData.Rarity.RARE
			
		custom_data["rarity"] = chosen_rarity
		
		# 2. Scale Primary Stats for Rare/Epic
		var stat_mult = 1.0
		if chosen_rarity == ItemData.Rarity.RARE: stat_mult = 1.4
		if chosen_rarity == ItemData.Rarity.EPIC: stat_mult = 2.0
		
		if stat_mult > 1.0:
			custom_data["modifiers"] = {}
			for stat in item_def.stat_modifiers:
				var base_val = item_def.stat_modifiers[stat]
				custom_data["modifiers"][stat] = int(base_val * stat_mult) - base_val
				# We store the DIFFERENCE here so recalculate_stats (which sums base + mods) gets the total.
		
		# 3. Add Secondary Modifiers ONLY for Epic
		if chosen_rarity == ItemData.Rarity.EPIC:
			var secondary_mods = _generate_epic_modifiers()
			if not custom_data.has("modifiers"): custom_data["modifiers"] = {}
			for mod in secondary_mods:
				custom_data["modifiers"][mod] = secondary_mods[mod]
			
	return ItemStackData.new(base_id, quantity, custom_data)

## Internal logic to pick 1-3 random modifiers from the pool with randomized ranges
static func _generate_epic_modifiers() -> Dictionary:
	var modifiers = {}
	var num_mods = randi_range(1, 3)
	
	# Duplicate and shuffle to pick unique mods
	var available_mods = MODIFIER_POOL.duplicate()
	available_mods.shuffle()
	
	for i in range(mini(num_mods, available_mods.size())):
		var mod = available_mods[i]
		var value = _roll_value_for_modifier(mod)
		modifiers[mod] = value
		
	return modifiers

## Internal lookup table for bounded random values
static func _roll_value_for_modifier(mod: String) -> Variant:
	match mod:
		"vampirism": return randf_range(0.05, 0.15)        # 5% to 15% life steal
		"scale_multiplier": return randf_range(0.1, 0.3)   # +10% to +30% size
		"speed": return randf_range(0.1, 0.25)             # +10% to +25% speed
		"knockback_bonus": return randf_range(0.2, 1.0)    # +20% to +100% force
		"extra_jumps": return randi_range(1, 1)            # +1 jump
		"mana_regen": return randf_range(1.0, 5.0)         # +1 to 5 hp/s
		"health_regen": return randf_range(0.5, 2.0)       # +0.5 to 2 hp/s
		"thorns": return randf_range(0.1, 0.3)             # +10% to 30% reflect
		"luck": return randf_range(10.0, 30.0)             # +10 to 30 flat luck finding
		"crit_multiplier": return randf_range(0.25, 1.5)   # +0.25x to +1.5x crit damage
		"cdr": return randf_range(0.05, 0.25)              # 5% to 25% cooldown reduction
		"cleave": return randf_range(0.25, 1.0)            # +25% to 100% weapon size
		"evasion": return randf_range(0.05, 0.15)          # +5% to 15% dodge chance
		"multishot": return randi_range(1, 2)              # +1 or +2 extra arrows
	return 0.0
