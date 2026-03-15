extends Resource
class_name NotificationData

enum Type { INFO, SUCCESS, WARNING, ERROR }

@export var message: String = ""
@export var type: Type = Type.INFO
@export var duration: float = 3.0

static func create(_message: String, _type: Type = Type.INFO, _duration: float = 3.0) -> NotificationData:
	var data = NotificationData.new()
	data.message = _message
	data.type = _type
	data.duration = _duration
	return data
