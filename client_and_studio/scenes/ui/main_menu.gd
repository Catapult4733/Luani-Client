# client_and_studio/scenes/ui/main_menu.gd
extends CanvasLayer

## Native Mobile & Desktop Main Menu Controller matching luani.fyi Web Aesthetic

@onready var tab_play_btn: Button = %TabPlayBtn
@onready var tab_profile_btn: Button = %TabProfileBtn
@onready var tab_settings_btn: Button = %TabSettingsBtn

@onready var panel_play: Control = %PanelPlay
@onready var panel_profile: Control = %PanelProfile
@onready var panel_settings: Control = %PanelSettings

# Play / Server Browser Elements
@onready var refresh_btn: Button = %RefreshBtn
@onready var server_cards_vbox: VBoxContainer = %ServerCardsVBox
@onready var ip_input: LineEdit = %IPInput
@onready var port_input: LineEdit = %PortInput
@onready var direct_connect_btn: Button = %DirectConnectBtn
@onready var status_footer: Label = %StatusFooter

# Profile Customizer Elements
@onready var username_edit: LineEdit = %UsernameEdit
@onready var save_profile_btn: Button = %SaveProfileBtn
@onready var color_head_btn: ColorPickerButton = %ColorHeadBtn
@onready var color_torso_btn: ColorPickerButton = %ColorTorsoBtn
@onready var color_legs_btn: ColorPickerButton = %ColorLegsBtn

# Settings Elements
@onready var volume_slider: HSlider = %VolumeSlider
@onready var graphics_option: OptionButton = %GraphicsOption
@onready var sensitivity_slider: HSlider = %SensitivitySlider

var profile_save_path: String = "user://user_profile.json"
var current_user_profile: Dictionary = {
	"username": "LuaniPlayer",
	"colors": {
		"head": "#e0ac69",
		"torso": "#0000ff",
		"left_arm": "#e0ac69",
		"right_arm": "#e0ac69",
		"left_leg": "#00ff00",
		"right_leg": "#00ff00"
	}
}

var backend_api_url: String = "https://www.luani.fyi/api/servers/active"

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		hide()
		return

	show()

	# Connect Tab Buttons
	tab_play_btn.pressed.connect(func(): _switch_tab("play"))
	tab_profile_btn.pressed.connect(func(): _switch_tab("profile"))
	tab_settings_btn.pressed.connect(func(): _switch_tab("settings"))

	# Connect Play Actions
	refresh_btn.pressed.connect(_fetch_active_servers)
	direct_connect_btn.pressed.connect(_on_direct_connect_pressed)

	# Connect Profile Actions
	save_profile_btn.pressed.connect(_save_user_profile)
	if color_head_btn: color_head_btn.color_changed.connect(func(c): current_user_profile.colors["head"] = c.to_html())
	if color_torso_btn: color_torso_btn.color_changed.connect(func(c): current_user_profile.colors["torso"] = c.to_html())
	if color_legs_btn: color_legs_btn.color_changed.connect(func(c): current_user_profile.colors["left_leg"] = c.to_html(); current_user_profile.colors["right_leg"] = c.to_html())

	# Connect Settings Actions
	volume_slider.value_changed.connect(_on_volume_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	_setup_graphics_options()

	_load_user_profile()
	_switch_tab("play")
	_fetch_active_servers()

func _switch_tab(tab_name: String) -> void:
	panel_play.visible = (tab_name == "play")
	panel_profile.visible = (tab_name == "profile")
	panel_settings.visible = (tab_name == "settings")

	var active_style: StyleBoxFlat = preload("res://scenes/ui/main_menu.tscn").instantiate().get_node("RootControl/MainVBox/HeaderPanel/HeaderMargin/HeaderHBox/TabsHBox/TabPlayBtn").get_theme_stylebox("normal").duplicate()
	var normal_style: StyleBoxFlat = preload("res://scenes/ui/main_menu.tscn").instantiate().get_node("RootControl/MainVBox/HeaderPanel/HeaderMargin/HeaderHBox/TabsHBox/TabProfileBtn").get_theme_stylebox("normal").duplicate()

	tab_play_btn.add_theme_stylebox_override("normal", active_style if tab_name == "play" else normal_style)
	tab_profile_btn.add_theme_stylebox_override("normal", active_style if tab_name == "profile" else normal_style)
	tab_settings_btn.add_theme_stylebox_override("normal", active_style if tab_name == "settings" else normal_style)

func _fetch_active_servers() -> void:
	status_footer.text = "Status: Fetching active server list from luani.fyi..."
	_clear_server_cards()

	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_servers_http_completed)
	
	var err := http_request.request(backend_api_url)
	if err != OK:
		status_footer.text = "Status: Could not connect to Luani API."
		http_request.queue_free()

