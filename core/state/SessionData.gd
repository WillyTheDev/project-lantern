extends Resource
class_name SessionData

@export var auth_token: String = ""
@export var user_id: String = ""
@export var username: String = ""
@export var is_authenticated: bool = false

func clear() -> void:
	auth_token = ""
	user_id = ""
	username = ""
	is_authenticated = false
