# client_and_studio/scripts/core/ui_manager.gd
extends CanvasLayer

## Persistent Autoload UI Manager for Luani Client & Game Worlds
## Manages Chat Overlay, Leaderboard Overlay, and Top-Left Health Bar HUD.

var chat_overlay_inst: Node = null
var leaderboard_overlay_inst: Node = null
var health_hud_inst: Control = null
var health_bar_progress: TextureProgressBar = null
var health_num_label: Label = null

var top_left_hud_inst: Control = null
var mic_btn_inst: Button = null
var is_mic_muted: bool = true

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		print("[Luani UIManager] Running in Headless/Dedicated Server Mode. Bypassing UI overlays.")
		return

	layer = 100 # Draw on top of game scenes
	process_mode = Node.PROCESS_MODE_ALWAYS

	_setup_overlays()
	_setup_health_hud()
	_setup_top_left_hud()
	set_game_ui_visible(false)

func _setup_top_left_hud() -> void:
	var hud_bar := HBoxContainer.new()
	hud_bar.name = "TopLeftHUD"
	hud_bar.position = Vector2(16, 16)
	hud_bar.add_theme_constant_override("separation", 8)

	mic_btn_inst = Button.new()
	mic_btn_inst.name = "MicButton"
	mic_btn_inst.text = "🎙️❌" # Muted by default with red cross
	mic_btn_inst.custom_minimum_size = Vector2(40, 40)
	mic_btn_inst.tooltip_text = "Toggle Microphone (Voice Chat)"
	mic_btn_inst.pressed.connect(_on_mic_toggle_pressed)
	hud_bar.add_child(mic_btn_inst)

	var chat_btn := Button.new()
	chat_btn.name = "ChatButton"
	chat_btn.text = "💬"
	chat_btn.custom_minimum_size = Vector2(40, 40)
	chat_btn.tooltip_text = "Toggle Chat"
	chat_btn.pressed.connect(toggle_chat)
	hud_bar.add_child(chat_btn)

	top_left_hud_inst = hud_bar
	add_child.call_deferred(top_left_hud_inst)

func _on_mic_toggle_pressed() -> void:
	is_mic_muted = not is_mic_muted
	if mic_btn_inst:
		mic_btn_inst.text = "🎙️❌" if is_mic_muted else "🎙️"
	var rec_bus := AudioServer.get_bus_index("Record")
	if rec_bus >= 0:
		AudioServer.set_bus_mute(rec_bus, is_mic_muted)

func _setup_overlays() -> void:
	var chat_scene := load("res://scenes/ui/chat_overlay.tscn")
	if chat_scene and not has_node("ChatOverlay"):
		chat_overlay_inst = chat_scene.instantiate()
		add_child.call_deferred(chat_overlay_inst)

	var tab_scene := load("res://scenes/ui/leaderboard_overlay.tscn")
	if tab_scene and not has_node("LeaderboardOverlay"):
		leaderboard_overlay_inst = tab_scene.instantiate()
		add_child.call_deferred(leaderboard_overlay_inst)

func _setup_health_hud() -> void:
	var hud_card := PanelContainer.new()
	hud_card.name = "HealthHUDCard"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.12, 0.18, 0.85)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.28, 0.4, 0.6)
	hud_card.add_theme_stylebox_override("panel", style)

	hud_card.custom_minimum_size = Vector2(200, 40)
	hud_card.anchor_left = 1.0
	hud_card.anchor_right = 1.0
	hud_card.anchor_top = 0.0
	hud_card.anchor_bottom = 0.0
	hud_card.offset_left = -280.0
	hud_card.offset_top = 16.0
	hud_card.offset_right = -68.0
	hud_card.offset_bottom = 56.0
	hud_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var portrait := Label.new()
	portrait.text = "👤"
	portrait.add_theme_font_size_override("font_size", 16)
	hbox.add_child(portrait)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	health_num_label = Label.new()
	health_num_label.text = "HP: 100 / 100"
	health_num_label.add_theme_font_size_override("font_size", 11)
	health_num_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(health_num_label)

	var pbar := ProgressBar.new()
	pbar.custom_minimum_size = Vector2(0, 10)
	pbar.max_value = 100.0
	pbar.value = 100.0
	pbar.show_percentage = false
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.8, 0.4, 0.9)
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_right = 3
	fill_style.corner_radius_bottom_left = 3
	pbar.add_theme_stylebox_override("fill", fill_style)

	vbox.add_child(pbar)
	health_hud_inst = hud_card
	health_hud_inst.add_child(margin)
	margin.add_child(hbox)
	hbox.add_child(vbox)

	# Hide health HUD initially until player joins game
	health_hud_inst.hide()

	add_child.call_deferred(health_hud_inst)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	if health_hud_inst and is_instance_valid(health_hud_inst):
		health_hud_inst.anchor_left = 1.0
		health_hud_inst.anchor_right = 1.0
		health_hud_inst.anchor_top = 0.0
		health_hud_inst.anchor_bottom = 0.0
		health_hud_inst.offset_left = -280.0
		health_hud_inst.offset_top = 16.0
		health_hud_inst.offset_right = -68.0
		health_hud_inst.offset_bottom = 56.0
		health_hud_inst.grow_horizontal = Control.GROW_DIRECTION_BEGIN

func update_health_bar(current_hp: float, max_hp: float) -> void:
	if health_hud_inst:
		health_hud_inst.show()
	if health_num_label:
		health_num_label.text = "HP: %d / %d" % [int(current_hp), int(max_hp)]
	if health_hud_inst and health_hud_inst.has_node("MarginContainer/HBoxContainer/VBoxContainer/ProgressBar"):
		var pbar: ProgressBar = health_hud_inst.get_node("MarginContainer/HBoxContainer/VBoxContainer/ProgressBar")
		pbar.max_value = max_hp
		pbar.value = current_hp

func toggle_chat() -> void:
	if chat_overlay_inst and chat_overlay_inst.has_method("toggle_chat"):
		chat_overlay_inst.call("toggle_chat")

func toggle_leaderboard() -> void:
	if leaderboard_overlay_inst and leaderboard_overlay_inst.has_method("toggle_leaderboard"):
		leaderboard_overlay_inst.call("toggle_leaderboard")

func set_game_ui_visible(is_visible: bool) -> void:
	visible = is_visible
	if chat_overlay_inst:
		chat_overlay_inst.visible = is_visible
	if leaderboard_overlay_inst:
		leaderboard_overlay_inst.visible = is_visible
	if health_hud_inst:
		health_hud_inst.visible = is_visible
	if top_left_hud_inst:
		top_left_hud_inst.visible = is_visible
