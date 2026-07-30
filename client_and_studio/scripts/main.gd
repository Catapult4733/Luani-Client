# client_and_studio/scripts/main.gd
extends Control

## Main Launcher script managing Direct Join, Direct URI Launching, and Native Main Menu UI

@onready var status_label: Label = %StatusLabel
@onready var ip_input: LineEdit = %IPInput
@onready var port_input: LineEdit = %PortInput
@onready var auth_input: LineEdit = %AuthInput

@onready var connect_button: Button = %ConnectButton
@onready var host_button: Button = %HostButton
@onready var studio_button: Button = %StudioButton
@onready var credits_button: Button = %CreditsButton
@onready var credits_menu: Control = %CreditsMenu

@onready var tab_container: TabContainer = %TabContainer
@onready var refresh_servers_btn: Button = %RefreshServersBtn
@onready var server_tree: Tree = %ServerTree

@export var backend_api_url: String = "https://www.luani.fyi/api/servers/active"

var active_servers_list: Array = []
var is_uri_launched: bool = false
var main_menu_inst: CanvasLayer = null

const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")

func _ready() -> void:
	DisplayServer.screen_set_orientation(6)
	credits_menu.hide()

	connect_button.pressed.connect(_on_connect_pressed)
	host_button.pressed.connect(_on_host_pressed)
	studio_button.pressed.connect(_on_studio_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	refresh_servers_btn.pressed.connect(_on_refresh_servers_pressed)
	server_tree.button_clicked.connect(_on_server_item_button_clicked)

	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.session_state_changed.connect(_on_session_state_changed)

	# Inspect command line arguments for luani:// URI
	var all_args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var uri_found := ""

	for arg in all_args:
		var clean_arg: String = arg.strip_edges().trim_prefix("'").trim_suffix("'").trim_prefix("\"").trim_suffix("\"").strip_edges()
		if clean_arg.begins_with("luani://") or "luani://join" in clean_arg:
			uri_found = clean_arg
			break
		elif clean_arg.begins_with("--uri="):
			var sub_uri := clean_arg.trim_prefix("--uri=").strip_edges().trim_prefix("'").trim_suffix("'").trim_prefix("\"").trim_suffix("\"").strip_edges()
			uri_found = sub_uri
			break

	if uri_found != "":
		is_uri_launched = true
		hide()
		print("[Luani Launcher] Direct URI launch detected: '", uri_found, "'. Hiding launcher menu.")

		var parser := get_node_or_null("/root/ProtocolParser")
		var session_data := {}
		if parser:
			session_data = parser.parse_uri(uri_found)

		call_deferred("_trigger_direct_uri_join", session_data)
	else:
		# Instantiates Native Godot Main Menu UI on launch across both Mobile & Desktop
		hide()
		main_menu_inst = MAIN_MENU_SCENE.instantiate() as CanvasLayer
		add_child(main_menu_inst)
		print("[Luani Launcher] Main Menu loaded native Godot UI overlay.")

func _trigger_direct_uri_join(data: Dictionary) -> void:
	var ip: String = data.get("server_ip", "127.0.0.1")
	var port: int = data.get("server_port", 7777)
	var auth: String = data.get("auth_token", "")
	
	print("[Luani Launcher] Connecting directly to ", ip, ":", port, "...")
	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.connect_to_server(ip, port, auth)

func _on_connect_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	var port := port_input.text.to_int()
	var auth := auth_input.text.strip_edges()

	if ip == "" or port <= 0:
		status_label.text = "Error: Invalid IP or Port."
		return

	status_label.text = "Initiating connection to " + ip + ":" + str(port) + "..."
	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.connect_to_server(ip, port, auth)

func _on_host_pressed() -> void:
	if is_uri_launched:
		return
	status_label.text = "Starting Host Server on Port 7777..."
	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.start_host_server(7777)

func _on_studio_pressed() -> void:
	print("[Luani Launcher] Opening Luani Studio Environment...")
	get_tree().change_scene_to_file("res://studio/studio_main.tscn")

func _on_credits_pressed() -> void:
	credits_menu.show()

func _on_refresh_servers_pressed() -> void:
	status_label.text = "Refreshing active servers list..."
	_fetch_active_servers()

func _fetch_active_servers() -> void:
	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_servers_http_request_completed)
	
	var err := http_request.request(backend_api_url)
	if err != OK:
		status_label.text = "Failed to fetch servers: HTTP Request error."
		http_request.queue_free()

func _on_servers_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	status_label.text = "Server list updated."
	server_tree.clear()
	
	var root_item := server_tree.create_item()
	server_tree.hide_root = true

	if response_code != 200:
		var err_item := server_tree.create_item(root_item)
		err_item.set_text(0, "Offline / API unavailable")
		return

	var json_str := body.get_string_from_utf8()
	var parsed = JSON.parse_string(json_str)

	if not (parsed is Array):
		var err_item := server_tree.create_item(root_item)
		err_item.set_text(0, "No active servers listed.")
		return

	active_servers_list = parsed
	if active_servers_list.is_empty():
		var empty_item := server_tree.create_item(root_item)
		empty_item.set_text(0, "No active public servers found.")
		return

	for server in active_servers_list:
		if server is Dictionary:
			var item := server_tree.create_item(root_item)
			var sname: String = server.get("name", "Luani Server")
			var players: int = server.get("players", 0)
			var max_players: int = server.get("max_players", 12)
			var ip: String = server.get("ip", "127.0.0.1")
			var port: int = server.get("port", 7777)

			item.set_text(0, "%s (%d/%d) - %s:%d" % [sname, players, max_players, ip, port])
			item.add_button(0, null, 0, false, "Join")
			item.set_metadata(0, server)

func _on_server_item_button_clicked(item: TreeItem, column: int, id: int, mouse_button_idx: int) -> void:
	var metadata = item.get_metadata(0)
	if metadata is Dictionary:
		var ip: String = metadata.get("ip", "127.0.0.1")
		var port: int = metadata.get("port", 7777)
		var auth: String = metadata.get("auth_token", "")
		status_label.text = "Connecting to " + ip + ":" + str(port) + "..."
		var game_mgr := get_node_or_null("/root/GameManager")
		if game_mgr:
			game_mgr.connect_to_server(ip, port, auth)

func _on_session_state_changed(new_state: int) -> void:
	if main_menu_inst:
		main_menu_inst.visible = (new_state == 0) # 0: LAUNCHER state
	if new_state == 0:
		show()
	else:
		hide()
