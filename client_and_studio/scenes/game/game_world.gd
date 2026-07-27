# client_and_studio/scenes/game/game_world.gd
extends Node3D

## Gameplay scene handling multiplayer world loading, 3D environment guarantee, avatar spawning, pause menu, chat, and leaderboard

@onready var world_root: Node3D = %WorldRoot
@onready var players_container: Node3D = %Players
@onready var status_label: Label = %StatusLabel
@onready var menu_button: Button = %MenuButton
@onready var pause_menu: Control = %PauseMenu

var current_place_id: String = "place_default_01"

func _ready() -> void:
	menu_button.pressed.connect(_on_menu_button_pressed)

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.setup_players_container(players_container)
		net_mgr.client_connected_to_server.connect(_on_connected)
		net_mgr.connection_failed.connect(_on_connection_failed)

	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.active_place_id != "":
		current_place_id = game_mgr.active_place_id

	# Instantiate Chat Overlay and Leaderboard Overlay UI
	_instantiate_game_ui()

	var loader := get_node_or_null("/root/PlaceLoader")

	# If hosting server, load place into world_root
	if net_mgr and net_mgr.is_server:
		status_label.text = "Hosting Server (Place: " + current_place_id + ")"
		if loader:
			loader.load_place(current_place_id, world_root)
		else:
			_guarantee_default_3d_environment()
	else:
		status_label.text = "Connected to Server (Place: " + current_place_id + ")"
		# Guarantee 3D floor baseplate and lighting exist on client join
		_guarantee_default_3d_environment()

		# Ensure local player avatar is spawned
		if net_mgr:
			var my_id := multiplayer.get_unique_id()
			net_mgr.spawn_player_avatar(my_id)

func _instantiate_game_ui() -> void:
	var chat_scene := load("res://scenes/ui/chat_overlay.tscn")
	if chat_scene and not has_node("ChatOverlay"):
		var chat_inst = chat_scene.instantiate()
		add_child.call_deferred(chat_inst)

	var tab_scene := load("res://scenes/ui/leaderboard_overlay.tscn")
	if tab_scene and not has_node("LeaderboardOverlay"):
		var tab_inst = tab_scene.instantiate()
		add_child.call_deferred(tab_inst)

func _guarantee_default_3d_environment() -> void:
	if world_root and world_root.get_child_count() == 0:
		print("[Luani GameWorld] Instantiating default 3D environment floor baseplate & lighting.")
		var loader := get_node_or_null("/root/PlaceLoader")
		if loader:
			loader._instantiate_default_starter_world(current_place_id, world_root)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_menu:
			pause_menu.toggle_menu()
			get_viewport().set_input_as_handled()

func _on_menu_button_pressed() -> void:
	if pause_menu:
		pause_menu.toggle_menu()

func _on_connected(_ip: String, _port: int) -> void:
	status_label.text = "Connected to Luani Game Server!"
	_guarantee_default_3d_environment()

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		var my_id := multiplayer.get_unique_id()
		net_mgr.spawn_player_avatar(my_id)

func _on_connection_failed(reason: String) -> void:
	status_label.text = "Connection Error: " + reason
