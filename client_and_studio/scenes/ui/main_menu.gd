# client_and_studio/scenes/ui/main_menu.gd
extends CanvasLayer

## Minimal Main Menu Controller. Active UI rendered via Native Android WebView Overlay (https://luani.fyi)

func _ready() -> void:
	DisplayServer.screen_set_orientation(6)
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		hide()
		return
	show()
