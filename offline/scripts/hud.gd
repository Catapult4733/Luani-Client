extends CanvasLayer
## Offline HUD: local chat, truthful one-player roster, settings, original avatar preview.
const AvatarScript = preload("res://scripts/avatar.gd")
const INK := Color("f5f4fa")
const MUTED := Color("a7abb1")
const ACCENT := Color("a6bbef")
const SURFACE := Color("202225")
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

	SessionState.preferences_changed.connect(_preferences_updated)
	player.shift_lock_changed.connect(func(_active: bool) -> void: _update_controls())
	player.camera_mode_changed.connect(func(_active: bool) -> void: _update_controls())
	root.resized.connect(_layout)
	_layout()
	_update_controls()

func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14
	for kind: String in ["Label", "Button", "CheckBox", "LineEdit", "TabContainer", "TabBar", "RichTextLabel"]:
		theme.set_color("font_color", kind, INK)
		theme.set_color("font_hover_color", kind, INK)
		theme.set_color("font_focus_color", kind, INK)
	theme.set_color("font_disabled_color", "Button", Color("777487"))
	theme.set_stylebox("normal", "Button", _style(Color("2d3035"), 4))
	theme.set_stylebox("hover", "Button", _style(Color("40444a"), 4))
	theme.set_stylebox("pressed", "Button", _style(Color("505660"), 4))
	theme.set_stylebox("disabled", "Button", _style(Color("25272b"), 4))
	var focus := _style(Color(0, 0, 0, 0), 4)
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("normal", "LineEdit", _style(Color("292c30"), 4))
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("selection_color", "LineEdit", Color("344f7b"))
	theme.set_font_size("normal_font_size", "RichTextLabel", 13)
	for kind: String in ["TabBar", "TabContainer"]:
		var selected := _style(Color(0, 0, 0, 0), 0)
		selected.border_color = Color("e3e6ea")
		selected.set_border_width_all(0)
		selected.border_width_bottom = 2
		theme.set_stylebox("tab_selected", kind, selected)
		theme.set_stylebox("tab_unselected", kind, _style(Color(0, 0, 0, 0), 0))
		theme.set_stylebox("tab_hovered", kind, _style(Color("303338"), 0))
	theme.set_stylebox("slider", "HSlider", _style(Color("353344"), 4))
	theme.set_stylebox("grabber_area", "HSlider", _style(ACCENT, 4))
	theme.set_stylebox("panel", "TabContainer", _style(Color(0, 0, 0, 0), 0))
	return theme

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = Color(1, 1, 1, 0.07)
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var surface := _style(Color(0.10, 0.11, 0.12, 0.93), 6)
	surface.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", surface)
	return panel

func _vbox(gap: int = 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	return box

func _label(text: String, size: int = 14, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: Callable, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 30)
	button.pressed.connect(action)
	return button

func _icon_button(asset: String, title: String, action: Callable) -> Button:
	var button := _button("", action, title)
	button.name = asset.capitalize() + "Button"
	button.custom_minimum_size = Vector2(36, 32)
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	# Decode supplied SVG bytes directly: no editor import/cache or Godot export needed.
	var image := Image.new()
	var source := FileAccess.get_file_as_string("res://assets/ui/compact/" + asset + ".svg")
	if image.load_svg_from_string(source) == OK:
		button.icon = ImageTexture.create_from_image(image)
	else:
		button.text = title.get_slice(" · ", 0)
		push_warning("Could not load Luani UI icon: " + asset)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 20)
	for state: String in ["normal", "hover", "pressed"]:
		var color := Color(0.11, 0.12, 0.13, 0.90) if state == "normal" else Color(0.30, 0.32, 0.35, 0.96)
		var style := _style(color, 6)
		style.set_content_margin_all(4)
		style.border_color = ACCENT if state == "pressed" else Color(1, 1, 1, 0.10)
		button.add_theme_stylebox_override(state, style)
	return button

func _build_topbar() -> void:
	var left := HBoxContainer.new()
	left.position = Vector2(12, 12)
	left.add_theme_constant_override("separation", 4)
	root.add_child(left)
	_menu_button = _icon_button("menu", "Menu · Esc", _toggle_menu)
	_chat_button = _icon_button("chat", "Chat · Enter or / to type", _toggle_chat)
	left.add_child(_menu_button)
	left.add_child(_chat_button)

	_leaderboard_button = _icon_button("leaderboard", "Leaderboard · Tab", _toggle_leaderboard)
	_leaderboard_button.size = Vector2(36, 32)
	root.add_child(_leaderboard_button)

func _build_chat() -> void:
	chat_panel = _panel()
	chat_panel.visible = false
	root.add_child(chat_panel)
	var box := _vbox(8)
	chat_panel.add_child(box)
	box.add_child(_label("Local chat", 13))
	var note := _label("Offline · Unmoderated", 11, MUTED)
	box.add_child(note)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = false
	chat_log.scroll_following = true
	chat_log.selection_enabled = true
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.custom_minimum_size.y = 90
	chat_log.text = "No messages yet. Press Enter to say hello."
	chat_log.add_theme_constant_override("line_separation", 3)
	box.add_child(chat_log)
	var row := HBoxContainer.new()
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Type a message…"
	chat_input.max_length = 240
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.custom_minimum_size.y = 30
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
	var box := _vbox(6)
	leaderboard_panel.add_child(box)
	var heading := HBoxContainer.new()
	var title := _label("Players", 12, MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_label("1", 12, MUTED))
	box.add_child(heading)
	leaderboard_name = _label(SessionState.display_name + "  (You)", 14)
	leaderboard_name.clip_text = true
	leaderboard_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	var box := _vbox(8)
	menu_panel.add_child(box)
	_menu_tabs = TabContainer.new()
	_menu_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_menu_tabs)
	_build_players_page()
	_build_settings_page()
	_menu_tabs.current_tab = 1
	_build_menu_actions(box)

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
	var box := _vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return box

