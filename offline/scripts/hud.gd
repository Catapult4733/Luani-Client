extends CanvasLayer
## Approved Figma overlays + native HUD controls. Inventory is session-only and offline.
const UI = preload("res://scripts/ui_theme.gd")
const Widgets = preload("res://scripts/ui_controls.gd")
const AvatarScript = preload("res://scripts/avatar.gd")
const Catalog = preload("res://scripts/item_catalog.gd")
var player
var inventory
var world
var root: Control
var menu_panel: Panel
var menu_dimmer: ColorRect
var chat_panel: Panel
var chat_log: RichTextLabel
var chat_input: LineEdit
var leaderboard_panel: Panel
var avatar_panel: Panel
var inventory_panel: Panel
var dialog_panel: Panel
var avatar_preview: Node3D
var crosshair: Label
var _menu_button: Button
var _chat_button: Button
var _leaderboard_button: Button
var _inventory_button: Button
var _settings_page: Control
var _players_page: Control
var _players_tab: Button
var _settings_tab: Button
var _name_input: LineEdit
var _volume_label: Label
var _roster_name: Label
var _leaderboard_name: Label
var _avatar_name: Label
var _dialog_title: Label
var _dialog_copy: Label
var _dialog_confirm: Button
var _dialog_action := ""
var _messages: Array[String] = []
var _inventory_slots: Array[Button] = []
var _hotbar_slots: Array[Button] = []
var _inspected_slot: int = -1
var _item_title: Label
var _item_description: Label
var _item_count: Label
var _equip_button: Button
var _drop_button: Button
var _hotbar: HBoxContainer
var _equipped_caption: Label
var _pickup_prompt: PanelContainer
var _pickup_label: Label
var _status_label: Label
var _status_remaining: float = 0.0

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.name = "LuaniHUD"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_chat()
	_build_leaderboard()
	menu_dimmer = ColorRect.new()
	menu_dimmer.name = "ModalDimmer"
	menu_dimmer.color = Color(UI.DARK, 0.48)
	menu_dimmer.z_index = 10
	root.add_child(menu_dimmer)
	menu_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_dimmer.hide()
	_build_menu()
	_build_avatar_view()
	_build_dialog()
	_build_inventory()
	_build_hotbar()
	_build_context_feedback()
	# Last in the scene tree as well as on top visually: dimmer must not eat HUD clicks.
	_build_topbar()
	SessionState.preferences_changed.connect(_preferences_updated)
	inventory.changed.connect(_refresh_inventory)
	world.status_changed.connect(_show_status)
	player.shift_lock_changed.connect(func(_active: bool) -> void: _update_controls())
	player.camera_mode_changed.connect(func(_active: bool) -> void: _update_controls())
	root.resized.connect(_layout)
	_select_page(true)
	_refresh_inventory()
	_layout()
	_update_controls()

func _place(node: Control, parent: Control, rect: Rect2) -> void:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size

func _text(parent: Control, value: String, rect: Rect2, size: int = 14, color: Color = UI.INK, weight: int = 400) -> Label:
	var label := UI.label(value, size, color, weight)
	_place(label, parent, rect)
	return label

func _bounded(label: Label) -> void:
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _panel(parent: Control, name_text: String, dimensions: Vector2, modal: bool = false) -> Panel:
	var panel := Panel.new()
	panel.name = name_text
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", UI.overlay_style())
	panel.z_index = 20 if modal else 0
	parent.add_child(panel)
	panel.hide()
	return panel

func _surface(parent: Control, rect: Rect2, radius: int = 8) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.style(UI.FIELD, radius, Color.TRANSPARENT))
	_place(panel, parent, rect)
	return panel

func _button(parent: Control, text: String, rect: Rect2, action: Callable, kind: String = "neutral") -> Button:
	var b := Button.new()
	b.text = text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if kind != "neutral":
		var fill := UI.ACCENT if kind == "primary" else UI.DANGER
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			var color := fill.lightened(0.08) if state == "hover" else fill.darkened(0.10) if state == "pressed" else fill
			b.add_theme_stylebox_override(state, UI.style(color))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(state, UI.DARK)
	b.pressed.connect(action)
	_place(b, parent, rect)
	return b

