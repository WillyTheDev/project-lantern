extends Node

## NotificationService (Facade)
## High-level API for sending in-game notifications to the player.
## UI components listen for the notification_requested signal.

signal notification_requested(data: NotificationData)

var notification_queue: Array[NotificationData] = []

func _ready() -> void:
	EventBus.session_ended.connect(reset)

## Sends a standard information notification to the UI.
## 
## @param message: The text content of the notification.
## @param duration: How long (in seconds) the notification should remain visible. Default is 3.0s.
func send_info(message: String, duration: float = 3.0) -> void:
	_request_notification(NotificationData.create(message, NotificationData.Type.INFO, duration))

## Sends a success (usually green) notification to the UI.
## 
## @param message: The text content of the notification.
## @param duration: How long (in seconds) the notification should remain visible. Default is 3.0s.
func send_success(message: String, duration: float = 3.0) -> void:
	_request_notification(NotificationData.create(message, NotificationData.Type.SUCCESS, duration))

## Sends a warning (usually yellow) notification to the UI.
## 
## @param message: The text content of the notification.
## @param duration: How long (in seconds) the notification should remain visible. Default is 4.0s.
func send_warning(message: String, duration: float = 4.0) -> void:
	_request_notification(NotificationData.create(message, NotificationData.Type.WARNING, duration))

## Sends a critical error (usually red) notification to the UI.
## 
## @param message: The text content of the notification.
## @param duration: How long (in seconds) the notification should remain visible. Default is 5.0s.
func send_error(message: String, duration: float = 5.0) -> void:
	_request_notification(NotificationData.create(message, NotificationData.Type.ERROR, duration))

func _request_notification(data: NotificationData) -> void:
	notification_queue.append(data)
	notification_requested.emit(data)
	print("[NotificationService] Notification: ", data.message, " (Type: ", data.type, ")")

## Clears all pending notifications from the queue. Called during logout transitions.
func reset() -> void:
	notification_queue.clear()
	print("[NotificationService] Reset.")
