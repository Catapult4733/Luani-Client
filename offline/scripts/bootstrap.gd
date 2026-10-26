extends Node
## Entry point selects production server, authenticated join, or explicitly chosen offline practice.
const Server = preload("res://scripts/dedicated_server.gd")
const Network = preload("res://scripts/network_client.gd")
const OnlineWorld = preload("res://scripts/online_world.gd")
const OfflineWorld = preload("res://scripts/world.gd")
const UI = preload("res://scripts/ui_theme.gd")
var _screen: CanvasLayer
var _status: Label
var _network: Network
var _world: Node

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args == PackedStringArray(["--server"]):
		if DisplayServer.get_name() != "headless" or OS.get_environment("LUANI_CONTROL_KEY").is_empty():
			push_error("Server mode requires the configured headless service."); get_tree().quit(1); return
		add_child(Server.new())
		return
	_build_launcher()
	if OS.has_feature("android"):
		var android: Node = load("res://scripts/android_launch.gd").new()
		android.connect("launch_ready", _begin_network)
		android.connect("failed", _lost)
		add_child(android)
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

func _begin_network(data: Dictionary) -> void:
	if is_instance_valid(_network): _network.queue_free()
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
	box.add_child(_status)
	var website := Button.new(); website.text="Open Baseplate on the website"; website.pressed.connect(func() -> void: OS.shell_open("https://new.luani.fyi/games/baseplate")); box.add_child(website)
	var practice := Button.new(); practice.text="Offline practice (not an account session)"; practice.pressed.connect(_practice); box.add_child(practice)

func _entered() -> void:
	if is_instance_valid(_world): _world.queue_free()
	var online_world := OnlineWorld.new()
	online_world.connection=_network
	_world=online_world
	add_child(_world)
	_screen.hide()

func _lost(message: String) -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_world): _world.queue_free(); _world=null
	_status.text=message; _screen.show()

func _practice() -> void:
	if is_instance_valid(_network): _network.queue_free(); _network=null
	SessionState.online=false; SessionState.set_identity({"username":"Explorer","avatar":{}})
	_world=OfflineWorld.new(); add_child(_world); _screen.hide()