func _asset(parent: Control, name_text: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = UI.texture(name_text)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(image, parent, rect)
	return image

func _small_icon(parent: Control, asset: String, rect: Rect2, action: Callable) -> Button:
	var b := _button(parent, "", rect, action)
	b.icon = UI.texture(asset)
	b.add_theme_constant_override("icon_max_width", 18)
	for state: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, UI.style(Color.TRANSPARENT if state == "normal" else UI.FIELD, 6, Color.TRANSPARENT))
	return b

func _hud_button(asset: String, title: String, shortcut: String, action: Callable, figma: bool = true) -> Button:
	var b := Widgets.HudButton.new()
	b.name = title + "Button"
	b.glyph = UI.texture(asset, figma)
	b.title = title
	b.shortcut = shortcut
	b.tooltip_text = title
	b.pressed.connect(action)
	b.z_index = 30
	root.add_child(b)
	return b

func _build_topbar() -> void:
	_menu_button = _hud_button("menu", "Menu", "Esc", _toggle_menu)
	_menu_button.position = Vector2(16, 16)
	_chat_button = _hud_button("chat", "Chat", "/", _toggle_chat)
	_chat_button.position = Vector2(58, 16)
	_inventory_button = _hud_button("backpack", "Inventory", "I", _toggle_inventory, false)
	_leaderboard_button = _hud_button("leaderboard", "Leaderboard", "Tab", _toggle_leaderboard)

func _build_chat() -> void:
	chat_panel = _panel(root, "ChatPanel", Vector2(300, 220))
	_text(chat_panel, "Chat", Rect2(12, 12, 42, 20), 14, UI.INK, 600)
	_text(chat_panel, "LOCAL ONLY", Rect2(64, 14, 160, 16), 10, UI.MUTED, 700)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = false
	chat_log.scroll_following = true
	chat_log.selection_enabled = true
	chat_log.add_theme_constant_override("line_separation", 6)
	chat_log.text = "Only visible on this device.\nPress Enter or / to say hello."
	_place(chat_log, chat_panel, Rect2(12, 42, 276, 112))
	var input_bg := _surface(chat_panel, Rect2(12, 166, 276, 34))
	input_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Say something…"
	chat_input.max_length = 240
	chat_input.add_theme_font_size_override("font_size", 13)
	chat_input.text_submitted.connect(_send_chat)
	chat_input.focus_entered.connect(_update_controls)
	chat_input.focus_exited.connect(_update_controls)
	_place(chat_input, input_bg, Rect2(0, 0, 240, 34))
	var send := _small_icon(input_bg, "send", Rect2(243, 5, 24, 24), func() -> void: _send_chat(chat_input.text))
	send.tooltip_text = "Send local message"
	send.add_theme_stylebox_override("normal", UI.style(UI.ACCENT_SOFT, 6, Color.TRANSPARENT))

func _build_leaderboard() -> void:
	leaderboard_panel = _panel(root, "LeaderboardPanel", Vector2(240, 112))
	_text(leaderboard_panel, "Players", Rect2(12, 12, 180, 18), 13, UI.INK, 600)
	var count := _text(leaderboard_panel, "1", Rect2(210, 12, 18, 18), 11, UI.MUTED)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_asset(leaderboard_panel, "avatar-leaderboard", Rect2(12, 43, 26, 36))
	_leaderboard_name = _text(leaderboard_panel, SessionState.display_name, Rect2(48, 43, 126, 19), 13, UI.INK, 600)
	_bounded(_leaderboard_name)
	_text(leaderboard_panel, "Local player", Rect2(48, 62, 126, 17), 11, UI.MUTED)
	_text(leaderboard_panel, "YOU", Rect2(184, 54, 34, 16), 10, UI.ACCENT, 700)

