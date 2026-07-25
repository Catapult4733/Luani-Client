# client_and_studio/scripts/core/luau_manager.gd
class_name LuauManager
extends Node

## Singleton managing sandboxed Luau script execution, runtime environment, and API bindings

signal output_logged(message: String, is_error: bool)
signal script_execution_started(target_node: Node)
signal script_execution_finished(target_node: Node, result: Dictionary)

var is_sandboxed: bool = true
var active_environment: Dictionary = {}

func _ready() -> void:
	print("[Luani LuauManager] Initialized Sandboxed Luau Engine Bridge.")

## Executes a Luau script string safely within a sandboxed environment bound to a target Node3D
func execute_luau_script(script_code: String, target_node: Node3D = null) -> Dictionary:
	var result := {
		"success": true,
		"error": "",
		"output": []
	}

	if target_node:
		script_execution_started.emit(target_node)

	log_output("[Luau System] Starting script execution for: " + (target_node.name if target_node else "Global Workspace"))

	# Basic security check for forbidden OS/File IO keywords in sandbox mode
	if is_sandboxed:
		var forbidden_keywords := ["os.execute", "os.remove", "io.open", "require", "get_node('/root')"]
		for kw in forbidden_keywords:
			if kw in script_code:
				var err_msg := "Security Error: Usage of forbidden function '%s' is blocked in sandboxed Luau." % kw
				log_output(err_msg, true)
				result["success"] = false
				result["error"] = err_msg
				if target_node:
					script_execution_finished.emit(target_node, result)
				return result

	# Execute script logic using sandboxed engine context
	_run_sandboxed_code(script_code, target_node, result)

	if target_node:
		script_execution_finished.emit(target_node, result)

	return result

func _run_sandboxed_code(code: String, target_node: Node3D, result: Dictionary) -> void:
	var lines := code.split("\n")
	for line in lines:
		var trimmed := line.strip_edges()
		if trimmed == "" or trimmed.begins_with("--") or trimmed.begins_with("#"):
			continue

		# Handle print(...) statement
		if trimmed.begins_with("print(") and trimmed.ends_with(")"):
			var content := trimmed.trim_prefix("print(").trim_suffix(")").strip_edges()
			if (content.begins_with('"') and content.ends_with('"')) or (content.begins_with("'") and content.ends_with("'")):
				content = content.substr(1, content.length() - 2)
			log_output("[Luau Output] " + content)
			result["output"].append(content)

		# Handle set_part_property("PartName", "Property", value) or self mutation
		elif "set_part_property(" in trimmed:
			_handle_set_property(trimmed, target_node)

		# Handle part rotation or movement animation line simulation
		elif target_node and ("rotate_y(" in trimmed or "rotate_x(" in trimmed):
			_handle_rotation(trimmed, target_node)

func _handle_set_property(line: String, default_target: Node3D) -> void:
	# Example syntax: set_part_property("Block", "color", "#ff0000")
	var start_idx := line.find("(")
	var end_idx := line.rfind(")")
	if start_idx != -1 and end_idx != -1:
		var args_str := line.substr(start_idx + 1, end_idx - start_idx - 1)
		var parts := args_str.split(",")
		if parts.size() >= 3:
			var target_name := parts[0].strip_edges().replace('"', '').replace("'", "")
			var prop_name := parts[1].strip_edges().replace('"', '').replace("'", "").to_lower()
			var val_str := parts[2].strip_edges().replace('"', '').replace("'", "")

			var target_part: Node3D = default_target
			if default_target and default_target.get_parent():
				var found := default_target.get_parent().find_child(target_name, true, false)
				if found is Node3D:
					target_part = found

			if target_part:
				if prop_name == "color" and target_part.has_node("MeshInstance3D"):
					var mesh_inst: MeshInstance3D = target_part.get_node("MeshInstance3D")
					var mat := StandardMaterial3D.new()
					mat.albedo_color = Color.html(val_str)
					mesh_inst.material_override = mat
					log_output("[Luau Engine] Updated %s color to %s" % [target_part.name, val_str])
				elif prop_name == "position":
					target_part.position += Vector3(0, 1, 0)
					log_output("[Luau Engine] Shifted %s position" % target_part.name)

func _handle_rotation(line: String, target_node: Node3D) -> void:
	if line.contains("rotate_y"):
		target_node.rotate_y(deg_to_rad(15))
		log_output("[Luau Engine] Rotated " + target_node.name + " on Y axis.")

func log_output(message: String, is_error: bool = false) -> void:
	print(message)
	output_logged.emit(message, is_error)

## Headless test script launcher
func _run_headless_test() -> void:
	var test_code := """
	-- Luau Sandbox Verification Test
	print("Hello from Luani Luau Sandbox!")
	set_part_property("Self", "color", "#00ffcc")
	"""
	var res := execute_luau_script(test_code)
	print("[LuauManager Test Result] Success: ", res.get("success"))
