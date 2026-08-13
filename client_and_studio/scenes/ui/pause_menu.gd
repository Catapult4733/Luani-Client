# client_and_studio/scenes/ui/pause_menu.gd
extends CanvasLayer

## In-Game Pause Menu Overlay for Luani Client (Website Theme, Voice Chat & Per-Player Mute Controls)

@onready var leave_button: Button = %LeaveButton
@onready var respawn_button: Button = %RespawnButton
@onready var shift_lock_button: CheckButton = %ShiftLockButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_label: Label = %VolumeLabel
@onready var voice_volume_slider: HSlider = %VoiceVolumeSlider
@onready var voice_volume_label: Label = %VoiceVolumeLabel
@onready var resume_button: Button = %ResumeButton

# Navigation Tabs (People, Settings, Help)
@onready var tab_people_btn: Button = %TabPeopleBtn
@onready var tab_settings_btn: Button = %TabSettingsBtn
@onready var tab_help_btn: Button = %TabHelpBtn

# Views
@onready var people_view: Control = %PeopleView
@onready var settings_view: Control = %SettingsView
@onready var help_view: Control = %HelpView

# People View Controls
@onready var invite_friends_btn: Button = %InviteFriendsBtn
@onready var mute_all_btn: Button = %MuteAllBtn
@onready var view_mode_btn: Button = %ViewModeBtn
@onready var section_title: Label = %SectionTitle
@onready var players_grid: GridContainer = %PlayersGrid

# Settings Controls
@onready var fullscreen_btn: CheckButton = %FullscreenBtn

var is_shift_lock_enabled: bool = true
var is_grid_view: bool = true
var is_voice_muted_all: bool = false
var muted_player_ids: Dictionary = {}
var all_tabs: Array = []
var all_views: Array = []

func _ready() -> void:
	layer = 150
	hide()
	
	_ensure_voice_audio_bus()

	all_tabs = [tab_people_btn, tab_settings_btn, tab_help_btn]
	all_views = [people_view, settings_view, help_view]
	
	tab_people_btn.pressed.connect(func(): _switch_tab(0))
	tab_settings_btn.pressed.connect(func(): _switch_tab(1))
	tab_help_btn.pressed.connect(func(): _switch_tab(2))
	
	leave_button.pressed.connect(_on_leave_pressed)
	respawn_button.pressed.connect(_on_respawn_pressed)
	shift_lock_button.toggled.connect(_on_shift_lock_toggled)
	volume_slider.value_changed.connect(_on_game_volume_changed)
	voice_volume_slider.value_changed.connect(_on_voice_volume_changed)
	resume_button.pressed.connect(_on_resume_pressed)
	
	if fullscreen_btn:
		fullscreen_btn.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_btn.toggled.connect(_on_fullscreen_toggled)

	if invite_friends_btn:
		invite_friends_btn.pressed.connect(_on_invite_friends_pressed)
	if mute_all_btn:
		mute_all_btn.pressed.connect(_on_mute_all_pressed)
	if view_mode_btn:
		view_mode_btn.pressed.connect(_on_toggle_view_mode)

	# Initial game volume setup
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var current_db := AudioServer.get_bus_volume_db(master_bus)
		volume_slider.value = db_to_linear(current_db) * 100.0

	# Initial voice volume setup
	var voice_bus := AudioServer.get_bus_index("Voice")
	if voice_bus >= 0:
		var voice_db := AudioServer.get_bus_volume_db(voice_bus)
		voice_volume_slider.value = db_to_linear(voice_db) * 100.0

func _ensure_voice_audio_bus() -> void:
	if AudioServer.get_bus_index("Voice") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Voice")
		AudioServer.set_bus_send(idx, "Master")

func _switch_tab(tab_idx: int) -> void:
	for i in range(all_tabs.size()):
		var btn: Button = all_tabs[i]
		var view: Control = all_views[i]
		btn.button_pressed = (i == tab_idx)
		view.visible = (i == tab_idx)

func toggle_menu() -> void:
	visible = not visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_switch_tab(0)
		_refresh_players_list()
	else:
		if is_shift_lock_enabled:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			_on_leave_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			_on_respawn_pressed()
			get_viewport().set_input_as_handled()

func _refresh_players_list() -> void:
	for child in players_grid.get_children():
		child.queue_free()
		
	var player_nodes: Array = []
	var players_parent := get_node_or_null("/root/GameWorld/Players")
	if not players_parent:
		players_parent = get_node_or_null("/root/Main/Players")
		
	if players_parent:
		player_nodes = players_parent.get_children()
		
	var net_mgr := get_node_or_null("/root/NetworkManager")
	var my_name: String = net_mgr.local_username if net_mgr else "Player"
	var my_peer_id: int = multiplayer.get_unique_id() if multiplayer else 1

	if is_grid_view:
		players_grid.columns = 4
	else:
		players_grid.columns = 1

	var added_peers: Dictionary = {}

	if player_nodes.size() > 0:
		section_title.text = "In this server (" + str(player_nodes.size()) + ")"
		for p_node in player_nodes:
			var p_peer_id: int = p_node.name.to_int()
			if p_peer_id in added_peers:
				continue
			added_peers[p_peer_id] = true
			
			var is_me: bool = (p_peer_id == my_peer_id or p_node.name == str(my_peer_id))
			var uname: String = ""
			if p_node.get("player_username"):
				uname = str(p_node.get("player_username"))
			elif p_node.get("username"):
				uname = str(p_node.get("username"))
				
			if uname.is_empty() or uname == p_node.name:
				uname = my_name if is_me else ("Player " + str(p_peer_id))
				
			var p_owner: bool = p_node.get("is_owner") if p_node.get("is_owner") != null else false
			_create_player_card(uname, is_me, p_owner, p_peer_id)
	else:
		section_title.text = "In this server (1)"
		_create_player_card(my_name, true, net_mgr.is_owner if net_mgr else false, my_peer_id)

