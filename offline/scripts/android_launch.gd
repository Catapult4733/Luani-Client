extends Node
## Android's native activity supplies only an opaque one-use URI, never browser cookies.
signal launch_ready(data: Dictionary)
signal failed(message: String)
const API := "https://ffghvwuuqmvzvjuiynkn.supabase.co/functions/v1/luani-play"
var _uri_pattern := RegEx.new()
var _code_pattern := RegEx.new()
var _last_uri: String = ""
var _last_intent_uri: String = ""
var _busy: bool = false
var _clock: float = 0.0
var _generation: int = 0
var _request: HTTPRequest

func _ready() -> void:
	_uri_pattern.compile("\\Aluani://launch\\?ticket=([A-Za-z0-9_-]{43})\\z")
	_code_pattern.compile("\\A[A-Za-z0-9_-]{43}\\z")
	if not Engine.has_singleton("AndroidRuntime"):
		failed.emit("Android launch integration unavailable. Please update Luani.")
		set_process(false)

func _process(delta: float) -> void:
	_clock -= delta
	if _clock > 0.0: return
	_clock = 0.2
	if _busy or SessionState.online: return
	var value := current_uri()
	if value != _last_intent_uri:
		_last_intent_uri = value
		accept_uri(value)

func current_uri() -> String:
	if not Engine.has_singleton("AndroidRuntime"): return ""
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Variant = runtime.call("getActivity")
	if activity == null: return ""
	var intent: Variant = activity.call("getIntent")
	if intent == null: return ""
	var value: Variant = intent.call("getDataString")
	return value if value is String else ""

func accept_uri(value: String) -> void:
	if value.is_empty() or value == _last_uri: return
	if _busy or SessionState.online: return
	_last_uri = value
	if value.length() > 256 or _uri_pattern.search(value) == null:
		failed.emit("Invalid launch link. Choose Join game on new.luani.fyi."); return
	_redeem(_uri_pattern.search(value).get_string(1))

func _redeem(ticket: String) -> void:
	_busy = true
	_generation += 1
	var generation := _generation
	var request := HTTPRequest.new()
	_request = request
	request.timeout = 15.0
	request.body_size_limit = 65536
	request.max_redirects = 0
	request.use_threads = true
	add_child(request)
	var error: Error = request.request(API, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify({"action":"redeem","ticket":ticket}))
	ticket = ""
	if error != OK:
		_busy = false; request.queue_free(); failed.emit("Could not reach Luani. Check your connection."); return
	var reply: Array = await request.request_completed
	if generation != _generation: return
	_request = null
	request.queue_free(); _busy = false
	if int(reply[0]) != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Could not reach Luani. Join again from the website."); return
	if int(reply[1]) != 200:
		failed.emit("Launch expired, server unavailable, or this account is already playing. Use a fresh Join link."); return
	var body: PackedByteArray = reply[3]
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or data.get("protocol") != 1 or not data.get("endpoint") is Dictionary or _code_pattern.search(str(data.get("admission",""))) == null:
		failed.emit("Invalid authentication response. Join again from the website."); return
	launch_ready.emit(data)

func cancel_pending() -> void:
	_generation += 1
	_busy = false
	if is_instance_valid(_request):
		_request.cancel_request()
		_request.queue_free()
	_request = null
