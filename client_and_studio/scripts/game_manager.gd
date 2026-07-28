# client_and_studio/scripts/game_manager.gd
extends Node

## Core session manager for Luani Client, Studio, & Server Hosting

signal connection_started(server_ip: String, server_port: int)
signal session_state_changed(new_state: String)

enum AppState {
	LAUNCHER,
	JOINING_SERVER,
	IN_GAME,
	STUDIO_MODE,
	SERVER_HOST
}

var current_state: AppState = AppState.LAUNCHER
var active_server_ip: String = ""
var active_server_port: int = 7777
var active_auth_token: String = ""
var active_place_id: String = "place_default_01"

func _ready() -> void:
	print("[Luani GameManager] Initialized Luani Core Engine.")

	# Check CLI flags for headless server mode or direct URI protocol launch
	_parse_cmdline_flags()

	# Forcefully instantiate DirectUILayer onto root when running client
	_force_instantiate_ui_overlays()

	# Connect to protocol parser signal
	var parser := get_node_or_null("/root/ProtocolParser")
	if parser:
		parser.protocol_received.connect(_on_protocol_received)
		if parser.latest_session_data.get("valid", false):
			_on_protocol_received(parser.latest_session_data)

func _process(_delta: float) -> void:
	check_pending_uri()

func _force_instantiate_ui_overlays() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		print("[Luani GameManager] Running in Headless/Dedicated Server Mode. Bypassing DirectUILayer.")
		return

	var root := get_tree().root
	if root.has_node("DirectUILayer"):
		return

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "DirectUILayer"
	ui_layer.layer = 100
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	# Chat Overlay
	var chat_scene := load("res://scenes/ui/chat_overlay.tscn")
	if chat_scene:
		ui_layer.add_child(chat_scene.instantiate())

	# Leaderboard Overlay
	var tab_scene := load("res://scenes/ui/leaderboard_overlay.tscn")
	if tab_scene:
		ui_layer.add_child(tab_scene.instantiate())

	root.add_child.call_deferred(ui_layer)
	print("[Luani GameManager] Forcefully instantiated DirectUILayer directly on root.")

func _parse_cmdline_flags() -> void:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())

	var is_headless_server := false
	for arg in args:
		if arg == "--server" or arg == "--headless":
			is_headless_server = true
		elif arg.begins_with("--port="):
			active_server_port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--place_id="):
			active_place_id = arg.trim_prefix("--place_id=")

	if is_headless_server:
		print("[Luani GameManager] Starting Headless Server Mode on Port: ", active_server_port, " Place: ", active_place_id)
		host_local_server(active_server_port, active_place_id)

func _on_protocol_received(session_data: Dictionary) -> void:
	if session_data.get("valid", false) and session_data.get("action") == "join":
		active_server_ip = session_data.get("server_ip", "127.0.0.1")
		active_server_port = session_data.get("server_port", 7777)
		active_auth_token = session_data.get("auth_token", "")

		print("[Luani GameManager] Protocol trigger: Joining server ", active_server_ip, ":", active_server_port)
		connect_to_server(active_server_ip, active_server_port, active_auth_token)

func connect_to_server(ip: String, port: int, token: String) -> void:
	active_server_ip = ip
	active_server_port = port
	active_auth_token = token
	current_state = AppState.JOINING_SERVER

	session_state_changed.emit("JOINING_SERVER")
	connection_started.emit(ip, port)

	var ui_mgr := get_node_or_null("/root/UIManager")
	if ui_mgr and ui_mgr.has_method("set_game_ui_visible"):
		ui_mgr.set_game_ui_visible(true)

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.join_server(ip, port, token)

	get_tree().call_deferred("change_scene_to_file", "res://scenes/game/game_world.tscn")

func host_local_server(port: int = 7777, place_id: String = "place_default_01") -> void:
	active_server_port = port
	active_place_id = place_id
	current_state = AppState.SERVER_HOST

	session_state_changed.emit("SERVER_HOST")

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.host_server(port)

	get_tree().call_deferred("change_scene_to_file", "res://scenes/game/game_world.tscn")

func launch_studio() -> void:
	current_state = AppState.STUDIO_MODE
	session_state_changed.emit("STUDIO_MODE")
	print("[Luani GameManager] Launching Luani Studio environment...")
	get_tree().call_deferred("change_scene_to_file", "res://studio/studio_main.tscn")

func connect_via_uri(uri_str: String) -> void:
	print("[Luani Bridge] Successfully received join URI: ", uri_str)
	print("[Luani GameManager] Received native URI from Java bridge: ", uri_str)
	hide_web_portal()
	var parser := get_node_or_null("/root/ProtocolParser")
	var session_data := {}
	if parser and parser.has_method("parse_uri"):
		session_data = parser.parse_uri(uri_str)
	var ip: String = session_data.get("server_ip", "127.0.0.1")
	var port: int = session_data.get("server_port", 7777)
	var auth: String = session_data.get("auth_token", "")

	var ui_mgr := get_node_or_null("/root/UIManager")
	if ui_mgr and ui_mgr.has_method("set_game_ui_visible"):
		ui_mgr.set_game_ui_visible(true)

	connect_to_server(ip, port, auth)

func show_web_portal() -> void:
	if OS.get_name() == "Android":
		var godot_app = JavaClassWrapper.wrap("com.godot.game.GodotApp")
		if godot_app:
			godot_app.showWebPortalStatic()
			print("[Luani GameManager] Triggered native Java showWebPortalStatic overlay.")

func hide_web_portal() -> void:
	if OS.get_name() == "Android":
		var godot_app = JavaClassWrapper.wrap("com.godot.game.GodotApp")
		if godot_app:
			godot_app.hideWebPortalStatic()
			print("[Luani GameManager] Triggered native Java hideWebPortalStatic overlay.")

func check_pending_uri() -> void:
	if OS.has_feature("android"):
		var java_app = JavaClassWrapper.wrap("com.godot.game.GodotApp")
		if java_app:
			var uri = java_app.getPendingUri()
			if uri != "":
				print("[Luani Bridge] Pulled URI from Java: ", uri)
				connect_via_uri(uri)


