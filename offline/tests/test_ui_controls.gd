extends SceneTree
## Desktop-only Godot regression. Not executed by Hermes.
const Widgets = preload("res://scripts/ui_controls.gd")
const Hud = preload("res://scripts/hud.gd")
const World = preload("res://scripts/world.gd")

func _init() -> void:
	# Loading the real dependency chain must compile before any gameplay checks.
	assert(Hud != null and World != null)
	var button := Widgets.HudButton.new()
	button.title = "Menu"
	button.shortcut_hint = "Esc"
	assert(button.shortcut_hint == "Esc")
	assert(button.shortcut == null, "Tooltip text must not overwrite BaseButton.shortcut")
	var native_shortcut := Shortcut.new()
	button.shortcut = native_shortcut
	assert(button.shortcut == native_shortcut)
	var tooltip := button._make_custom_tooltip("Menu") as Control
	assert(tooltip != null)
	var caption := tooltip.get_child(0).get_child(0) as Label
	var keycap := tooltip.get_child(0).get_child(1).get_child(0) as Label
	assert(caption != null and caption.text == "Menu")
	assert(keycap != null and keycap.text == "Esc")
	tooltip.free()
	button.free()
	print("UI script loading, tooltip text and native Shortcut contract passed.")
	quit(0)
