# client_and_studio/scenes/game/game_world.gd
extends Node3D

## Gameplay scene handling multiplayer world loading and player avatar spawning

@onready var world_root: Node3D = %WorldRoot
@onready var players_container: Node3D = %Players
@onready var status_label: Label = %StatusLabel
@onready var disconnect_button: Button = %DisconnectButton

var current_place_id: String = "place_default_01"

func _ready() -> void:
	disconnect_button.pressed.connect(_on_disconnect_pressed)

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.setup_players_container(players_container)
		net_mgr.client_connected_to_server.connect(_on_connected)
		net_mgr.connection_failed.connect(_on_connection_failed)

	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.active_place_id != "":
		current_place_id = game_mgr.active_place_id

	# If hosting, load place into world_root
	if net_mgr and net_mgr.is_server:
		status_label.text = "Hosting Server (Place: " + current_place_id + ")"
		var loader := get_node_or_null("/root/PlaceLoader")
		if loader:
			loader.load_place(current_place_id, world_root)
	else:
		status_label.text = "Connected to Server (Place: " + current_place_id + ")"

func _on_connected(_ip: String, _port: int) -> void:
	status_label.text = "Connected to Luani Game Server!"

func _on_connection_failed(reason: String) -> void:
	status_label.text = "Connection Error: " + reason

func _on_disconnect_pressed() -> void:
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.disconnect_network()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
