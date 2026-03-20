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

func _ready() -> void:
	_setup_slots()
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
	_on_base_stats_updated(player_ref.stats)
	_on_active_slot_changed(player_ref.inventory.active_hotbar_index)

func _on_base_stats_updated(_stats: PlayerStatsData = null) -> void:
	_update_stats_label()

func _on_total_stats_updated(_total_stats: Dictionary) -> void:
	if not is_local_authority: return
	_update_stats_label()

## Calculates text formatting and updates the visual UI labels for player stats.
func _update_stats_label() -> void:
	if not player_ref: return
	var stats = player_ref.stats
	var total_agi = InventoryService.get_total_agility()
	var total_str = InventoryService.get_total_strength()
	var total_int = InventoryService.get_total_intellect()
	var total_sta = InventoryService.get_total_stamina()
	
	stats_label.text = "LVL: %d (XP: %d)\nSTR: %d\nAGI: %d\nINT: %d\nSTA: %d" % [
		stats.level, stats.experience, total_str, total_agi, total_int, total_sta
	]

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
	current_tooltip.display(item.id)
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
