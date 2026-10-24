extends RefCounted
## Shared Figma tokens. Raw font/SVG decoding avoids a Godot editor import pass.
const INK := Color("f5f4fa")
const MUTED := Color("adb1c0")
const ACCENT := Color("c1adff")
const ACCENT_SOFT := Color("3b324e")
const PANEL := Color("202229")
const FIELD := Color("2b2e38")
const LINE := Color("3a3e49")
const DARK := Color("201a2d")
const DANGER := Color("eea7ad")
const SHELL := Color("14171f")
const EDGE := Color("697185")
static var _font_file: FontFile
static var _fonts: Dictionary = {}
static var _textures: Dictionary = {}

static func font(weight: int = 400) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	if _font_file == null:
		_font_file = FontFile.new()
		_font_file.data = FileAccess.get_file_as_bytes("res://assets/fonts/NunitoSans.ttf")
	var face := FontVariation.new()
	face.base_font = _font_file
	face.variation_opentype = {"wght": float(weight), "wdth": 100.0, "YTLC": 500.0}
	_fonts[weight] = face
	return face

static func texture(name: String, figma: bool = true) -> Texture2D:
	var path := "res://assets/ui/" + ("figma/" if figma else "items/") + name + ".svg"
	if _textures.has(path):
		return _textures[path]
	var image := Image.new()
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty() or image.load_svg_from_string(source) != OK:
		push_warning("Could not decode local Luani SVG: " + path)
		return null
	var result := ImageTexture.create_from_image(image)
	_textures[path] = result
	return result

static func style(fill: Color, radius: int = 8, edge: Color = LINE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(0)
	return s

static func overlay_style() -> StyleBoxFlat:
	var s := style(PANEL, 12)
	s.shadow_color = Color(0, 0, 0, 0.28)
	s.shadow_size = 40
	s.shadow_offset = Vector2(0, 16)
	return s

static func label(text: String, pixels: int = 14, color: Color = INK, weight: int = 400) -> Label:
	var n := Label.new()
	n.text = text
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_font_override("font", font(weight))
	n.add_theme_font_size_override("font_size", pixels)
	n.add_theme_color_override("font_color", color)
	return n

static func circle_texture() -> Texture2D:
	var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(12):
		for x in range(12):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(6, 6)) <= 6.0:
				image.set_pixel(x, y, INK)
	return ImageTexture.create_from_image(image)

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 14
	for kind: String in ["Label", "Button", "LineEdit", "RichTextLabel"]:
		t.set_color("font_color", kind, INK)
		t.set_color("font_hover_color", kind, INK)
		t.set_color("font_focus_color", kind, INK)
	t.set_font("font", "Button", font(600))
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.38))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var fill := FIELD
		if state == "hover": fill = Color("3b414f")
		if state == "pressed": fill = Color("1b1f29")
		t.set_stylebox(state, "Button", style(fill))
	var focus := style(Color.TRANSPARENT, 8, ACCENT)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(2)
	t.set_stylebox("focus", "Button", focus)
	for state: String in ["normal", "read_only"]:
		var input := style(FIELD, 8, Color.TRANSPARENT)
		input.content_margin_left = 12
		input.content_margin_right = 12
		t.set_stylebox(state, "LineEdit", input)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", ACCENT_SOFT)
	t.set_font("normal_font", "RichTextLabel", font())
	t.set_font("bold_font", "RichTextLabel", font(600))
	t.set_font_size("normal_font_size", "RichTextLabel", 14)
	var rail := style(FIELD, 2, Color.TRANSPARENT)
	rail.set_content_margin_all(0)
	rail.content_margin_top = 2
	rail.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", rail)
	var active := rail.duplicate() as StyleBoxFlat
	active.bg_color = ACCENT
	t.set_stylebox("grabber_area", "HSlider", active)
	t.set_stylebox("grabber_area_highlight", "HSlider", active)
	var knob := circle_texture()
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	return t

static func tooltip(title: String, shortcut: String = "") -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 28
	var bg := style(SHELL, 7, EDGE)
	bg.content_margin_left = 10
	bg.content_margin_right = 6
	bg.content_margin_top = 5
	bg.content_margin_bottom = 5
	bg.shadow_color = Color(0, 0, 0, 0.22)
	bg.shadow_size = 5
	bg.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	row.add_child(label(title, 12, INK, 600))
	if not shortcut.is_empty():
		var cap := PanelContainer.new()
		cap.custom_minimum_size.y = 18
		var cap_style := style(FIELD, 4)
		cap_style.content_margin_left = 4
		cap_style.content_margin_right = 4
		cap.add_theme_stylebox_override("panel", cap_style)
		cap.add_child(label(shortcut, 10, MUTED, 600))
		row.add_child(cap)
	return panel
