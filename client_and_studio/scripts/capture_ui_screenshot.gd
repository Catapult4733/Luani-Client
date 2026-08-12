# client_and_studio/scripts/capture_ui_screenshot.gd
extends SceneTree

func _init() -> void:
	print("[Capture Test] Instantiating PauseMenu...")
	var scene := preload("res://scenes/ui/pause_menu.tscn")
	var inst = scene.instantiate()
	root.add_child(inst)
	
	if inst.has_method("toggle_menu"):
		inst.toggle_menu()
		
	await create_timer(0.4).timeout
	var img := root.get_texture().get_image()
	img.save_png("/home/username/.gemini/antigravity-ide/brain/581943f4-ab24-4ffb-8920-a1a63beb84fc/pause_menu_render.png")
	print("[Capture Test] Saved screenshot successfully to pause_menu_render.png!")
	quit()
