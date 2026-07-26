# client_and_studio/scripts/main.gd
extends Control

## Main Launcher script managing Direct Join, Direct URI Launching, and Server Browser

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

func _ready() -> void:
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

	# Inspect all command line arguments for luani:// URI
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
		
		# 1. Immediately hide main launcher UI root node
		hide()
		print("[Luani Launcher] Direct URI launch detected: '", uri_found, "'. Hiding launcher menu.")

		# 2. Extract IP, Port, and Auth token via ProtocolParser
		var parser := get_node_or_null("/root/ProtocolParser")
		var session_data := {}
		if parser:
			session_data = parser.parse_uri(uri_found)

		# 3. Directly trigger connection & skip calling fetch_server_list()
		call_deferred("_trigger_direct_uri_join", session_data)
	else:
		# Show main menu as normal and fetch active server list
		show()
		status_label.text = "Ready to connect, self-host, or browse servers."
		_fetch_active_servers()

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

	var port := port_input.text.to_int()
	if port <= 0:
		port = 7777

	status_label.text = "Starting self-hosted server on port " + str(port) + "..."
	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.host_local_server(port)

func _on_studio_pressed() -> void:
	status_label.text = "Starting Luani Studio mode..."
	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.launch_studio()

func _on_credits_pressed() -> void:
	credits_menu.show()

func _on_refresh_servers_pressed() -> void:
	_fetch_active_servers()

func _fetch_active_servers() -> void:
	status_label.text = "Fetching active servers from luani.fyi..."
	var http := HTTPRequest.new()
	add_child.call_deferred(http)
	
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var json_res = JSON.parse_string(body.get_string_from_utf8())
			if json_res is Dictionary and json_res.get("success", false):
				active_servers_list = json_res.get("servers", [])
				_render_server_list(active_servers_list)
				status_label.text = "Server list updated (%d servers found)." % active_servers_list.size()
			else:
				status_label.text = "Failed to parse server list."
		else:
			status_label.text = "Could not reach server browser API."
		http.queue_free()
	)
	
	var err := http.request(backend_api_url)
	if err != OK:
		status_label.text = "API connection error."

func _render_server_list(servers: Array) -> void:
	server_tree.clear()
	var root := server_tree.create_item()
	server_tree.hide_root = true

	for srv in servers:
		var item := server_tree.create_item(root)
		var name_str: String = srv.get("name", "Luani Server")
		var players_str: String = "%d/%d" % [srv.get("playerCount", 1), srv.get("maxPlayers", 16)]
		var ping_str: String = "%d ms" % srv.get("ping", 15)
		var type_str: String = "User Host" if srv.get("isUserHosted", false) else "Managed"

		item.set_text(0, name_str)
		item.set_text(1, type_str)
		item.set_text(2, players_str)
		item.set_text(3, ping_str)
		item.add_button(4, null, 0, false, "Join")
		item.set_metadata(0, srv)

func _on_server_item_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	var srv_data: Dictionary = item.get_metadata(0)
	if srv_data:
		var ip: String = srv_data.get("serverIp", "127.0.0.1")
		var port: int = srv_data.get("serverPort", 7777)
		var token: String = srv_data.get("authToken", "")
		status_label.text = "Joining server: " + srv_data.get("name", "")
		
		var game_mgr := get_node_or_null("/root/GameManager")
		if game_mgr:
			game_mgr.connect_to_server(ip, port, token)

func _on_session_state_changed(new_state: String) -> void:
	status_label.text = "Status: " + new_state
