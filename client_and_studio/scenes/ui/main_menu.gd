# client_and_studio/scenes/ui/main_menu.gd
extends CanvasLayer

## Native 100% Godot Main Menu UI supporting Server List, Profile Customizer, and Settings for Mobile & PC

@onready var tab_servers_btn: Button = %TabServersBtn
@onready var tab_profile_btn: Button = %TabProfileBtn
@onready var tab_settings_btn: Button = %TabSettingsBtn

@onready var panel_servers: Control = %PanelServers
@onready var panel_profile: Control = %PanelProfile
@onready var panel_settings: Control = %PanelSettings

# Server Browser Elements
@onready var server_ip_edit: LineEdit = %ServerIPEdit
@onready var server_port_edit: LineEdit = %ServerPortEdit
@onready var join_custom_btn: Button = %JoinCustomBtn
@onready var official_server_list: VBoxContainer = %OfficialServerList

# Profile Customizer Elements
@onready var username_edit: LineEdit = %UsernameEdit
@onready var save_profile_btn: Button = %SaveProfileBtn
@onready var color_head_btn: ColorPickerButton = %ColorHeadBtn
@onready var color_torso_btn: ColorPickerButton = %ColorTorsoBtn
@onready var color_arms_btn: ColorPickerButton = %ColorArmsBtn
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
	},
	"settings": {
		"volume": 0.8,
		"graphics": 2,
		"sensitivity": 1.0
	}
}

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		hide()
		return

	load_user_profile()
	_setup_tab_buttons()
	_setup_server_browser()
	_setup_customizer()
	_setup_settings()

	# Start on Servers Tab
	_show_tab("servers")

func load_user_profile() -> void:
	if FileAccess.file_exists(profile_save_path):
		var file := FileAccess.open(profile_save_path, FileAccess.READ)
		if file:
			var text := file.get_as_text()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				current_user_profile.merge(parsed, true)

	# Apply loaded username to NetworkManager
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		if current_user_profile.get("username", "") != "":
			net_mgr.local_username = current_user_profile.get("username")
		if current_user_profile.get("colors") is Dictionary:
			net_mgr.local_avatar_colors = current_user_profile.get("colors")

func save_user_profile() -> void:
	if username_edit:
		current_user_profile["username"] = username_edit.text.strip_edges()

	var file := FileAccess.open(profile_save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_user_profile, "\t"))
		file.close()
		print("[Luani MainMenu] Saved user profile: ", current_user_profile.get("username"))

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.local_username = current_user_profile.get("username")
		net_mgr.local_avatar_colors = current_user_profile.get("colors")

func _setup_tab_buttons() -> void:
	if tab_servers_btn: tab_servers_btn.pressed.connect(func(): _show_tab("servers"))
	if tab_profile_btn: tab_profile_btn.pressed.connect(func(): _show_tab("profile"))
	if tab_settings_btn: tab_settings_btn.pressed.connect(func(): _show_tab("settings"))

func _show_tab(tab_name: String) -> void:
	if panel_servers: panel_servers.visible = (tab_name == "servers")
	if panel_profile: panel_profile.visible = (tab_name == "profile")
	if panel_settings: panel_settings.visible = (tab_name == "settings")

func _setup_server_browser() -> void:
	if join_custom_btn:
		join_custom_btn.pressed.connect(func():
			var ip := server_ip_edit.text.strip_edges() if server_ip_edit else "127.0.0.1"
			var port := server_port_edit.text.to_int() if server_port_edit else 7777
			_join_server(ip, port)
		)

	_populate_official_servers()

func _populate_official_servers() -> void:
	if not official_server_list:
		return

	for child in official_server_list.get_children():
		child.queue_free()

	var official_servers := [
		{ "name": "🌐 Official Luani US-East", "ip": "127.0.0.1", "port": 7777, "ping": "24ms" },
		{ "name": "🌐 Official Luani EU-Central", "ip": "127.0.0.1", "port": 7778, "ping": "42ms" },
		{ "name": "⚔️ Luani Sword Arena Place", "ip": "127.0.0.1", "port": 7779, "ping": "18ms" }
	]

	for s in official_servers:
		var btn := Button.new()
		btn.text = "%s (%s) - Join" % [s["name"], s["ping"]]
		btn.custom_minimum_size = Vector2(0, 45)
		var ip_val: String = s["ip"]
		var port_val: int = s["port"]
		btn.pressed.connect(func(): _join_server(ip_val, port_val))
		official_server_list.add_child(btn)

func _join_server(ip: String, port: int) -> void:
	save_user_profile()
	print("[Luani MainMenu] Joining server: ", ip, ":", port)
	hide()
	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("connect_to_server"):
		game_mgr.connect_to_server(ip, port, "")

func _setup_customizer() -> void:
	if username_edit:
		username_edit.text = current_user_profile.get("username", "LuaniPlayer")

	if save_profile_btn:
		save_profile_btn.pressed.connect(save_user_profile)

	var colors: Dictionary = current_user_profile.get("colors", {})
	if color_head_btn:
		color_head_btn.color = Color.html(colors.get("head", "#e0ac69"))
		color_head_btn.color_changed.connect(func(c: Color):
			colors["head"] = "#" + c.to_html(false)
			colors["left_arm"] = "#" + c.to_html(false)
			colors["right_arm"] = "#" + c.to_html(false)
		)

	if color_torso_btn:
		color_torso_btn.color = Color.html(colors.get("torso", "#0000ff"))
		color_torso_btn.color_changed.connect(func(c: Color): colors["torso"] = "#" + c.to_html(false))

	if color_legs_btn:
		color_legs_btn.color = Color.html(colors.get("left_leg", "#00ff00"))
		color_legs_btn.color_changed.connect(func(c: Color):
			colors["left_leg"] = "#" + c.to_html(false)
			colors["right_leg"] = "#" + c.to_html(false)
		)

func _setup_settings() -> void:
	if volume_slider:
		volume_slider.value = current_user_profile.get("settings", {}).get("volume", 0.8)
		volume_slider.value_changed.connect(func(val: float):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(val))
			current_user_profile["settings"]["volume"] = val
		)

	if graphics_option:
		graphics_option.clear()
		graphics_option.add_item("Low (Fastest)")
		graphics_option.add_item("Medium (Balanced)")
		graphics_option.add_item("High (Best Quality)")
		graphics_option.selected = current_user_profile.get("settings", {}).get("graphics", 2)

	if sensitivity_slider:
		sensitivity_slider.value = current_user_profile.get("settings", {}).get("sensitivity", 1.0)
