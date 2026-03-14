extends Node
class_name PBRequest

signal completed(response_code: int, result: Variant)

var http: HTTPRequest
var url: String
var method: int
var headers: Array
var body: String
var requester_id: int

func _init(_url: String, _method: int, _headers: Array, _body: String, _requester_id: int = 1) -> void:
	url = _url
	method = _method
	headers = _headers
	body = _body
	requester_id = _requester_id

func execute(parent: Node) -> void:
	http = HTTPRequest.new()
	http.timeout = 5.0
	parent.add_child(http)
	
	http.request_completed.connect(_on_request_completed)
	
	var err = http.request(url, headers, method, body)
	if err != OK:
		printerr("[PBRequest] Immediate error: ", err)
		_on_request_completed(0, 0, [], PackedByteArray())

func _on_request_completed(_result: int, response_code: int, _headers: Array, _body: PackedByteArray) -> void:
	var response_str = _body.get_string_from_utf8()
	var json_result = JSON.parse_string(response_str)
	completed.emit(response_code, json_result)
	http.queue_free()
