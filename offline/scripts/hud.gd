extends CanvasLayer
## Offline HUD: local chat, truthful one-player roster, settings, original avatar preview.
const AvatarScript = preload("res://scripts/avatar.gd")
const INK := Color("f5f4fa")
const MUTED := Color("aaa7be")
const ACCENT := Color("a98aff")
const SURFACE := Color("20202a")
var player
var root: Control
var menu_panel: PanelContainer
var menu_dimmer: ColorRect
var chat_panel: PanelContainer
var chat_log: RichTextLabel
var chat_input: LineEdit
var leaderboard_panel: PanelContainer
var avatar_panel: PanelContainer
var avatar_viewport: SubViewport
var avatar_preview: Node3D
var crosshair: Label
var status_label: Label
var roster_name: Label
var leaderboard_name: Label
var avatar_name: Label
var leave_dialog: ConfirmationDialog
var _messages: Array[String] = []
var _name_input: LineEdit
var _volume_label: Label
var _leaderboard_button: Button
var _menu_tabs: TabContainer
var _menu_button: Button
var _chat_button: Button
var _brand_panel: PanelContainer
var _help_panel: PanelContainer
var _camera_label: Label

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_topbar()
	_build_chat()
	_build_leaderboard()
	_build_menu()
	_build_avatar_view()
	leave_dialog = ConfirmationDialog.new()
	leave_dialog.title = "Leave Luani?"
	leave_dialog.dialog_text = "Leave this offline baseplate and close Luani Client?"
	leave_dialog.ok_button_text = "Leave game"
	leave_dialog.confirmed.connect(_leave_game)
	leave_dialog.canceled.connect(_update_controls)
	leave_dialog.visibility_changed.connect(_update_controls)
	root.add_child(leave_dialog)
	crosshair = _label("·", 32, INK)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	_help_panel = _panel()
	_help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_help_panel)
	status_label = _label("", 12, MUTED)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_panel.add_child(status_label)
	SessionState.preferences_changed.connect(_preferences_updated)
	player.shift_lock_changed.connect(func(_active: bool) -> void: _update_controls())
	player.camera_mode_changed.connect(func(_active: bool) -> void: _update_controls())
	root.resized.connect(_layout)
	_layout()
	_update_controls()

func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 17
	for kind: String in ["Label", "Button", "CheckBox", "LineEdit", "TabContainer", "TabBar", "RichTextLabel"]:
		theme.set_color("font_color", kind, INK)
		theme.set_color("font_hover_color", kind, INK)
		theme.set_color("font_focus_color", kind, INK)
	theme.set_color("font_disabled_color", "Button", Color("777487"))
	theme.set_stylebox("normal", "Button", _style(Color("30303d"), 10))
	theme.set_stylebox("hover", "Button", _style(Color("424051"), 10))
	theme.set_stylebox("pressed", "Button", _style(Color("594586"), 10))
	theme.set_stylebox("disabled", "Button", _style(Color("272730"), 10))
	var focus := _style(Color(0, 0, 0, 0), 10)
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("normal", "LineEdit", _style(Color("14141c"), 8))
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("selection_color", "LineEdit", Color("554179"))
	theme.set_font_size("normal_font_size", "RichTextLabel", 15)
	for kind: String in ["TabBar", "TabContainer"]:
		theme.set_stylebox("tab_selected", kind, _style(Color("554179"), 9))
		theme.set_stylebox("tab_unselected", kind, _style(Color("242430"), 9))
		theme.set_stylebox("tab_hovered", kind, _style(Color("363344"), 9))
	theme.set_stylebox("slider", "HSlider", _style(Color("353344"), 4))
	theme.set_stylebox("grabber_area", "HSlider", _style(ACCENT, 4))
	theme.set_stylebox("panel", "TabContainer", _style(SURFACE, 10))
	return theme

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = Color(1, 1, 1, 0.07)
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var surface := _style(Color(0.075, 0.075, 0.105, 0.94), 18)
	surface.shadow_color = Color(0, 0, 0, 0.22)
	surface.shadow_size = 12
	surface.shadow_offset = Vector2(0, 4)
	surface.content_margin_left = 20
	surface.content_margin_right = 20
	surface.content_margin_top = 18
	surface.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", surface)
	return panel

