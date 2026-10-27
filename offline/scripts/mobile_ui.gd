extends RefCounted
## Android gets readable/touchable logical units; desktop retains its exact pixel geometry.
const PerformancePolicy = preload("res://scripts/mobile_performance.gd")
static func configure(window: Window) -> void:
	if not OS.has_feature("android"): return
	PerformancePolicy.configure(window)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(854, 480)
