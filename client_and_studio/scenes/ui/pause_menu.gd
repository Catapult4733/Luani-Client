# client_and_studio/scenes/ui/pause_menu.gd
extends CanvasLayer

## In-Game Pause Menu Overlay for Luani Client (Tabbed modern UI)

@onready var leave_button: Button = %LeaveButton
@onready var respawn_button: Button = %RespawnButton
@onready var shift_lock_button: CheckButton = %ShiftLockButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_label: Label = %VolumeLabel
@onready var resume_button: Button = %ResumeButton

# Navigation Tabs
@onready var tab_people_btn: Button = %TabPeopleBtn
@onready var tab_settings_btn: Button = %TabSettingsBtn
@onready var tab_gallery_btn: Button = %TabGalleryBtn
@onready var tab_report_btn: Button = %TabReportBtn
@onready var tab_help_btn: Button = %TabHelpBtn

# Views
@onready var people_view: Control = %PeopleView
@onready var settings_view: Control = %SettingsView
@onready var gallery_view: Control = %GalleryView
@onready var report_view: Control = %ReportView
@onready var help_view: Control = %HelpView

# People View Controls
@onready var invite_friends_btn: Button = %InviteFriendsBtn
@onready var mute_all_btn: Button = %MuteAllBtn
@onready var view_mode_btn: Button = %ViewModeBtn
@onready var section_title: Label = %SectionTitle
@onready var players_grid: GridContainer = %PlayersGrid

# Settings Controls
@onready var fullscreen_btn: CheckButton = %FullscreenBtn

# Gallery Controls
@onready var capture_btn: Button = %CaptureBtn
@onready var gallery_status_label: Label = %GalleryStatusLabel

# Report Controls
@onready var report_reason_option: OptionButton = %ReportReasonOption
@onready var report_details_edit: TextEdit = %ReportDetailsEdit
@onready var submit_report_btn: Button = %SubmitReportBtn

var is_shift_lock_enabled: bool = true
var is_grid_view: bool = true
var is_muted_all: bool = false
var all_tabs: Array = []
var all_views: Array = []

func _ready() -> void:
	layer = 150
	hide()
	
	all_tabs = [tab_people_btn, tab_settings_btn, tab_gallery_btn, tab_report_btn, tab_help_btn]
	all_views = [people_view, settings_view, gallery_view, report_view, help_view]
	
	tab_people_btn.pressed.connect(func(): _switch_tab(0))
	tab_settings_btn.pressed.connect(func(): _switch_tab(1))
	tab_gallery_btn.pressed.connect(func(): _switch_tab(2))
	tab_report_btn.pressed.connect(func(): _switch_tab(3))
	tab_help_btn.pressed.connect(func(): _switch_tab(4))
	
	leave_button.pressed.connect(_on_leave_pressed)
	respawn_button.pressed.connect(_on_respawn_pressed)
	shift_lock_button.toggled.connect(_on_shift_lock_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
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
	if capture_btn:
		capture_btn.pressed.connect(_on_take_screenshot)
	if submit_report_btn:
		submit_report_btn.pressed.connect(_on_submit_report)

	# Initial volume setup
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var current_db := AudioServer.get_bus_volume_db(bus_idx)
		volume_slider.value = db_to_linear(current_db) * 100.0

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
		
	var total_count := player_nodes.size()
	if total_count == 0:
		total_count = 1 # Local player alone
		
	section_title.text = "In this server (" + str(total_count) + ")"
	
	if is_grid_view:
		players_grid.columns = 4
	else:
		players_grid.columns = 1
		
	# Populate local player card
	var net_mgr := get_node_or_null("/root/NetworkManager")
	var my_name: String = net_mgr.local_username if net_mgr else "Player"
	_create_player_card(my_name, true, net_mgr.is_owner if net_mgr else false)
	
	# Populate connected peer player cards
	for p_node in player_nodes:
		var uname: String = p_node.get("username") if p_node.get("username") else p_node.name
		if uname != my_name:
			var p_owner: bool = p_node.get("is_owner") if p_node.get("is_owner") != null else false
			_create_player_card(uname, false, p_owner)

func _create_player_card(username: String, is_local: bool, is_owner_user: bool) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 160) if is_grid_view else Vector2(0, 56)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	
	if is_grid_view:
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 6)
		margin.add_child(vbox)
		
		var icon_lbl := Label.new()
		icon_lbl.text = "👑 🧑‍🚀" if is_owner_user else "🧑‍🚀"
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 32)
		vbox.add_child(icon_lbl)
		
		var name_lbl := Label.new()
		name_lbl.text = username + (" (You)" if is_local else "")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(name_lbl)
		
		var handle_lbl := Label.new()
		handle_lbl.text = "@" + username.to_lower()
		handle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		handle_lbl.add_theme_font_size_override("font_size", 11)
		handle_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		vbox.add_child(handle_lbl)
		
		if not is_local:
			var friend_btn := Button.new()
			friend_btn.text = "➕ Add Friend"
			friend_btn.custom_minimum_size = Vector2(0, 26)
			friend_btn.pressed.connect(func(): friend_btn.text = "✔ Sent")
			vbox.add_child(friend_btn)
	else:
		var hbox := HBoxContainer.new()
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
			
	players_grid.add_child(card)

func _on_invite_friends_pressed() -> void:
	DisplayServer.clipboard_set("https://www.luani.fyi/join")
	if invite_friends_btn:
		invite_friends_btn.text = "✔ Link Copied!"
		await get_tree().create_timer(2.0).timeout
		invite_friends_btn.text = "👥 Invite Friends"

func _on_mute_all_pressed() -> void:
	is_muted_all = not is_muted_all
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, is_muted_all)
	if mute_all_btn:
		mute_all_btn.text = "🔊 Unmute All" if is_muted_all else "🔇 Mute All"

func _on_toggle_view_mode() -> void:
	is_grid_view = not is_grid_view
	if view_mode_btn:
		view_mode_btn.text = "📑 List View" if is_grid_view else "🔳 Grid View"
	_refresh_players_list()

func _on_take_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	var time_str := Time.get_datetime_string_from_system().replace(":", "-")
	var path_str := "user://screenshot_" + time_str + ".png"
	img.save_png(path_str)
	if gallery_status_label:
		gallery_status_label.text = "Screenshot saved to: " + path_str

func _on_submit_report() -> void:
	if report_details_edit and submit_report_btn:
		submit_report_btn.text = "✔ Report Submitted"
		report_details_edit.text = ""
		await get_tree().create_timer(2.0).timeout
		submit_report_btn.text = "🚩 Submit Report"

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
	print("[Luani PauseMenu] Shift Lock toggled: ", pressed)

func _on_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var linear_val := value / 100.0
		var db_val := linear_to_db(linear_val)
		AudioServer.set_bus_volume_db(bus_idx, db_val)
		volume_label.text = "Master Volume: " + str(int(value)) + "%"