func _build_menu() -> void:
	menu_panel = _panel(root, "MenuPanel", Vector2(560, 452), true)
	_players_tab = _button(menu_panel, "Players", Rect2(16, 10, 120, 36), func() -> void: _select_page(false))
	_settings_tab = _button(menu_panel, "Settings", Rect2(144, 10, 128, 36), func() -> void: _select_page(true))
	for tab in [_players_tab, _settings_tab]:
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.add_theme_font_size_override("font_size", 13)
		tab.add_theme_constant_override("h_separation", 8)
	_small_icon(menu_panel, "close", Rect2(520, 12, 32, 32), _close_panels).tooltip_text = "Resume game"
	var separator := ColorRect.new()
	separator.color = UI.LINE
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(separator, menu_panel, Rect2(0, 56, 560, 1))
	_settings_page = Control.new()
	_settings_page.name = "SettingsPage"
	_place(_settings_page, menu_panel, Rect2(0, 57, 560, 323))
	_players_page = Control.new()
	_players_page.name = "PlayersPage"
	_place(_players_page, menu_panel, Rect2(0, 57, 560, 323))
	_build_settings()
	_build_players()
	var footer := _surface(menu_panel, Rect2(0, 380, 560, 72), 12)
	var footer_style := UI.style(UI.FIELD, 12, Color.TRANSPARENT)
	footer_style.corner_radius_top_left = 0
	footer_style.corner_radius_top_right = 0
	footer.add_theme_stylebox_override("panel", footer_style)
	_button(menu_panel, "Leave", Rect2(18, 398, 104, 36), func() -> void: _show_dialog("leave"))
	_button(menu_panel, "Respawn", Rect2(130, 398, 114, 36), func() -> void: _show_dialog("respawn"))
	_button(menu_panel, "Resume game", Rect2(364, 398, 178, 36), _close_panels, "primary")

func _build_settings() -> void:
	_text(_settings_page, "CONTROLS", Rect2(20, 20, 500, 16), 10, UI.MUTED, 700)
	_text(_settings_page, "Shift lock", Rect2(20, 52, 432, 20), 14, UI.INK, 600)
	_text(_settings_page, "Use Ctrl to keep the camera behind your character.", Rect2(20, 74, 432, 18), 12, UI.MUTED)
	var toggle := Widgets.Toggle.new()
	_place(toggle, _settings_page, Rect2(464, 64, 36, 20))
	toggle.button_pressed = SessionState.shift_lock_enabled
	toggle.tooltip_text = "Allow Ctrl shift lock"
	toggle.toggled.connect(SessionState.set_shift_lock_enabled)
	_text(_settings_page, "Game volume", Rect2(20, 112, 460, 20), 14, UI.INK, 600)
	_volume_label = _text(_settings_page, "%d%%" % int(SessionState.game_volume * 100), Rect2(490, 112, 50, 20), 13, UI.MUTED, 600)
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = SessionState.game_volume * 100
	_place(slider, _settings_page, Rect2(20, 142, 520, 20))
	slider.value_changed.connect(func(value: float) -> void:
		SessionState.set_volume(value / 100.0)
		_volume_label.text = "%d%%" % int(value)
	)
	slider.drag_ended.connect(func(_changed: bool) -> void: SessionState.save_preferences())
	_text(_settings_page, "Display name", Rect2(20, 192, 520, 20), 14, UI.INK, 600)
	_name_input = LineEdit.new()
	_name_input.text = SessionState.display_name
	_name_input.max_length = 24
	_place(_name_input, _settings_page, Rect2(20, 218, 520, 36))
	_name_input.text_submitted.connect(SessionState.set_display_name)
	_name_input.focus_exited.connect(func() -> void: SessionState.set_display_name(_name_input.text))
	_text(_settings_page, "Saved on this device. No account needed.", Rect2(20, 260, 520, 17), 11, UI.MUTED)