func _build_settings_page() -> void:
	var box := _page("Settings")
	box.add_child(_label("CONTROLS", 12, ACCENT))
	var shift_row := HBoxContainer.new()
	var shift_text := _label("Shift-lock keybind", 14)
	shift_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shift_row.add_child(shift_text)
	var shift_toggle := CheckBox.new()
	shift_toggle.text = "Ctrl"
	shift_toggle.button_pressed = SessionState.shift_lock_enabled
	shift_toggle.toggled.connect(func(value: bool) -> void: SessionState.set_shift_lock_enabled(value))
	shift_row.add_child(shift_toggle)
	box.add_child(shift_row)
	var help := _label("Ctrl toggles shift lock when enabled. Shift runs.", 12, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	box.add_child(_label("AUDIO", 12, ACCENT))
	_volume_label = _label("Volume: %d%%" % int(SessionState.game_volume * 100.0), 14)
	box.add_child(_volume_label)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.value = SessionState.game_volume * 100.0
	volume.custom_minimum_size.y = 20
	volume.value_changed.connect(func(value: float) -> void:
		SessionState.set_volume(value / 100.0)
		_volume_label.text = "Volume: %d%%" % int(value)
	)
	volume.drag_ended.connect(func(_changed: bool) -> void: SessionState.save_preferences())
	box.add_child(volume)
	box.add_child(_label("YOUR OFFLINE NAME", 12, ACCENT))
	_name_input = LineEdit.new()
	_name_input.text = SessionState.display_name
	_name_input.max_length = 24
	_name_input.custom_minimum_size.y = 30
	_name_input.text_submitted.connect(func(value: String) -> void: SessionState.set_display_name(value))
	_name_input.focus_exited.connect(func() -> void: SessionState.set_display_name(_name_input.text))
	box.add_child(_name_input)

func _build_menu_actions(box: VBoxContainer) -> void:
	# Keep core actions visible even when the settings page needs to scroll.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var leave := _button("Leave", _confirm_leave)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(leave)
	var respawn := _button("Respawn", _respawn)
	respawn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(respawn)
	var resume := _button("Resume", _close_menu, "Esc")
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume.add_theme_stylebox_override("normal", _style(Color("304a86"), 4))
	resume.add_theme_stylebox_override("hover", _style(Color("3e5d9e"), 4))
	actions.add_child(resume)
	box.add_child(actions)

func _build_players_page() -> void:
	var box := _page("Players")
	box.add_child(_label("In this session", 14))
	var hint := _label("Offline · Only your local player is present.", 12, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	roster_name = _label(SessionState.display_name + "  (You)", 16)
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
	var explanation := _label("Friend requests, blocking and reports are unavailable offline.", 12, MUTED)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation)

func _build_avatar_view() -> void:
	avatar_panel = _panel()
	avatar_panel.visible = false
	root.add_child(avatar_panel)
	var box := _vbox(12)
	avatar_panel.add_child(box)
	avatar_name = _label(SessionState.display_name + "'s avatar", 16)
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
	# Fixed logical pixels: resizing moves anchored panels but never scales them.
	menu_panel.size = Vector2(560, 452)
	menu_panel.position = (screen - menu_panel.size) * 0.5
	avatar_panel.size = Vector2(360, 420)
	avatar_panel.position = (screen - avatar_panel.size) * 0.5
	chat_panel.position = Vector2(12, 56)
	chat_panel.size = Vector2(300, 220)
	leaderboard_panel.position = Vector2(screen.x - 232, 56)
	leaderboard_panel.size = Vector2(220, 76)
	_leaderboard_button.position = Vector2(screen.x - 48, 12)
	crosshair.position = screen * 0.5 - crosshair.get_combined_minimum_size() * 0.5


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
	_menu_tabs.current_tab = 0
	_update_controls()

func _preferences_updated() -> void:
	roster_name.text = SessionState.display_name + "  (You)"
	leaderboard_name.text = roster_name.text
	avatar_name.text = SessionState.display_name + "'s avatar"

func _update_controls() -> void:
	if not is_instance_valid(player) or not is_instance_valid(menu_panel) or not is_instance_valid(_leaderboard_button):
		return
	player.input_blocked = menu_panel.visible or avatar_panel.visible or chat_input.has_focus() or (is_instance_valid(leave_dialog) and leave_dialog.visible)
	player.update_mouse_mode()
	_menu_button.set_pressed_no_signal(menu_panel.visible or avatar_panel.visible)
	_chat_button.set_pressed_no_signal(chat_panel.visible)
	_leaderboard_button.set_pressed_no_signal(leaderboard_panel.visible)

	if is_instance_valid(crosshair):
		crosshair.visible = (player.shift_locked or player.first_person) and not player.input_blocked

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SessionState.save_preferences()
