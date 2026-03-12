extends Control

@onready var bag_grid: GridContainer = %BagGrid
@onready var hotbar_grid: GridContainer = %HotbarGrid
@onready var armor_grid: GridContainer = %ArmorGrid
@onready var hud_grid: GridContainer = %HUDGrid
@onready var stats_label: Label = %StatsLabel
@onready var inventory_overlay: Control = %InventoryOverlay
@onready var hotbar_hud: Control = %HotbarHUD
@onready var tooltip_container: Control = %TooltipContainer

const SLOT_SCENE = preload("res://ui/inventory/InventorySlot.tscn")
const TOOLTIP_SCENE = preload("res://ui/inventory/ItemTooltip.tscn")

var is_local_authority: bool = false
var current_tooltip: Control = null

func _ready() -> void:
	_setup_slots()
	InventoryManager.inventory_updated.connect(refresh)
	InventoryManager.active_slot_changed.connect(_on_active_slot_changed)
	
	inventory_overlay.visible = false
	hotbar_hud.visible = true
	visible = true
	
	refresh()

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

func refresh() -> void:
	if not is_inside_tree(): return
	
	for i in range(InventoryManager.BAG_SIZE):
		var slot = bag_grid.get_child(i)
		var data = InventoryManager.bag[i]
		if data: slot.set_item(data["id"], data["quantity"])
		else: slot.clear()
		
	for i in range(InventoryManager.HOTBAR_SIZE):
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
		var slot = armor_grid.get_child(i)
		var data = InventoryManager.armor[i]
		if data: slot.set_item(data["id"], data["quantity"])
		else: slot.clear()
		
	var s = InventoryManager.total_stats
	stats_label.text = "STR: %d\nAGI: %d\nINT: %d\nSTA: %d" % [
		s.get("strength", 0), s.get("agility", 0), s.get("intellect", 0), s.get("stamina", 0)
	]

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
