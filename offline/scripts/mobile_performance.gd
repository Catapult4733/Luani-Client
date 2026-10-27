extends RefCounted
## Android-only pacing/power policy. A configured target is not a measured FPS guarantee.
static func settings_for(website_visible: bool) -> Dictionary:
	return {"fps":15,"low_processor":true} if website_visible else {"fps":60,"low_processor":false}

static func configure(window: Window) -> void:
	if not OS.has_feature("android"): return
	set_website_visible(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED,window.get_window_id())

static func set_website_visible(value: bool) -> void:
	if not OS.has_feature("android"): return
	var settings := settings_for(value)
	Engine.max_fps=int(settings.fps)
	OS.low_processor_usage_mode=bool(settings.low_processor)
	if value: OS.low_processor_usage_mode_sleep_usec=20000
