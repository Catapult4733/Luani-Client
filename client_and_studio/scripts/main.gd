# client_and_studio/scripts/main.gd
extends Control

@onready var status_label: Label = %StatusLabel
@onready var ip_input: LineEdit = %IPInput
@onready var port_input: LineEdit = %PortInput
@onready var auth_input: LineEdit = %AuthInput

@onready var connect_button: Button = %ConnectButton
@onready var host_button: Button = %HostButton
@onready var studio_button: Button = %StudioButton
@onready var credits_button: Button = %CreditsButton
@onready var credits_menu: Control = %CreditsMenu

func _ready() -> void:
	credits_menu.hide()

	connect_button.pressed.connect(_on_connect_pressed)
	host_button.pressed.connect(_on_host_pressed)
	studio_button.pressed.connect(_on_studio_pressed)
	credits_button.pressed.connect(_on_credits_pressed)

	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.session_state_changed.connect(_on_session_state_changed)

	var parser := get_node_or_null("/root/ProtocolParser")
	if parser and parser.latest_session_data.get("valid", false):
		var data: Dictionary = parser.latest_session_data
		ip_input.text = data.get("server_ip", "127.0.0.1")
		port_input.text = str(data.get("server_port", 7777))
		auth_input.text = data.get("auth_token", "")
		status_label.text = "Protocol launch received! Connecting..."
	else:
		status_label.text = "Ready to connect or self-host."

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

func _on_session_state_changed(new_state: String) -> void:
	status_label.text = "Status: " + new_state
