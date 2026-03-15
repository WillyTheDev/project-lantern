extends Control

## Notification UI Component
## Animates incoming notifications using a Tween.

@onready var label: Label = %NotificationLabel
@onready var icon: TextureRect = %NotificationIcon
@onready var panel: TextureRect = $TextureRect # Container for the notification content

var current_tween: Tween
var is_displaying: bool = false
var queue: Array[NotificationData] = []

func _ready() -> void:
	# Start invisible and off-screen (top)
	modulate.a = 0.0
	panel.position.y = -panel.size.y
	
	# Connect to the service
	NotificationService.notification_requested.connect(_on_notification_requested)

func _on_notification_requested(data: NotificationData) -> void:
	queue.append(data)
	if not is_displaying:
		_process_queue()

func _process_queue() -> void:
	if queue.is_empty():
		is_displaying = false
		return
	
	is_displaying = true
	var data = queue.pop_front()
	_show_notification(data)

func _show_notification(data: NotificationData) -> void:
	# Update UI
	label.text = data.message
	# Set color based on type
	match data.type:
		NotificationData.Type.INFO: label.modulate = Color.WHITE
		NotificationData.Type.SUCCESS: label.modulate = Color.GREEN
		NotificationData.Type.WARNING: label.modulate = Color.YELLOW
		NotificationData.Type.ERROR: label.modulate = Color.RED
	
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	# Slide in and fade in
	current_tween.tween_property(panel, "position:y", 20.0, 0.5)
	current_tween.tween_property(self, "modulate:a", 1.0, 0.4)
	
	# Wait for duration
	await get_tree().create_timer(data.duration).timeout
	
	# Slide out and fade out
	current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	current_tween.tween_property(panel, "position:y", -panel.size.y, 0.5)
	current_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	
	await current_tween.finished
	_process_queue()
