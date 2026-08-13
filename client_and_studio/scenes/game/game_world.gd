# client_and_studio/scenes/game/game_world.gd
extends Node3D

## Gameplay scene handling multiplayer world loading, 3D environment guarantee, avatar spawning, pause menu, chat, and leaderboard

@onready var world_root: Node3D = %WorldRoot
@onready var players_container: Node3D = %Players
@onready var pause_menu: Control = %PauseMenu

@onready var settings_button: Button = %SettingsButton
@onready var chat_toggle_button: Button = %ChatToggleButton
@onready var leaderboard_toggle_button: Button = %LeaderboardToggleButton

var current_place_id: String = "place_default_01"

const VECTOR_ICON_SCRIPT := preload("res://scripts/ui/vector_icon_button.gd")

func _ready() -> void:
	var top_left_bar := get_node_or_null("UI/HUD/TopLeftBar")
	if top_left_bar:
		for child in top_left_bar.get_children():
			child.queue_free()
			
		# 1. Menu Button (Galaxy Spiral)
		var menu_btn := Button.new()
		menu_btn.set_script(VECTOR_ICON_SCRIPT)
		menu_btn.set("icon_type", 0) # MENU
		menu_btn.tooltip_text = "Pause Menu (ESC)"
		menu_btn.pressed.connect(_on_menu_button_pressed)
		top_left_bar.add_child(menu_btn)

		# 2. Mic Button
		var mic_btn := Button.new()
		mic_btn.name = "MicButton"
		mic_btn.set_script(VECTOR_ICON_SCRIPT)
		mic_btn.set("icon_type", 2) # MIC
		mic_btn.set("is_muted", true)
		mic_btn.tooltip_text = "Toggle Voice Chat Mic"
		mic_btn.pressed.connect(func():
			var voice_mgr := get_node_or_null("/root/VoiceChatManager")
			var is_muted := true
			if voice_mgr and voice_mgr.has_method("toggle_mic"):
				is_muted = not voice_mgr.call("toggle_mic")
			if mic_btn.has_method("set_muted"):
				mic_btn.call("set_muted", is_muted)
		)
		top_left_bar.add_child(mic_btn)

		# 3. Chat Button
		var chat_btn := Button.new()
		chat_btn.set_script(VECTOR_ICON_SCRIPT)
		chat_btn.set("icon_type", 1) # CHAT
		chat_btn.tooltip_text = "Toggle Chat (T)"
		chat_btn.pressed.connect(_on_chat_toggle_pressed)
		top_left_bar.add_child(chat_btn)

	if leaderboard_toggle_button:
		leaderboard_toggle_button.pressed.connect(_on_leaderboard_toggle_pressed)

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.setup_players_container(players_container)
		net_mgr.client_connected_to_server.connect(_on_connected)
		net_mgr.connection_failed.connect(_on_connection_failed)

	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.active_place_id != "":
		current_place_id = game_mgr.active_place_id

	# Instantiate Chat Overlay and Leaderboard Overlay into UI CanvasLayer
	_instantiate_game_ui()

	var loader := get_node_or_null("/root/PlaceLoader")

	# If hosting server, load place into world_root
	if net_mgr and net_mgr.is_server:
		if loader:
			loader.load_place(current_place_id, world_root)
		else:
			_guarantee_default_3d_environment()
	else:
		# Guarantee 3D floor baseplate and lighting exist on client join
		_guarantee_default_3d_environment()

		# Ensure local player avatar is spawned
		if net_mgr:
			var my_id := multiplayer.get_unique_id()
			net_mgr.spawn_player_avatar(my_id)

func _instantiate_game_ui() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		return

	var ui_node := get_node_or_null("UI")
	if not ui_node:
		ui_node = self

	var chat_scene := load("res://scenes/ui/chat_overlay.tscn")
	if chat_scene and not ui_node.has_node("ChatOverlay"):
		var chat_inst = chat_scene.instantiate()
		ui_node.add_child.call_deferred(chat_inst)

	var tab_scene := load("res://scenes/ui/leaderboard_overlay.tscn")
	if tab_scene and not ui_node.has_node("LeaderboardOverlay"):
		var tab_inst = tab_scene.instantiate()
		ui_node.add_child.call_deferred(tab_inst)

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

func _on_chat_toggle_pressed() -> void:
	var ui_mgr := get_node_or_null("/root/UIManager")
	if ui_mgr and ui_mgr.has_method("toggle_chat"):
		ui_mgr.call("toggle_chat")
	else:
		var chat := get_node_or_null("UI/ChatOverlay")
		if chat and chat.has_method("toggle_chat"):
			chat.call("toggle_chat")

func _on_leaderboard_toggle_pressed() -> void:
	var ui_mgr := get_node_or_null("/root/UIManager")
	if ui_mgr and ui_mgr.has_method("toggle_leaderboard"):
		ui_mgr.call("toggle_leaderboard")
	else:
		var tab := get_node_or_null("UI/LeaderboardOverlay")
		if tab and tab.has_method("toggle_leaderboard"):
			tab.call("toggle_leaderboard")

func _on_connected(_ip: String, _port: int) -> void:
	_guarantee_default_3d_environment()

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		var my_id := multiplayer.get_unique_id()
		net_mgr.spawn_player_avatar(my_id)

func _on_connection_failed(_reason: String) -> void:
	pass