func _build_players() -> void:
	_text(_players_page, "IN THIS SESSION", Rect2(20, 20, 520, 16), 10, UI.MUTED, 700)
	_surface(_players_page, Rect2(20, 52, 520, 86), 10)
	_asset(_players_page, "avatar-roster", Rect2(34, 67, 40, 55))
	_roster_name = _text(_players_page, SessionState.display_name, Rect2(88, 74, 278, 21), 15, UI.INK, 600)
	_bounded(_roster_name)
	_text(_players_page, "You · Local player", Rect2(88, 97, 278, 17), 11, UI.MUTED)
	_button(_players_page, "View avatar", Rect2(386, 77, 140, 36), _show_avatar)
	var labels := ["Friend request", "Block", "Report"]
	for index in range(labels.size()):
		var b := _button(_players_page, labels[index], Rect2(20 + index * 176, 154, 168, 36), func() -> void: pass)
		b.disabled = true
		b.add_theme_color_override("font_disabled_color", UI.INK)
		b.modulate.a = 0.38
		b.tooltip_text = "Unavailable offline. You cannot use this on yourself."
	_text(_players_page, "Online actions are unavailable in this offline preview.\nOnly your local player is here.", Rect2(20, 206, 520, 40), 12, UI.MUTED)

func _select_page(settings: bool) -> void:
	_settings_page.visible = settings
	_players_page.visible = not settings
	for tab in [_settings_tab, _players_tab]:
		var active: bool = (tab == _settings_tab) == settings
		var base := UI.style(UI.ACCENT_SOFT if active else Color.TRANSPARENT, 8, Color.TRANSPARENT)
		base.content_margin_left = 12
		tab.add_theme_stylebox_override("normal", base)
		tab.add_theme_color_override("font_color", UI.INK if active else UI.MUTED)
	_settings_tab.icon = UI.texture("settings-active" if settings else "settings-muted")
	_players_tab.icon = UI.texture("players-muted" if settings else "players-active")

func _build_avatar_view() -> void:
	avatar_panel = _panel(root, "AvatarPanel", Vector2(360, 420), true)
	_text(avatar_panel, "Your avatar", Rect2(20, 18, 320, 26), 20, UI.INK, 700)
	_surface(avatar_panel, Rect2(20, 56, 320, 244), 10)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(container, avatar_panel, Rect2(20, 56, 320, 244))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 244)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(viewport)
	var preview_root := Node3D.new()
	viewport.add_child(preview_root)
	var environment := WorldEnvironment.new()
	var setup := Environment.new()
	setup.background_mode = Environment.BG_COLOR
	setup.background_color = UI.FIELD
	setup.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	setup.ambient_light_color = Color("e5e0ff")
	setup.ambient_light_energy = 0.85
	environment.environment = setup
	preview_root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.3
	preview_root.add_child(light)
	avatar_preview = AvatarScript.new()
	preview_root.add_child(avatar_preview)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.55, -6.4)
	camera.fov = 30
	preview_root.add_child(camera)
	camera.look_at(Vector3(0, 1.55, 0), Vector3.UP)
	camera.current = true
	_avatar_name = _text(avatar_panel, SessionState.display_name, Rect2(20, 312, 320, 20), 14, UI.INK, 600)
	_bounded(_avatar_name)
	_text(avatar_panel, "Original six-part rig", Rect2(20, 334, 320, 17), 11, UI.MUTED)
	_button(avatar_panel, "Back to players", Rect2(20, 366, 320, 36), _hide_avatar)

func _build_dialog() -> void:
	dialog_panel = _panel(root, "ConfirmationPanel", Vector2(416, 204), true)
	_dialog_title = _text(dialog_panel, "", Rect2(24, 20, 368, 26), 20, UI.INK, 700)
	_dialog_copy = _text(dialog_panel, "", Rect2(24, 60, 368, 42), 14, UI.MUTED)
	_button(dialog_panel, "Cancel", Rect2(110, 114, 124, 36), _cancel_dialog)
	_dialog_confirm = _button(dialog_panel, "", Rect2(242, 114, 150, 36), _confirm_dialog)

