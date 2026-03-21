extends Control

@onready var bag_grid: GridContainer = %BagGrid
@onready var hotbar_grid: GridContainer = %HotbarGrid
@onready var armor_grid: GridContainer = %ArmorGrid
@onready var hud_grid: GridContainer = %HUDGrid
@onready var stats_label: Label = %StatsLabel
@onready var inventory_overlay: Control = %InventoryOverlay
@onready var hotbar_hud: Control = %HotbarHUD
@onready var tooltip_container: Control = %TooltipContainer
@onready var external_section: VBoxContainer = %ExternalSection
@onready var external_grid: GridContainer = %ExternalGrid

const SLOT_SCENE = preload("res://ui/inventory/InventorySlot.tscn")
const TOOLTIP_SCENE = preload("res://ui/inventory/ItemTooltip.tscn")

var is_local_authority: bool = false
var current_tooltip: Control = null
var external_slot_count: int = 0
var player_ref: Node3D = null

# Dynamic UI Elements
var xp_bar: ProgressBar
var mana_bar: ProgressBar
var stats_grid: GridContainer
var stat_labels: Dictionary = {}
var stat_buttons: Dictionary = {}

func _ready() -> void:
	_setup_slots()
	_setup_dynamic_ui()
	# Global service signals via EventBus
	EventBus.external_inventory_updated.connect(_on_external_inventory_updated)
	EventBus.total_stats_updated.connect(_on_total_stats_updated)
	
	inventory_overlay.visible = false
	external_section.visible = false
	hotbar_hud.visible = true
	visible = false

## Binds the UI signals to a specific player instance (usually the local authority player).
## Attaches callbacks for inventory modification and stat changes.
##
## @param player: The local Player node instance.
func initialize_for_player(player: Node3D) -> void:
	if player_ref:
		player_ref.inventory.inventory_updated.disconnect(refresh)
		player_ref.inventory.active_slot_changed.disconnect(_on_active_slot_changed)
		player_ref.stats.stats_changed.disconnect(_on_base_stats_updated)

	player_ref = player
	player_ref.inventory.inventory_updated.connect(refresh)
	player_ref.inventory.active_slot_changed.connect(_on_active_slot_changed)
	player_ref.stats.stats_changed.connect(_on_base_stats_updated)

	refresh()
	_on_base_stats_updated()
	_on_active_slot_changed(player_ref.inventory.active_hotbar_index)

func _on_base_stats_updated() -> void:
	_update_stats_label()

func _on_total_stats_updated(_total_stats: Dictionary) -> void:
	if not is_local_authority: return
	_update_stats_label()

func _setup_dynamic_ui() -> void:
	# 1. Setup HUD Bars (XP and Mana)
	var bar_container = VBoxContainer.new()
	bar_container.custom_minimum_size = Vector2(300, 40)
	bar_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar_container.position = Vector2(20, -60)
	hotbar_hud.add_child(bar_container)
	
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(300, 15)
	xp_bar.show_percentage = true
	var sb_xp = StyleBoxFlat.new()
	sb_xp.bg_color = Color(0.6, 0.2, 0.8)
	xp_bar.add_theme_stylebox_override("fill", sb_xp)
	bar_container.add_child(xp_bar)
	
	mana_bar = ProgressBar.new()
	mana_bar.custom_minimum_size = Vector2(300, 15)
	mana_bar.show_percentage = true
	var sb_mana = StyleBoxFlat.new()
	sb_mana.bg_color = Color(0.2, 0.4, 0.9)
	mana_bar.add_theme_stylebox_override("fill", sb_mana)
	bar_container.add_child(mana_bar)
	
	# 2. Setup Stats Grid
	stats_grid = GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 10)
	stats_grid.add_theme_constant_override("v_separation", 5)
	
	var left_section = stats_label.get_parent()
	left_section.add_child(stats_grid)
	
	var stat_names = ["strength", "agility", "intellect", "stamina"]
	for s_name in stat_names:
		var name_lbl = Label.new()
		name_lbl.text = s_name.to_upper() + ":"
		stats_grid.add_child(name_lbl)
		
		var val_lbl = Label.new()
		val_lbl.text = "10"
		stat_labels[s_name] = val_lbl
		stats_grid.add_child(val_lbl)
		
		var btn = Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(24, 24)
		btn.pressed.connect(_on_stat_button_pressed.bind(s_name))
		stat_buttons[s_name] = btn
		stats_grid.add_child(btn)

func _on_stat_button_pressed(stat_name: String) -> void:
	InventoryService.request_spend_attribute_point(stat_name)

## Calculates text formatting and updates the visual UI labels for player stats.
func _update_stats_label() -> void:
	if not player_ref: return
	var stats = player_ref.stats
	var total_agi = InventoryService.get_total_agility()
	var total_str = InventoryService.get_total_strength()
	var total_int = InventoryService.get_total_intellect()
	var total_sta = InventoryService.get_total_stamina()
	
	# Update top labels
	stats_label.text = "LVL: %d\nXP: %d / %d\nPOINTS: %d" % [
		stats.level, stats.experience, LevelManager.get_experience_for_level(stats.level + 1), stats.available_points
	]
	
	# Update Grid
	stat_labels["strength"].text = str(total_str)
	stat_labels["agility"].text = str(total_agi)
	stat_labels["intellect"].text = str(total_int)
	stat_labels["stamina"].text = str(total_sta)
	
	for s_name in stat_buttons.keys():
		stat_buttons[s_name].visible = (stats.available_points > 0)
		
	# Update HUD Bars
	if is_instance_valid(xp_bar):
		var next_xp = LevelManager.get_experience_for_level(stats.level + 1)
		var prev_xp = LevelManager.get_experience_for_level(stats.level) if stats.level > 1 else 0
		xp_bar.min_value = prev_xp
		xp_bar.max_value = next_xp
		xp_bar.value = stats.experience
		
	if is_instance_valid(mana_bar):
		var total_mana = InventoryManager.recalculate_stats(player_ref).get("max_mana", 100.0)
		mana_bar.max_value = total_mana
		mana_bar.value = stats.current_mana

