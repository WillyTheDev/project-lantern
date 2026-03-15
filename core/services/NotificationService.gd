extends Node

## NotificationService (Facade)
## High-level API for sending in-game notifications to the player.
## UI components listen for the notification_requested signal.

signal notification_requested(data: NotificationData)

var notification_queue: Array[NotificationData] = []

func send_info(message: String, duration: float = 3.0) -> void:
	_request_notification(NotificationData.create(message, NotificationData.Type.INFO, duration))

func send_success(message: String, duration: float = 3.0) -> void:
	_request_notification(NotificationData.create(message, NotificationData.Type.SUCCESS, duration))

func send_warning(message: String, duration: float = 4.0) -> void:
	_request_notification(NotificationData.create(message, NotificationData.Type.WARNING, duration))

func send_error(message: String, duration: float = 5.0) -> void:
	_request_notification(NotificationData.create(message, NotificationData.Type.ERROR, duration))

func _request_notification(data: NotificationData) -> void:
	notification_queue.append(data)
	notification_requested.emit(data)
	print("[NotificationService] Notification: ", data.message, " (Type: ", data.type, ")")

func reset() -> void:
	notification_queue.clear()
	print("[NotificationService] Reset.")