func _build_inventory() -> void:
	inventory_panel = _panel(root, "InventoryPanel", Vector2(560, 452), true)
	_text(inventory_panel, "Inventory", Rect2(20, 16, 480, 26), 20, UI.INK, 700)
	_small_icon(inventory_panel, "close", Rect2(520, 12, 32, 32), _close_panels)
	_text(inventory_panel, "YOUR ITEMS · SESSION ONLY", Rect2(20, 76, 420, 16), 10, UI.MUTED, 700)
	_item_count = _text(inventory_panel, "0 / 18", Rect2(470, 76, 70, 18), 12, UI.MUTED)
	_item_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for index in range(inventory.CAPACITY):
		var slot := Widgets.SlotButton.new()
		slot.name = "InventorySlot%d" % (index + 1)
		slot.slot_index = index
		slot.pressed.connect(_inspect_slot.bind(index))
		_place(slot, inventory_panel, Rect2(20 + (index % 6) * 88, 108 + (index / 6) * 72, 80, 64))
		_inventory_slots.append(slot)
	_item_title = _text(inventory_panel, "", Rect2(20, 332, 520, 20), 14, UI.INK, 600)
	_item_description = _text(inventory_panel, "", Rect2(20, 354, 520, 18), 12, UI.MUTED)
	_bounded(_item_description)
	_surface(inventory_panel, Rect2(0, 380, 560, 72), 12)
	_button(inventory_panel, "Close", Rect2(18, 398, 104, 36), _close_panels)
	_drop_button = _button(inventory_panel, "Drop", Rect2(130, 398, 104, 36), _drop_inspected)
	_equip_button = _button(inventory_panel, "Equip", Rect2(364, 398, 178, 36), _equip_inspected, "primary")

func _build_hotbar() -> void:
	_hotbar = HBoxContainer.new()
	_hotbar.name = "Hotbar"
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar.add_theme_constant_override("separation", 6)
	root.add_child(_hotbar)
	for index in range(inventory.HOTBAR_SIZE):
		var slot := Widgets.SlotButton.new()
		slot.name = "HotbarSlot%d" % (index + 1)
		slot.slot_index = index
		slot.hotbar = true
		slot.custom_minimum_size = Vector2(40, 44)
		slot.pressed.connect(_equip_hotbar.bind(index))
		_hotbar.add_child(slot)
		_hotbar_slots.append(slot)
	_equipped_caption = UI.label("", 12, UI.INK, 600)
	_equipped_caption.add_theme_color_override("font_outline_color", UI.SHELL)
	_equipped_caption.add_theme_constant_override("outline_size", 4)
	root.add_child(_equipped_caption)

func _build_context_feedback() -> void:
	crosshair = UI.label("·", 32)
	root.add_child(crosshair)
	_pickup_prompt = PanelContainer.new()
	_pickup_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := UI.style(UI.SHELL, 7, UI.EDGE)
	bg.set_content_margin_all(8)
	_pickup_prompt.add_theme_stylebox_override("panel", bg)
	_pickup_label = UI.label("", 12, UI.INK, 600)
	_pickup_prompt.add_child(_pickup_label)
	root.add_child(_pickup_prompt)
	_status_label = UI.label("", 12, UI.INK, 600)
	_status_label.add_theme_color_override("font_outline_color", UI.SHELL)
	_status_label.add_theme_constant_override("outline_size", 4)
	root.add_child(_status_label)

func _layout() -> void:
	if not is_instance_valid(_leaderboard_button): return
	var screen := root.get_viewport_rect().size
	# Only position changes on window resize. Dimensions/fonts never scale with it.
	for panel in [menu_panel, avatar_panel, inventory_panel, dialog_panel]:
		panel.position = (screen - panel.size) * 0.5
	chat_panel.position = Vector2(16, 64)
	leaderboard_panel.position = Vector2(screen.x - 256, 64)
	_leaderboard_button.position = Vector2(screen.x - 52, 16)
	_inventory_button.position = Vector2(screen.x - 94, 16)
	_hotbar.position = Vector2((screen.x - 408) * 0.5, screen.y - 60)
	_equipped_caption.position = Vector2((screen.x - _equipped_caption.get_combined_minimum_size().x) * 0.5, screen.y - 84)
	crosshair.position = screen * 0.5 - crosshair.get_combined_minimum_size() * 0.5
	_pickup_prompt.position = Vector2((screen.x - _pickup_prompt.get_combined_minimum_size().x) * 0.5, screen.y * 0.5 + 44)
	_status_label.position = Vector2((screen.x - _status_label.get_combined_minimum_size().x) * 0.5, screen.y - 110)

