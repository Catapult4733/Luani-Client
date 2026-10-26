extends Node
## Desktop URI handoff is unchanged; Android owns a trusted website overlay and native game.
const Server = preload("res://scripts/dedicated_server.gd")
const Network = preload("res://scripts/network_client.gd")
const OnlineWorld = preload("res://scripts/online_world.gd")
const OfflineWorld = preload("res://scripts/world.gd")
const UI = preload("res://scripts/ui_theme.gd")
const MobileUI = preload("res://scripts/mobile_ui.gd")
var _screen: CanvasLayer
var _status: Label
var _network: Network
var _world: Node
var _android: Node
var _website: Object
var _returning := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args == PackedStringArray(["--server"]):
		if DisplayServer.get_name() != "headless" or OS.get_environment("LUANI_CONTROL_KEY").is_empty():
			push_error("Server mode requires the configured headless service."); get_tree().quit(1); return
		add_child(Server.new())
		return
	MobileUI.configure(get_window())
	_build_launcher()
	if OS.has_feature("android"):
		get_tree().quit_on_go_back = false
		_android = load("res://scripts/android_launch.gd").new()
		_android.connect("launch_ready", _begin_network)
		_android.connect("failed", _lost)
		add_child(_android)
		if Engine.has_singleton("LuaniWebsite"):
			_website = Engine.get_singleton("LuaniWebsite")
			_website.connect("launch_requested", Callable(_android, "accept_uri"))
			_website.connect("practice_requested", _practice)
			if _android.current_uri().is_empty(): _open_website()
		else:
			_status.text = "Android website component is unavailable. Please update Luani."
		return
	if args.is_empty(): return
	if args.size()!=2 or args[0]!="--launch-fd" or not args[1].is_valid_int(): _status.text="Invalid launch arguments. Join from new.luani.fyi."; return
	var descriptor := int(args[1])
	if descriptor<3 or descriptor>128: _status.text="Invalid launch handoff."; return
	var file := FileAccess.open("/proc/self/fd/"+str(descriptor),FileAccess.READ)
	if file==null or file.get_length()>65536: _status.text="Launch handoff unavailable."; return
	var data: Variant = JSON.parse_string(file.get_as_text()); file.close()
	if not data is Dictionary or data.get("protocol")!=1: _status.text="Launch expired. Join again from the website."; return
	_begin_network(data)

func _open_website() -> void:
	if _website != null: _website.call("showWebsite")
	else: OS.shell_open("https://new.luani.fyi/games/baseplate")

func _hide_website() -> void:
	if _website != null: _website.call("hideWebsite")

func _discard_network() -> void:
	if not is_instance_valid(_network): return
	if _network.lost.is_connected(_lost): _network.lost.disconnect(_lost)
	if _network.entered.is_connected(_entered): _network.entered.disconnect(_entered)
	_network.queue_free(); _network = null

func _begin_network(data: Dictionary) -> void:
	_discard_network()
	_hide_website()
	_status.text="Authenticating with the game server…"
	_screen.show()
	_network=Network.new(); add_child(_network)
	_network.entered.connect(_entered)
	_network.lost.connect(_lost)
	_network.start(data)

func _build_launcher() -> void:
	_screen=CanvasLayer.new(); add_child(_screen)
	var root := Control.new(); root.theme=UI.make_theme(); _screen.add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color=UI.DARK; root.add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new(); root.add_child(center); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new(); panel.custom_minimum_size=Vector2(440,260); panel.add_theme_stylebox_override("panel",UI.overlay_style()); center.add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",18); panel.add_child(box)
	box.add_child(UI.label("Luani",28,UI.INK,700))
	_status=UI.label("Log in on new.luani.fyi and choose Join game.\nYour account name and avatar load automatically.",14,UI.MUTED)
	if OS.has_feature("android"):
		_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_status.custom_minimum_size.x = 416
	box.add_child(_status)
	var website := Button.new(); website.text="Open Luani website" if OS.has_feature("android") else "Open Baseplate on the website"; website.pressed.connect(_open_website); box.add_child(website)
	var practice := Button.new(); practice.text="Offline practice (not an account session)"; practice.pressed.connect(_practice); box.add_child(practice)
	if OS.has_feature("android"):
		website.custom_minimum_size.y=48; practice.custom_minimum_size.y=48

func _entered() -> void:
	if is_instance_valid(_world): _world.queue_free()
	var online_world := OnlineWorld.new()
	online_world.connection=_network
	_world=online_world
	add_child(_world)
	_screen.hide()

func _lost(message: String) -> void:
	if _returning: return
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_world): _world.queue_free(); _world=null
	SessionState.online=false
	_status.text=message; _screen.show()
	if _website != null:
		_open_website(); _website.call("showMessage", message)

func _practice() -> void:
	if is_instance_valid(_android): _android.cancel_pending()
	_hide_website()
	_discard_network()
	if is_instance_valid(_world): _world.queue_free()
	SessionState.online=false; SessionState.set_identity({"username":"Explorer","avatar":{}})
	_world=OfflineWorld.new(); add_child(_world); _screen.hide()

func return_to_website() -> void:
	if _returning: return
	_returning = true
	if is_instance_valid(_android): _android.cancel_pending()
	if is_instance_valid(_world):
		await _world.leave_game()
		_world.queue_free(); _world=null
	_discard_network()
	SessionState.online=false
	SessionState.mobile_move=Vector2.ZERO; SessionState.mobile_jump=false; SessionState.mobile_sprint=false
	_screen.show(); _returning=false; _open_website()

func _notification(what: int) -> void:
	if OS.has_feature("android") and what == NOTIFICATION_WM_GO_BACK_REQUEST and not is_instance_valid(_world):
		return_to_website()
