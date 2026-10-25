extends RefCounted
## Reusable native Godot controls, painted from the approved Figma geometry.
const UI = preload("res://scripts/ui_theme.gd")

class HudButton extends Button:
	var glyph: Texture2D
	var title: String = ""
	var shortcut_hint: String = ""
	var _held := false
	var _color := UI.FIELD
	var _face: StyleBoxFlat
	var _shell: StyleBoxFlat
	var _focus_outer: StyleBoxFlat
	var _focus_inner: StyleBoxFlat
	var _led: StyleBoxFlat

	func _get_minimum_size() -> Vector2:
		return Vector2(36, 32)

	func _ready() -> void:
		toggle_mode = true
		custom_minimum_size = Vector2(36, 32)
		size = Vector2(36, 32)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_ALL
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_shell = UI.style(UI.SHELL, 10, Color.TRANSPARENT)
		_shell.shadow_color = Color(0, 0, 0, 0.22)
		_shell.shadow_size = 5
		_shell.shadow_offset = Vector2(0, 2)
		_face = UI.style(UI.FIELD, 9, UI.EDGE)
		_focus_outer = UI.style(Color.TRANSPARENT, 13, UI.SHELL)
		_focus_outer.set_border_width_all(3)
		_focus_inner = UI.style(Color.TRANSPARENT, 12, UI.ACCENT)
		_focus_inner.set_border_width_all(2)
		_led = UI.style(UI.ACCENT, 1, Color.TRANSPARENT)
		button_down.connect(func() -> void: _held = true; queue_redraw())
		button_up.connect(func() -> void: _held = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _process(delta: float) -> void:
		var target := UI.FIELD
		if _held:
			target = Color("1b1f29")
		elif button_pressed:
			target = Color("504265") if is_hovered() else UI.ACCENT_SOFT
		elif is_hovered():
			target = Color("3b414f")
		_color = _color.lerp(target, minf(delta / 0.12, 1.0))
		self_modulate.a = 0.36 if disabled else 1.0
		queue_redraw()

	func _draw() -> void:
		if _face == null:
			return
		draw_style_box(_shell, Rect2(0, 0, 36, 32))
		_face.bg_color = _color
		_face.border_color = UI.ACCENT if button_pressed and not _held else UI.EDGE
		var y := 1.0 if _held else 0.0
		draw_style_box(_face, Rect2(0, y, 36, 30))
		draw_line(Vector2(6, y + 1), Vector2(30, y + 1), Color(UI.INK, 0.025 if _held else 0.055), 1.0)
		if glyph != null:
			draw_texture_rect(glyph, Rect2(8, y + 5, 20, 20), false)
		if button_pressed and not _held:
			draw_style_box(_led, Rect2(13, 27, 10, 2))
		if has_focus():
			draw_style_box(_focus_outer, Rect2(-3, -3, 42, 38))
			draw_style_box(_focus_inner, Rect2(-2, -2, 40, 36))

	func _make_custom_tooltip(_for_text: String) -> Object:
		return UI.tooltip(title, shortcut_hint)

class Toggle extends Button:
	func _get_minimum_size() -> Vector2:
		return Vector2(36, 20)

	func _ready() -> void:
		toggle_mode = true
		custom_minimum_size = Vector2(36, 20)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		toggled.connect(func(_value: bool) -> void: queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		if button_pressed:
			var on := UI.texture("toggle-on")
			if on != null: draw_texture_rect(on, Rect2(0, 0, 36, 20), false)
		else:
			draw_style_box(UI.style(UI.LINE, 10, Color.TRANSPARENT), Rect2(0, 0, 36, 20))
			draw_circle(Vector2(10, 10), 7, UI.MUTED)
		if has_focus():
			draw_style_box(UI.style(Color.TRANSPARENT, 12, UI.ACCENT), Rect2(-2, -2, 40, 24))

class SlotButton extends Button:
	var slot_index: int = 0
	var item_id: String = ""
	var equipped: bool = false
	var inspected: bool = false
	var hotbar: bool = false

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var edge := UI.ACCENT if equipped or inspected else UI.LINE
		var background := UI.ACCENT_SOFT if equipped else UI.FIELD
		if is_hovered(): background = background.lightened(0.10)
		draw_style_box(UI.style(background, 8, edge), Rect2(Vector2.ZERO, size))
		var icon_size := 24.0 if hotbar else 28.0
		if not item_id.is_empty():
			var tex := UI.texture(item_id, false)
			if tex != null:
				draw_texture_rect(tex, Rect2((size.x - icon_size) * 0.5, 7, icon_size, icon_size), false)
		if hotbar:
			draw_string(UI.font(600), Vector2(4, 12), str(slot_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.MUTED)
		else:
			var name_text: String = "Empty" if item_id.is_empty() else str({"sword":"Sword", "lantern":"Lantern", "spring_coil":"Coil"}.get(item_id, "Item"))
			draw_string(UI.font(600), Vector2(6, size.y - 9), str(name_text), HORIZONTAL_ALIGNMENT_CENTER, size.x - 12, 11, UI.MUTED if item_id.is_empty() else UI.INK)
		if equipped:
			draw_style_box(UI.style(UI.ACCENT, 1, Color.TRANSPARENT), Rect2(size.x * 0.5 - 5, size.y - 4, 10, 2))