func _process(delta: float) -> void:
	_status_remaining = maxf(0.0, _status_remaining - delta)
	_status_label.visible = _status_remaining > 0 and not player.input_blocked
	_hotbar.visible = inventory.occupied_count() > 0 and not _modal_visible()
	_equipped_caption.visible = not inventory.equipped_id().is_empty() and not _modal_visible()
	var title: String = world.pickup_title()
	_pickup_label.text = "[E] Pick up · " + title
	_pickup_prompt.visible = not player.input_blocked and not title.is_empty()
	crosshair.visible = (player.shift_locked or player.first_person) and not player.input_blocked
	_layout_context()

func _layout_context() -> void:
	var screen := root.get_viewport_rect().size
	_pickup_prompt.position.x = (screen.x - _pickup_prompt.get_combined_minimum_size().x) * 0.5
	_status_label.position.x = (screen.x - _status_label.get_combined_minimum_size().x) * 0.5

func _modal_visible() -> bool:
	return menu_panel.visible or avatar_panel.visible or inventory_panel.visible or dialog_panel.visible

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if dialog_panel.visible: _cancel_dialog()
		elif avatar_panel.visible: _hide_avatar()
		elif menu_panel.visible or inventory_panel.visible: _close_panels()
		elif chat_input.has_focus(): chat_input.release_focus(); _update_controls()
		else: _toggle_menu()
		get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.physical_keycode == KEY_I and not dialog_panel.visible:
		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if _modal_visible(): return
	if event.keycode == KEY_ENTER or event.keycode == KEY_SLASH:
		chat_panel.show()
		chat_input.grab_focus()
		_update_controls()
	elif event.keycode == KEY_TAB: _toggle_leaderboard()
	elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		_equip_hotbar(event.physical_keycode - KEY_1)
	else: return
	get_viewport().set_input_as_handled()

func _release_focus() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus): focus.release_focus()

func _close_panels() -> void:
	_release_focus()
	SessionState.set_display_name(_name_input.text)
	for panel in [menu_panel, avatar_panel, inventory_panel, dialog_panel]: panel.hide()
	menu_dimmer.hide()
	_update_controls()

func _toggle_menu() -> void:
	if menu_panel.visible or avatar_panel.visible or dialog_panel.visible:
		_close_panels()
	else:
		_close_panels()
		_name_input.text = SessionState.display_name
		menu_panel.show()
		_update_controls()

func _toggle_chat() -> void:
	var opening := not chat_panel.visible
	_close_panels()
	chat_panel.visible = opening
	if opening: chat_input.grab_focus()
	_update_controls()

func _toggle_leaderboard() -> void:
	_close_panels()
	leaderboard_panel.visible = not leaderboard_panel.visible
	_release_focus()
	_update_controls()

func _toggle_inventory() -> void:
	var opening := not inventory_panel.visible
	_close_panels()
	inventory_panel.visible = opening
	_refresh_inventory()
	_update_controls()

func _send_chat(text: String) -> void:
	var message := text.strip_edges().replace("\n", " ").replace("\r", " ").substr(0, 240)
	if not message.is_empty():
		_messages.append(SessionState.display_name + " : " + message)
		if _messages.size() > 100: _messages.pop_front()
		chat_log.text = "\n".join(PackedStringArray(_messages))
	chat_input.clear()
	_release_focus()
	_update_controls()

func _show_avatar() -> void:
	_release_focus()
	menu_panel.hide()
	avatar_panel.show()
	_update_controls()

func _hide_avatar() -> void:
	_release_focus()
	avatar_panel.hide()
	menu_panel.show()
	_select_page(false)
	_update_controls()

