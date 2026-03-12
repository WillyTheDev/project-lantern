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

func _ready() -> void:
	_setup_slots()
	InventoryManager.inventory_updated.connect(refresh)
	InventoryManager.active_slot_changed.connect(_on_active_slot_changed)
	InventoryManager.external_inventory_updated.connect(_on_external_inventory_updated)
	
	inventory_overlay.visible = false
	external_section.visible = false
	hotbar_hud.visible = true
	visible = true
	
	refresh()

func _on_external_inventory_updated() -> void:
	var new_count = InventoryManager.external_inventory.size()
	
	if new_count > 0:
		# Only rebuild if the slot count changed to avoid flickering and race conditions
		if new_count != external_slot_count:
			_setup_external_slots(new_count)
			
		external_section.visible = true
		inventory_overlay.visible = true
		hotbar_hud.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		external_section.visible = false
		external_slot_count = 0
		for child in external_grid.get_children():
			child.queue_free()
	
	refresh()

func _setup_external_slots(count: int) -> void:
	# Clear old slots
	for child in external_grid.get_children():
		child.queue_free()
	
	external_slot_count = count
	for i in range(count):
		var slot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.inventory_type = "external"
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_mouse_exited)
		external_grid.add_child(slot)

func refresh() -> void:
	if not is_inside_tree(): return
	
	# Safety check: Ensure grids exist
	if not bag_grid or not hotbar_grid: return
	
	for i in range(InventoryManager.BAG_SIZE):
		if i >= bag_grid.get_child_count(): break
		var slot = bag_grid.get_child(i)
		var data = InventoryManager.bag[i]
		if data: slot.set_item(data["id"], data["quantity"])
		else: slot.clear()
		
	for i in range(InventoryManager.HOTBAR_SIZE):
		if i >= hotbar_grid.get_child_count(): break
		var data = InventoryManager.hotbar[i]
		var slot = hotbar_grid.get_child(i)
		var h_slot = hud_grid.get_child(i)
		if data:
			slot.set_item(data["id"], data["quantity"])
			h_slot.set_item(data["id"], data["quantity"])
		else:
			slot.clear()
			h_slot.clear()
		
	for i in range(InventoryManager.ARMOR_SIZE):
		if i >= armor_grid.get_child_count(): break
		var slot = armor_grid.get_child(i)
		var data = InventoryManager.armor[i]
		if data: slot.set_item(data["id"], data["quantity"])
		else: slot.clear()
		
	# External slots - Use the tracked count to avoid out of bounds
	if external_section.visible:
		var current_external_data = InventoryManager.external_inventory
		for i in range(external_grid.get_child_count()):
			var slot = external_grid.get_child(i)
			if i < current_external_data.size():
				var data = current_external_data[i]
				if data: slot.set_item(data["id"], data["quantity"])
				else: slot.clear()
			else:
				slot.clear()
			
	var s = InventoryManager.total_stats
	stats_label.text = "STR: %d\nAGI: %d\nINT: %d\nSTA: %d" % [
		s.get("strength", 0), s.get("agility", 0), s.get("intellect", 0), s.get("stamina", 0)
	]

func _on_active_slot_changed(index: int) -> void:
	# Update highlights in the HUD grid
	for i in range(hud_grid.get_child_count()):
		var slot = hud_grid.get_child(i)
		if slot.has_method("highlight"):
			slot.highlight(i == index)

func _setup_slots() -> void:
	for i in range(InventoryManager.BAG_SIZE):
		var slot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.inventory_type = "bag"
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_mouse_exited)
		bag_grid.add_child(slot)
		
	for i in range(InventoryManager.HOTBAR_SIZE):
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
		
	for i in range(InventoryManager.ARMOR_SIZE):
		var slot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.inventory_type = "armor"
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_mouse_exited)
		armor_grid.add_child(slot)

func _on_slot_mouse_entered(slot: Control) -> void:
	var item = slot._get_my_item_data()
	if not item: return
	
	if current_tooltip: current_tooltip.queue_free()
	
	current_tooltip = TOOLTIP_SCENE.instantiate()
	tooltip_container.add_child(current_tooltip)
	current_tooltip.display(item["id"])
	
	_update_tooltip_pos()

func _on_slot_mouse_exited() -> void:
	if current_tooltip:
		current_tooltip.queue_free()
		current_tooltip = null

func _process(_delta: float) -> void:
	if current_tooltip:
		_update_tooltip_pos()

func _update_tooltip_pos() -> void:
	if current_tooltip:
		current_tooltip.global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if not is_local_authority: return
	
	if event.is_action_pressed("inventory"):
		inventory_overlay.visible = !inventory_overlay.visible
		hotbar_hud.visible = !inventory_overlay.visible
		
		if current_tooltip: _on_slot_mouse_exited()
		
		if inventory_overlay.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			refresh()
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			# If we had an external inventory open, clear it now
			if external_section.visible:
				InventoryManager.close_external_inventory()
