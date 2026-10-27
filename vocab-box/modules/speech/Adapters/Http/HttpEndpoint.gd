extends Node

const Contracts = preload("res://modules/speech/Core/Domain/SpeechContracts.gd")

signal completed(session_id: int, result: Dictionary)

var _url := ""
var _token := ""
var _request: HTTPRequest

func configure(url: String, token: String) -> bool:
	if not is_allowed_endpoint(url) or token.contains("\r") or token.contains("\n"):
		return false
	_url = url
	_token = token
	return true

func post_bytes(session_id: int, body: PackedByteArray, content_type: String) -> void:
	_request_json(session_id, HTTPClient.METHOD_POST, body, content_type)

func get_json(session_id: int) -> void:
	_request_json(session_id, HTTPClient.METHOD_GET, PackedByteArray(), "")

func _request_json(session_id: int, method: HTTPClient.Method, body: PackedByteArray, content_type: String) -> void:
	cancel()
	var request := HTTPRequest.new()
	request.max_redirects = 0
	request.body_size_limit = 65536
	request.timeout = 10.0 if method == HTTPClient.METHOD_GET else 30.0
	add_child(request)
	_request = request
	request.request_completed.connect(_on_completed.bind(request, session_id))
	var headers := PackedStringArray()
	if not content_type.is_empty():
		headers.append("Content-Type: " + content_type)
	if not _token.is_empty():
		headers.append("Authorization: Bearer " + _token)
	var error := request.request_raw(_url, headers, method, body)
	if error != OK:
		cancel()
		completed.emit(session_id, Contracts.failure("service_unavailable", "Speech checking is unavailable. Please try again."))

func post_json(session_id: int, body: Dictionary) -> void:
	post_bytes(session_id, JSON.stringify(body).to_utf8_buffer(), "application/json")

func cancel() -> void:
	if is_instance_valid(_request):
		_request.cancel_request()
		_request.queue_free()
	_request = null

func _on_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray,
		request: HTTPRequest, session_id: int) -> void:
	if request != _request:
		return
	_request = null
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
		completed.emit(session_id, Contracts.failure("service_unavailable", "Speech checking is unavailable. Please try again."))
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		completed.emit(session_id, Contracts.failure("invalid_response", "Speech checking returned an unusable response."))
		return
	completed.emit(session_id, Contracts.success(data))

static func is_allowed_endpoint(url: String) -> bool:
	if _has_invalid_url_characters(url):
		return false
	var secure := url.begins_with("https://")
	var loopback := url.begins_with("http://")
	if not secure and not loopback:
		return false
	var authority := url.substr(8 if secure else 7).get_slice("/", 0).get_slice("?", 0)
	if authority.is_empty() or authority.contains("@") or authority.contains("\\"):
		return false
	var host := authority
	var port := ""
	if host.begins_with("["):
		var close := host.find("]")
		if close < 0:
			return false
		var suffix := host.substr(close + 1)
		if not suffix.is_empty() and not suffix.begins_with(":"):
			return false
		port = suffix.substr(1) if not suffix.is_empty() else ""
		host = host.substr(0, close + 1)
	elif host.contains(":"):
		if host.count(":") != 1:
			return false
		port = host.get_slice(":", 1)
		host = host.get_slice(":", 0)
	if host.is_empty() or (authority.ends_with(":") and port.is_empty()):
		return false
	if not port.is_empty() and (not port.is_valid_int() or int(port) < 1 or int(port) > 65535):
		return false
	if secure:
		return true
	host = host.to_lower()
	return host in ["localhost", "127.0.0.1", "[::1]"]

static func _has_invalid_url_characters(url: String) -> bool:
	return url != url.strip_edges() \
		or url.contains("\r") \
		or url.contains("\n") \
		or url.contains("\t") \
		or url.contains(" ") \
		or url.contains("#")
