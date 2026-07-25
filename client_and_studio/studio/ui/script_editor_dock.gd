# client_and_studio/studio/ui/script_editor_dock.gd
extends Control

signal script_saved(target_node: Node3D, script_code: String)

@onready var code_edit: TextEdit = %CodeEdit
@onready var output_box: RichTextLabel = %OutputBox
@onready var target_label: Label = %TargetLabel
@onready var run_button: Button = %RunButton
@onready var clear_output_button: Button = %ClearOutputButton

var current_node: Node3D = null

func _ready() -> void:
	run_button.pressed.connect(_on_run_pressed)
	clear_output_button.pressed.connect(_on_clear_output_pressed)
	code_edit.text_changed.connect(_on_text_changed)

	var luau_mgr := get_node_or_null("/root/LuauManager")
	if luau_mgr:
		luau_mgr.output_logged.connect(_on_luau_output_logged)

func attach_to_node(node: Node3D) -> void:
	current_node = node
	if current_node:
		target_label.text = "Script Attached to: " + current_node.name
		var existing_script: String = current_node.get_meta("luau_script", "-- Write Luau code for " + current_node.name + "\nprint('Hello from " + current_node.name + "!')")
		code_edit.text = existing_script
	else:
		target_label.text = "Script Attached to: Global Place"
		code_edit.text = "-- Global Place Luau Script\nprint('Luani Place Loaded')"

func get_current_script() -> String:
	return code_edit.text

func _on_text_changed() -> void:
	if current_node:
		current_node.set_meta("luau_script", code_edit.text)
		script_saved.emit(current_node, code_edit.text)

func _on_run_pressed() -> void:
	var code := code_edit.text
	var luau_mgr := get_node_or_null("/root/LuauManager")
	if luau_mgr:
		luau_mgr.execute_luau_script(code, current_node)

func _on_luau_output_logged(msg: String, is_error: bool) -> void:
	if output_box:
		if is_error:
			output_box.append_text("[color=red]" + msg + "[/color]\n")
		else:
			output_box.append_text("[color=lightgreen]" + msg + "[/color]\n")

func _on_clear_output_pressed() -> void:
	if output_box:
		output_box.clear()
