extends Node
## Native cloud sessions stay in memory; reusable credentials never enter URLs/files.
signal account_changed
const API := "https://ffghvwuuqmvzvjuiynkn.supabase.co/functions/v1/luani-studio"
const AUTH := "https://ffghvwuuqmvzvjuiynkn.supabase.co/functions/v1/luani-auth"
var access_token: String = ""
var actor: String = ""
var busy: bool = false
var last_error: String = ""
var _generation: int = 0

func sign_out() -> void:
	_generation += 1; access_token = ""; actor = ""; last_error = ""; account_changed.emit()

func _post(url: String, payload: Dictionary, bearer: String = "") -> Dictionary:
	last_error = ""
	if busy: last_error = "Another cloud operation is still running"; return {}
	busy = true
	var generation: int = _generation
	var request := HTTPRequest.new(); request.timeout = 20; request.max_redirects = 0; request.body_size_limit = 1048576
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not bearer.is_empty(): headers.append("Authorization: Bearer " + bearer)
	var error: Error = request.request(url,headers,HTTPClient.METHOD_POST,JSON.stringify(payload))
	if error != OK: busy = false; request.queue_free(); last_error = "Could not reach Luani cloud"; return {}
	var response: Array = await request.request_completed
	request.queue_free(); busy = false
	if generation != _generation: last_error = "Your account changed"; return {}
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS: last_error = "Could not reach Luani cloud"; return {}
	var result: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if int(response[1]) != 200 or not result is Dictionary and not result is Array:
		last_error = "Cloud request failed"
		if result is Dictionary and result.get("error") is String: last_error = str(result.error).substr(0,200)
		if int(response[1]) == 401: access_token = ""; actor = ""
		return {}
	return {"value":result}

func sign_in(identifier: String, password: String) -> bool:
	var result: Dictionary = await _post(AUTH,{"action":"login","identifier":identifier.strip_edges(),"password":password})
	password = ""
	if result.is_empty(): return false
	var value: Dictionary = result.value
	var session: Dictionary = value.get("session",{})
	if not session.get("access_token") is String or not session.get("user") is Dictionary: last_error = "Could not establish your Luani account session"; return false
	_generation += 1; access_token = str(session.access_token); actor = str(session.user.get("id","")); account_changed.emit()
	return not actor.is_empty()

func operation(action: String, values: Dictionary = {}) -> Dictionary:
	if access_token.is_empty(): last_error = "Sign in to use Studio cloud"; return {}
	if not action in ["list","get","create","save","settings","publish","playtest"]: last_error = "Invalid cloud operation"; return {}
	var payload: Dictionary = values.duplicate(true); payload.action = action
	return await _post(API,payload,access_token)
