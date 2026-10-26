extends RefCounted
## Android gets readable/touchable logical units; desktop retains its exact pixel geometry.
static func configure(window: Window) -> void:
	if not OS.has_feature("android"): return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(854, 480)