func _vbox(gap: int = 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	return box

func _label(text: String, size: int = 17, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: Callable, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(action)
	return button

func _icon_button(asset: String, title: String, action: Callable) -> Button:
	var button := _button("", action, title)
	button.name = asset.capitalize() + "Button"
	button.custom_minimum_size = Vector2(64, 64)
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	# Decode supplied SVG bytes directly: no editor import/cache or Godot export needed.
	var image := Image.new()
	var source := FileAccess.get_file_as_string("res://assets/ui/" + asset + ".svg")
	if image.load_svg_from_string(source) == OK:
		button.icon = ImageTexture.create_from_image(image)
	else:
		button.text = title.get_slice(" · ", 0)
		push_warning("Could not load Luani UI icon: " + asset)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 56)
	for state: String in ["normal", "hover", "pressed"]:
		var color := Color(0, 0, 0, 0) if state == "normal" else Color(0.65, 0.48, 1.0, 0.24 if state == "hover" else 0.42)
		var style := _style(color, 32)
		style.set_content_margin_all(4)
		style.border_color = ACCENT if state == "pressed" else Color(1, 1, 1, 0.10)
		button.add_theme_stylebox_override(state, style)
	return button

func _build_topbar() -> void:
	var left := HBoxContainer.new()
	left.position = Vector2(20, 20)
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)
	_menu_button = _icon_button("menu", "Menu · Esc", _toggle_menu)
	_chat_button = _icon_button("chat", "Chat · Enter or / to type", _toggle_chat)
	left.add_child(_menu_button)
	left.add_child(_chat_button)
	_brand_panel = _panel()
	_brand_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_brand_panel)
	var brand := _vbox(3)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brand_panel.add_child(brand)
	var badge := _label("LUANI  /  OFFLINE BASEPLATE", 12, ACCENT)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(badge)
	_camera_label = _label("", 12, MUTED)
	_camera_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camera_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(_camera_label)
	_leaderboard_button = _icon_button("leaderboard", "Leaderboard · Tab", _toggle_leaderboard)
	_leaderboard_button.size = Vector2(64, 64)
	root.add_child(_leaderboard_button)

func _build_chat() -> void:
	chat_panel = _panel()
	chat_panel.visible = false
	root.add_child(chat_panel)
	var box := _vbox(8)
	chat_panel.add_child(box)
	box.add_child(_label("Chat", 20))
	var note := _label("LOCAL ONLY  ·  Unmoderated", 12, ACCENT)
	box.add_child(note)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = false
	chat_log.scroll_following = true
	chat_log.selection_enabled = true
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.custom_minimum_size.y = 145
	chat_log.text = "No messages yet. Press Enter to say hello."
	chat_log.add_theme_constant_override("line_separation", 6)
	box.add_child(chat_log)
	var row := HBoxContainer.new()
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Message this offline session…"
	chat_input.max_length = 240
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.custom_minimum_size.y = 40
	chat_input.text_submitted.connect(_send_chat)
	chat_input.focus_entered.connect(_update_controls)
	chat_input.focus_exited.connect(_update_controls)
	row.add_child(chat_input)
	row.add_child(_button("Send", func() -> void: _send_chat(chat_input.text)))
	box.add_child(row)

func _build_leaderboard() -> void:
	leaderboard_panel = _panel()
	leaderboard_panel.visible = false
	root.add_child(leaderboard_panel)
	var box := _vbox(10)
	leaderboard_panel.add_child(box)
	box.add_child(_label("Leaderboard", 20))
	box.add_child(_label("1 PLAYER  ·  OFFLINE", 12, ACCENT))
	leaderboard_name = _label(SessionState.display_name + "  (You)", 17)
	leaderboard_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(leaderboard_name)


func _build_menu() -> void:
	menu_dimmer = ColorRect.new()
	menu_dimmer.color = Color(0.035, 0.035, 0.055, 0.62)
	menu_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_dimmer.visible = false
	root.add_child(menu_dimmer)
	menu_panel = _panel()
	menu_panel.visible = false
	root.add_child(menu_panel)
	var box := _vbox(14)
	menu_panel.add_child(box)
	var header := HBoxContainer.new()
	var title := _label("Game menu", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("×", _close_menu, "Resume · Esc"))
	box.add_child(header)
	box.add_child(_label("Your baseplate. Your pace.", 14, MUTED))
	_menu_tabs = TabContainer.new()
	_menu_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_menu_tabs)
	_build_settings_page()
	_build_players_page()
	_build_menu_actions(box)
	var footer := _label("OFFLINE PREVIEW  ·  " + str(ProjectSettings.get_setting("application/config/version", "")) + "  ·  Esc to resume", 12, MUTED)
	box.add_child(footer)

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var box := _vbox(16)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return box