func _clear_server_cards() -> void:
	for child in server_cards_vbox.get_children():
		child.queue_free()

func _on_servers_http_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_clear_server_cards()
	status_footer.text = "Status: Active servers loaded."

	if response_code != 200:
		_add_empty_card("Offline / Local Standalone Server Active")
		return

	var json_str := body.get_string_from_utf8()
	var parsed = JSON.parse_string(json_str)

	if not (parsed is Array) or parsed.is_empty():
		_add_empty_card("No public servers active right now. Connect directly below!")
		return

	for server in parsed:
		if server is Dictionary:
			_create_server_card(server)

func _create_server_card(server: Dictionary) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.21, 0.3, 0.7)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.24, 0.32, 0.45, 0.6)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = server.get("name", "Luani World")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	info_vbox.add_child(name_lbl)

	var sub_lbl := Label.new()
	var players: int = server.get("players", 0)
	var max_p: int = server.get("max_players", 12)
	var ip: String = server.get("ip", "127.0.0.1")
	var port: int = server.get("port", 7777)
	sub_lbl.text = "👥 %d / %d Players   •   %s:%d" % [players, max_p, ip, port]
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.8))
	info_vbox.add_child(sub_lbl)

	hbox.add_child(info_vbox)

	var connect_btn := Button.new()
	connect_btn.text = "⚡ Connect"
	connect_btn.custom_minimum_size = Vector2(110, 46)
	connect_btn.add_theme_font_size_override("font_size", 14)
	connect_btn.pressed.connect(func():
		_connect_to_server(ip, port, server.get("auth_token", ""))
	)
	hbox.add_child(connect_btn)

	margin.add_child(hbox)
	card.add_child(margin)
	server_cards_vbox.add_child(card)

func _add_empty_card(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.8))
	server_cards_vbox.add_child(lbl)

func _on_direct_connect_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	var port := port_input.text.to_int()
	if ip != "" and port > 0:
		_connect_to_server(ip, port, "")

func _connect_to_server(ip: String, port: int, auth: String) -> void:
	status_footer.text = "Status: Connecting to " + ip + ":" + str(port) + "..."
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.local_username = current_user_profile.get("username", "LuaniPlayer")
		if current_user_profile.get("colors") is Dictionary:
			net_mgr.local_avatar_colors = current_user_profile.get("colors")

	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.connect_to_server(ip, port, auth)
		hide()

func _load_user_profile() -> void:
	if FileAccess.file_exists(profile_save_path):
		var file := FileAccess.open(profile_save_path, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				current_user_profile = parsed
				if username_edit and current_user_profile.get("username", "") != "":
					username_edit.text = current_user_profile.get("username")
				if current_user_profile.get("colors") is Dictionary:
					var colors: Dictionary = current_user_profile.get("colors")
					if color_head_btn and colors.has("head"): color_head_btn.color = Color.html(colors["head"])
					if color_torso_btn and colors.has("torso"): color_torso_btn.color = Color.html(colors["torso"])
					if color_legs_btn and colors.has("left_leg"): color_legs_btn.color = Color.html(colors["left_leg"])

func _save_user_profile() -> void:
	if username_edit:
		current_user_profile["username"] = username_edit.text.strip_edges()
	var file := FileAccess.open(profile_save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_user_profile, "  "))
		status_footer.text = "Status: Profile saved successfully!"

func _setup_graphics_options() -> void:
	if graphics_option:
		graphics_option.clear()
		graphics_option.add_item("Mobile Fast (Low GFX)")
		graphics_option.add_item("Mobile Balanced (Med GFX)")
		graphics_option.add_item("Mobile High Quality (High GFX)")
		graphics_option.select(1)

func _on_volume_changed(val: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(val))

func _on_sensitivity_changed(val: float) -> void:
	status_footer.text = "Status: Touch sensitivity set to %.1fx" % val