func _create_player_card(username: String, is_local: bool, is_owner_user: bool, peer_id: int) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(170, 175) if is_grid_view else Vector2(0, 56)
	
	# Apply website styled panel card
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.18, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.28, 0.45, 0.5)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	
	if is_grid_view:
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		margin.add_child(vbox)
		
		var icon_lbl := Label.new()
		icon_lbl.text = "👑 🧑‍🚀" if is_owner_user else "🧑‍🚀"
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 30)
		vbox.add_child(icon_lbl)
		
		var name_lbl := Label.new()
		name_lbl.text = username + (" (You)" if is_local else "")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(name_lbl)
		
		var handle_lbl := Label.new()
		handle_lbl.text = "@" + username.to_lower()
		handle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		handle_lbl.add_theme_font_size_override("font_size", 10)
		handle_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
		vbox.add_child(handle_lbl)
		
		if not is_local:
			var btn_box := HBoxContainer.new()
			btn_box.add_theme_constant_override("separation", 4)
			
			var friend_btn := Button.new()
			friend_btn.text = "➕"
			friend_btn.tooltip_text = "Add Friend"
			friend_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			friend_btn.pressed.connect(func(): friend_btn.text = "✔")
			btn_box.add_child(friend_btn)

			var is_muted: bool = muted_player_ids.get(peer_id, false)
			var mute_btn := Button.new()
			mute_btn.text = "🔇" if is_muted else "🎙️"
			mute_btn.tooltip_text = "Toggle Voice Mute for " + username
			mute_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mute_btn.pressed.connect(func():
				var new_state: bool = not muted_player_ids.get(peer_id, false)
				muted_player_ids[peer_id] = new_state
				mute_btn.text = "🔇" if new_state else "🎙️"
			)
			btn_box.add_child(mute_btn)
			vbox.add_child(btn_box)
	else:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		margin.add_child(hbox)
		
		var icon_lbl := Label.new()
		icon_lbl.text = "👑 🧑‍🚀" if is_owner_user else "🧑‍🚀"
		icon_lbl.add_theme_font_size_override("font_size", 20)
		hbox.add_child(icon_lbl)
		
		var name_lbl := Label.new()
		name_lbl.text = username + " (@" + username.to_lower() + ")" + (" (You)" if is_local else "")
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		if not is_local:
			var friend_btn := Button.new()
			friend_btn.text = "➕ Add Friend"
			friend_btn.pressed.connect(func(): friend_btn.text = "✔ Sent")
			hbox.add_child(friend_btn)

			var is_muted: bool = muted_player_ids.get(peer_id, false)
			var mute_btn := Button.new()
			mute_btn.text = "🔇 Muted" if is_muted else "🎙️ Mute"
			mute_btn.pressed.connect(func():
				var new_state: bool = not muted_player_ids.get(peer_id, false)
				muted_player_ids[peer_id] = new_state
				mute_btn.text = "🔇 Muted" if new_state else "🎙️ Mute"
			)
			hbox.add_child(mute_btn)
			
	players_grid.add_child(card)

func _on_invite_friends_pressed() -> void:
	DisplayServer.clipboard_set("https://www.luani.fyi/join")
	if invite_friends_btn:
		invite_friends_btn.text = "✔ Link Copied!"
		await get_tree().create_timer(2.0).timeout
		invite_friends_btn.text = "👥 Invite Friends"

func _on_mute_all_pressed() -> void:
	is_voice_muted_all = not is_voice_muted_all
	var voice_bus := AudioServer.get_bus_index("Voice")
	if voice_bus >= 0:
		AudioServer.set_bus_mute(voice_bus, is_voice_muted_all)
	if mute_all_btn:
		mute_all_btn.text = "🔇 Voice: Unmute All" if is_voice_muted_all else "🔊 Voice: Mute All"

func _on_toggle_view_mode() -> void:
	is_grid_view = not is_grid_view
	if view_mode_btn:
		view_mode_btn.text = "📑 List View" if is_grid_view else "🔳 Grid View"
	_refresh_players_list()

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_resume_pressed() -> void:
	hide()
	if is_shift_lock_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_leave_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.disconnect_network()
	multiplayer.multiplayer_peer = null
	print("[Luani PauseMenu] Disconnected network peer. Quitting client window.")
	get_tree().quit()

func _on_respawn_pressed() -> void:
	hide()
	if is_shift_lock_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	var my_peer_id := multiplayer.get_unique_id()
	var player_node: Node3D = get_node_or_null("/root/GameWorld/Players/" + str(my_peer_id))
	if not player_node:
		player_node = get_node_or_null("/root/Main/Players/" + str(my_peer_id))
		
	if player_node:
		player_node.global_position = Vector3(0, 2, 0)
		player_node.velocity = Vector3.ZERO
		print("[Luani PauseMenu] Respawned local player avatar at spawn location.")

func _on_shift_lock_toggled(pressed: bool) -> void:
	is_shift_lock_enabled = pressed
	if pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_game_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var linear_val := value / 100.0
		var db_val := linear_to_db(linear_val)
		AudioServer.set_bus_volume_db(bus_idx, db_val)
		volume_label.text = "Game Sound Volume: " + str(int(value)) + "%"

func _on_voice_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Voice")
	if bus_idx >= 0:
		var linear_val := value / 100.0
		var db_val := linear_to_db(linear_val)
		AudioServer.set_bus_volume_db(bus_idx, db_val)
		voice_volume_label.text = "Voice Chat Volume: " + str(int(value)) + "%"