func _on_external_inventory_updated() -> void:
	if not is_local_authority: return
	
	var new_count = InventoryService.external_inventory.size()
	if new_count > 0:
		if new_count != external_slot_count:
			_setup_external_slots(new_count)
		external_section.visible = true
		inventory_overlay.visible = true
		hotbar_hud.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# Update title if it's a stash
		var title = external_section.get_node_or_null("Title")
		if title:
			title.text = "STASH" if InventoryService.current_external_type == "stash" else "LOOT"
	else:
		external_section.visible = false
		external_slot_count = 0
		for child in external_grid.get_children(): child.queue_free()
	refresh()

## Dynamically instantiates UI slots for external container interfaces based on the container size.
##
## @param count: The number of interaction slots available.
func _setup_external_slots(count: int) -> void:
	for child in external_grid.get_children(): child.queue_free()
	external_slot_count = count
	for i in range(count):
		var slot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.inventory_type = InventoryService.current_external_type
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_mouse_exited)
		external_grid.add_child(slot)

## Forces a full visual synchronization of all visible inventory slots based on the underlying player references.
func refresh() -> void:
	if not is_inside_tree() or not player_ref: return
	var data = player_ref.inventory
	if not data: return
	
	for i in range(InventoryData.BAG_SIZE):
		var slot = bag_grid.get_child(i)
		slot.set_item_stack(data.bag[i])
		
	for i in range(InventoryData.HOTBAR_SIZE):
		var slot = hotbar_grid.get_child(i)
		var h_slot = hud_grid.get_child(i)
		slot.set_item_stack(data.hotbar[i])
		h_slot.set_item_stack(data.hotbar[i])
		
	for i in range(InventoryData.ARMOR_SIZE):
		var slot = armor_grid.get_child(i)
		slot.set_item_stack(data.armor[i])
		
	if external_section.visible:
		var ext_data = []
		if InventoryService.current_external_type == "stash":
			ext_data = player_ref.stash.items
		else:
			ext_data = InventoryService.external_inventory
			
		for i in range(external_grid.get_child_count()):
			var slot = external_grid.get_child(i)
			if i < ext_data.size():
				slot.set_item_stack(ext_data[i])
			else:
				slot.clear()

func _on_active_slot_changed(index: int) -> void:
	for i in range(hud_grid.get_child_count()):
		var slot = hud_grid.get_child(i)
		if slot.has_method("highlight"):
			slot.highlight(i == index)

## Instantiates and maps all persistent UI slots (hotbar, bag, armor) to memory and the screen.
func _setup_slots() -> void:
	for i in range(InventoryData.BAG_SIZE):
		var slot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.inventory_type = "bag"
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_mouse_exited)
		bag_grid.add_child(slot)
		
	for i in range(InventoryData.HOTBAR_SIZE):
		var slot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.inventory_type = "hotbar"
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_mouse_exited)
		hotbar_grid.add_child(slot)
		
		var h_slot = SLOT_SCENE.instantiate()
		h_slot.slot_index = i
		h_slot.inventory_type = "hotbar"
		h_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_grid.add_child(h_slot)
		
	for i in range(InventoryData.ARMOR_SIZE):
		var slot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.inventory_type = "armor"
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_mouse_exited)
		armor_grid.add_child(slot)

func _on_slot_mouse_entered(slot: Control) -> void:
	var item = slot.get_item_stack()
	if not item: return
	if current_tooltip: current_tooltip.queue_free()
	current_tooltip = TOOLTIP_SCENE.instantiate()
	tooltip_container.add_child(current_tooltip)
	current_tooltip.display(item)
	_update_tooltip_pos()

func _on_slot_mouse_exited() -> void:
	if current_tooltip:
		current_tooltip.queue_free()
		current_tooltip = null

func _process(_delta: float) -> void:
	if current_tooltip: _update_tooltip_pos()

func _update_tooltip_pos() -> void:
	if current_tooltip: current_tooltip.global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if not is_local_authority: return
	
	# Allow 'I' to toggle, and 'E' or 'ESC' to close if already open
	var is_inventory_toggle = event.is_action_pressed("inventory")
	var is_interact_close = inventory_overlay.visible and event.is_action_pressed("interact")
	var is_esc_close = inventory_overlay.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
	
	if is_inventory_toggle or is_interact_close or is_esc_close:
		# Consume the event so it doesn't trigger interactions or open settings menu
		get_viewport().set_input_as_handled()
		
		inventory_overlay.visible = !inventory_overlay.visible
		hotbar_hud.visible = !inventory_overlay.visible
		
		if current_tooltip: _on_slot_mouse_exited()
		
		if inventory_overlay.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			refresh()
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			if external_section.visible: 
				InventoryService.close_external_inventory()