func _build_settings_page() -> void:
	var box := _page("Settings")
	box.add_child(_label("CONTROLS", 12, ACCENT))
	var shift_row := HBoxContainer.new()
	var shift_text := _label("Enable shift-lock keybind", 17)
	shift_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shift_row.add_child(shift_text)
	var shift_toggle := CheckBox.new()
	shift_toggle.text = "Ctrl"
	shift_toggle.button_pressed = SessionState.shift_lock_enabled
	shift_toggle.toggled.connect(func(value: bool) -> void: SessionState.set_shift_lock_enabled(value))
	shift_row.add_child(shift_toggle)
	box.add_child(shift_row)
	var help := _label("Enables Ctrl to toggle shoulder-camera shift lock. Shift still runs.", 13, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	box.add_child(_label("AUDIO", 12, ACCENT))
	_volume_label = _label("Game volume: %d%%" % int(SessionState.game_volume * 100.0), 17)
	box.add_child(_volume_label)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.value = SessionState.game_volume * 100.0
	volume.custom_minimum_size.y = 28
	volume.value_changed.connect(func(value: float) -> void:
		SessionState.set_volume(value / 100.0)
		_volume_label.text = "Game volume: %d%%" % int(value)
	)
	volume.drag_ended.connect(func(_changed: bool) -> void: SessionState.save_preferences())
	box.add_child(volume)
	box.add_child(_label("YOUR OFFLINE NAME", 12, ACCENT))
	_name_input = LineEdit.new()
	_name_input.text = SessionState.display_name
	_name_input.max_length = 24
	_name_input.custom_minimum_size.y = 42
	_name_input.text_submitted.connect(func(value: String) -> void: SessionState.set_display_name(value))
	_name_input.focus_exited.connect(func() -> void: SessionState.set_display_name(_name_input.text))
	box.add_child(_name_input)

func _build_menu_actions(box: VBoxContainer) -> void:
	# Keep core actions visible even when the settings page needs to scroll.
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	var resume := _button("Resume game", _close_menu)
	resume.add_theme_stylebox_override("normal", _style(Color("6740b4"), 10))
	resume.add_theme_stylebox_override("hover", _style(Color("8056cf"), 10))
	actions.add_child(resume)
	actions.add_child(_button("Respawn", _respawn))
	var leave := _button("Leave game", _confirm_leave)
	leave.add_theme_color_override("font_color", Color("ffa3b1"))
	actions.add_child(leave)
	box.add_child(actions)

func _build_players_page() -> void:
	var box := _page("Players")
	box.add_child(_label("Players in this session", 20))
	var hint := _label("This is an offline session. Only your local character is present.", 14, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	roster_name = _label(SessionState.display_name + "  (You)", 22)
	roster_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(roster_name)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	actions.add_child(_button("View avatar", _show_avatar))
	for text: String in ["Block", "Send friend request", "Report"]:
		var button := _button(text, func() -> void: pass)
		button.disabled = true
		button.tooltip_text = "Unavailable offline. You cannot use this action on yourself."
		actions.add_child(button)
	box.add_child(actions)
	var explanation := _label("Online social actions will require multiplayer and a verified account. Nothing is sent to a server in this build.", 14, MUTED)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation)

func _build_avatar_view() -> void:
	avatar_panel = _panel()
	avatar_panel.visible = false
	root.add_child(avatar_panel)
	var box := _vbox(12)
	avatar_panel.add_child(box)
	avatar_name = _label(SessionState.display_name + "'s avatar", 22)
	avatar_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(avatar_name)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(280, 250)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(container)
	avatar_viewport = SubViewport.new()
	avatar_viewport.size = Vector2i(480, 340)
	avatar_viewport.own_world_3d = true
	avatar_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(avatar_viewport)
	var preview_root := Node3D.new()
	avatar_viewport.add_child(preview_root)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("252634")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("e5e0ff")
	settings.ambient_light_energy = 0.85
	environment.environment = settings
	preview_root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.3
	preview_root.add_child(light)
	avatar_preview = AvatarScript.new()
	preview_root.add_child(avatar_preview)
	var camera := Camera3D.new()
	camera.position = Vector3(3.4, 2.4, -6.0)
	camera.fov = 35
	preview_root.add_child(camera)
	camera.look_at(Vector3(0, 1.55, 0), Vector3.UP)
	camera.current = true
	var caption := _label("Original Luani six-part rig · procedural animation", 13, MUTED)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(caption)
	box.add_child(_button("Back to players", _hide_avatar))

func _layout() -> void:
	var screen := root.get_viewport_rect().size
	if not is_instance_valid(menu_panel):
		return
	menu_panel.size = Vector2(minf(720, screen.x - 48), minf(620, screen.y - 48))
	menu_panel.position = (screen - menu_panel.size) * 0.5
	avatar_panel.size = Vector2(minf(520, screen.x - 40), minf(560, screen.y - 40))
	avatar_panel.position = (screen - avatar_panel.size) * 0.5
	chat_panel.position = Vector2(20, 100)
	chat_panel.size = Vector2(minf(390, screen.x * 0.46), minf(320, screen.y - 190))
	leaderboard_panel.position = Vector2(screen.x - 310, 100)
	leaderboard_panel.size = Vector2(290, 160)
	_leaderboard_button.position = Vector2(screen.x - 84, 20)
	_brand_panel.size = Vector2(320, 78)
	_brand_panel.position = Vector2((screen.x - 320) * 0.5, 20)
	crosshair.position = screen * 0.5 - crosshair.get_combined_minimum_size() * 0.5
	status_label.text = "WASD move  ·  Space jump  ·  Shift run  ·  Ctrl shift lock  ·  RMB look  ·  Scroll zoom  ·  Enter chat" if screen.x >= 1100 else "WASD  ·  Space  ·  Shift  ·  Ctrl  ·  Enter chat  ·  Esc menu"
	_help_panel.size = Vector2.ZERO
	_help_panel.position = Vector2((screen.x - _help_panel.get_combined_minimum_size().x) * 0.5, screen.y - 60)

func _input(event: InputEvent) -> void:
	if leave_dialog.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if avatar_panel.visible:
				_hide_avatar()
			elif chat_input.has_focus():
				chat_input.release_focus()
			else:
				_toggle_menu()
			get_viewport().set_input_as_handled()
		elif not menu_panel.visible and not avatar_panel.visible:
			if (event.keycode == KEY_ENTER or event.keycode == KEY_SLASH) and not chat_input.has_focus():
				chat_panel.show()
				chat_input.grab_focus()
				_update_controls()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_TAB and not chat_input.has_focus():
				_toggle_leaderboard()
				get_viewport().set_input_as_handled()

func _toggle_menu() -> void:
	if menu_panel.visible:
		_close_menu()
	else:
		chat_input.release_focus()
		_name_input.text = SessionState.display_name
		menu_panel.show()
		menu_dimmer.show()
		_update_controls()

func _close_menu() -> void:
	_name_input.release_focus()
	SessionState.set_display_name(_name_input.text)
	SessionState.save_preferences()
	menu_panel.hide()
	avatar_panel.hide()
	menu_dimmer.hide()
	_update_controls()

func _toggle_chat() -> void:
	chat_panel.visible = not chat_panel.visible
	if not chat_panel.visible:
		chat_input.release_focus()
	_update_controls()

func _toggle_leaderboard() -> void:
	leaderboard_panel.visible = not leaderboard_panel.visible
	_update_controls()

func _send_chat(text: String) -> void:
	var message := text.strip_edges().replace("\n", " ").replace("\r", " ").substr(0, 240)
	if not message.is_empty():
		_messages.append(SessionState.display_name + " : " + message)
		if _messages.size() > 100:
			_messages.pop_front()
		chat_log.text = "\n".join(PackedStringArray(_messages))
	chat_input.clear()
	chat_input.release_focus()
	_update_controls()

func _respawn() -> void:
	player.respawn()
	_close_menu()

func _confirm_leave() -> void:
	leave_dialog.popup_centered(Vector2i(420, 170))
	_update_controls()

func _leave_game() -> void:
	SessionState.save_preferences()
	get_tree().quit()

func _show_avatar() -> void:
	menu_panel.hide()
	avatar_panel.show()
	_update_controls()

func _hide_avatar() -> void:
	avatar_panel.hide()
	menu_panel.show()
	_menu_tabs.current_tab = 1
	_update_controls()

func _preferences_updated() -> void:
	roster_name.text = SessionState.display_name + "  (You)"
	leaderboard_name.text = roster_name.text
	avatar_name.text = SessionState.display_name + "'s avatar"

func _update_controls() -> void:
	if not is_instance_valid(player) or not is_instance_valid(menu_panel) or not is_instance_valid(_help_panel):
		return
	player.input_blocked = menu_panel.visible or avatar_panel.visible or chat_input.has_focus() or (is_instance_valid(leave_dialog) and leave_dialog.visible)
	player.update_mouse_mode()
	_menu_button.set_pressed_no_signal(menu_panel.visible or avatar_panel.visible)
	_chat_button.set_pressed_no_signal(chat_panel.visible)
	_leaderboard_button.set_pressed_no_signal(leaderboard_panel.visible)
	_camera_label.text = "First person · Scroll out to orbit" if player.first_person else ("Shift lock · Ctrl to unlock" if player.shift_locked else "Third person · Scroll in for first person")
	_help_panel.visible = not menu_panel.visible and not avatar_panel.visible
	if is_instance_valid(crosshair):
		crosshair.visible = (player.shift_locked or player.first_person) and not player.input_blocked

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SessionState.save_preferences()