func _show_dialog(action: String) -> void:
	_release_focus()
	menu_panel.hide()
	_dialog_action = action
	_dialog_title.text = "Leave this game?" if action == "leave" else "Start fresh?"
	_dialog_copy.text = "Your settings are saved. Local chat and items\nclear when you leave." if action == "leave" else "Your character returns to the center\nof the baseplate. Items stay in your bag."
	_dialog_confirm.text = "Leave game" if action == "leave" else "Respawn"
	var fill := UI.DANGER if action == "leave" else UI.ACCENT
	for state: String in ["normal", "hover", "pressed"]:
		_dialog_confirm.add_theme_stylebox_override(state, UI.style(fill.lightened(0.06) if state == "hover" else fill))
		_dialog_confirm.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), UI.DARK)
	dialog_panel.show()
	_update_controls()

func _cancel_dialog() -> void:
	_release_focus()
	dialog_panel.hide()
	menu_panel.show()
	_update_controls()

func _confirm_dialog() -> void:
	if _dialog_action == "leave":
		SessionState.save_preferences()
		get_tree().quit()
	else:
		player.respawn()
		_close_panels()

func _preferences_updated() -> void:
	_roster_name.text = SessionState.display_name
	_leaderboard_name.text = SessionState.display_name
	_avatar_name.text = SessionState.display_name

func _inspect_slot(index: int) -> void:
	_inspected_slot = index
	_refresh_inventory()

func _equip_inspected() -> void:
	if _inspected_slot >= 0: inventory.equip(_inspected_slot)

func _drop_inspected() -> void:
	if _inspected_slot >= 0: world.drop_slot(_inspected_slot)

func _equip_hotbar(index: int) -> void:
	inventory.equip(index)
	_release_focus()
	_update_controls()

func _refresh_inventory() -> void:
	if not is_instance_valid(_item_title): return
	for index in range(_inventory_slots.size()):
		var slot = _inventory_slots[index]
		slot.item_id = str(inventory.get_slot(index).get("id", ""))
		slot.equipped = inventory.equipped_slot == index
		slot.inspected = _inspected_slot == index
		slot.tooltip_text = Catalog.title(slot.item_id)
		slot.queue_redraw()
	for index in range(_hotbar_slots.size()):
		var slot = _hotbar_slots[index]
		slot.item_id = str(inventory.get_slot(index).get("id", ""))
		slot.equipped = inventory.equipped_slot == index
		slot.tooltip_text = Catalog.title(slot.item_id) + " · " + str(index + 1) + " to equip / put away"
		slot.queue_redraw()
	_item_count.text = "%d / %d" % [inventory.occupied_count(), inventory.CAPACITY]
	var id: String = str(inventory.get_slot(_inspected_slot).get("id", ""))
	_item_title.text = Catalog.title(id) if not id.is_empty() else "Pick up tools around the baseplate"
	_item_description.text = str(Catalog.item(id).get("description", "Approach a tool and press E. Your first nine slots appear on the hotbar."))
	_item_description.tooltip_text = _item_description.text
	_drop_button.disabled = id.is_empty()
	_equip_button.disabled = id.is_empty()
	_equip_button.text = "Put away" if inventory.equipped_slot == _inspected_slot and not id.is_empty() else "Equip"
	var active: String = inventory.equipped_id()
	_equipped_caption.text = Catalog.title(active) + " · " + str(Catalog.item(active).get("use", "")) if not active.is_empty() else ""
	_layout()

func _show_status(message: String) -> void:
	_status_label.text = message
	_status_remaining = 2.2

func _update_controls() -> void:
	if not is_instance_valid(_menu_button): return
	var modal := _modal_visible()
	menu_dimmer.visible = modal
	player.input_blocked = modal or chat_input.has_focus()
	player.update_mouse_mode()
	_menu_button.set_pressed_no_signal(menu_panel.visible or avatar_panel.visible or dialog_panel.visible)
	_chat_button.set_pressed_no_signal(chat_panel.visible)
	_leaderboard_button.set_pressed_no_signal(leaderboard_panel.visible)
	_inventory_button.set_pressed_no_signal(inventory_panel.visible)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SessionState.save_preferences()
