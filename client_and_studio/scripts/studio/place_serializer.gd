# client_and_studio/scripts/studio/place_serializer.gd
class_name PlaceSerializer
extends Node

## Handles workspace scene serialization into .luani JSON format and 1-click publishing to luani.fyi backend

signal publish_completed(success: bool, response_msg: String)

## Serializes 3D workspace node tree and attached Luau scripts into a Dictionary
static func serialize_workspace(workspace_node: Node3D, place_name: String = "Luani Level") -> Dictionary:
	var place_dict := {
		"format_version": 1,
		"name": place_name,
		"created_at": Time.get_datetime_string_from_system(),
		"parts": []
	}

	for child in workspace_node.get_children():
		if child is RigidBody3D and not child.name.begins_with("Gizmo"):
			var part_data := {
				"name": child.name,
				"primitive_type": child.get_meta("primitive_type", 0),
				"position": [child.position.x, child.position.y, child.position.z],
				"rotation": [child.rotation_degrees.x, child.rotation_degrees.y, child.rotation_degrees.z],
				"scale": [child.scale.x, child.scale.y, child.scale.z],
				"anchored": child.get_meta("anchored", true),
				"luau_script": child.get_meta("luau_script", "")
			}

			if child.has_node("MeshInstance3D"):
				var mesh_inst: MeshInstance3D = child.get_node("MeshInstance3D")
				if mesh_inst.material_override is StandardMaterial3D:
					var col: Color = (mesh_inst.material_override as StandardMaterial3D).albedo_color
					part_data["color"] = [col.r, col.g, col.b, col.a]

			place_dict["parts"].append(part_data)

	return place_dict

## Deserializes a .luani JSON Dictionary and reconstructs the 3D workspace scene
static func deserialize_workspace(place_dict: Dictionary, workspace_node: Node3D) -> void:
	# Clear existing parts
	for child in workspace_node.get_children():
		if child is RigidBody3D and not child.name.begins_with("Gizmo"):
			child.queue_free()

	var parts_array: Array = place_dict.get("parts", [])
	for part_data in parts_array:
		var prim_type: int = part_data.get("primitive_type", 0)
		var pos_arr: Array = part_data.get("position", [0, 0, 0])
		var rot_arr: Array = part_data.get("rotation", [0, 0, 0])
		var scale_arr: Array = part_data.get("scale", [1, 1, 1])

		var pos := Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		var part := PrimitiveFactory.spawn_primitive(prim_type as PrimitiveFactory.PrimitiveType, workspace_node, pos)

		part.name = part_data.get("name", part.name)
		part.rotation_degrees = Vector3(rot_arr[0], rot_arr[1], rot_arr[2])
		part.scale = Vector3(scale_arr[0], scale_arr[1], scale_arr[2])
		part.freeze = part_data.get("anchored", true)

		part.set_meta("luau_script", part_data.get("luau_script", ""))
		part.set_meta("anchored", part.freeze)

		if part_data.has("color") and part.has_node("MeshInstance3D"):
			var col_arr: Array = part_data["color"]
			var col := Color(col_arr[0], col_arr[1], col_arr[2], col_arr[3] if col_arr.size() > 3 else 1.0)
			var mesh_inst: MeshInstance3D = part.get_node("MeshInstance3D")
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col
			mesh_inst.material_override = mat

## Publishes place data dictionary to Luani backend API (luani.fyi)
func publish_place_to_backend(place_dict: Dictionary, api_url: String = "https://www.luani.fyi/api/places/publish", http_request: HTTPRequest = null) -> void:
	var json_str := JSON.stringify(place_dict)
	print("[Luani PlaceSerializer] Publishing place file to: ", api_url)
	
	if not http_request:
		http_request = HTTPRequest.new()
		add_child(http_request)

	var headers := ["Content-Type: application/json"]
	var error := http_request.request(api_url, headers, HTTPClient.METHOD_POST, json_str)
	if error != OK:
		push_error("[Luani PlaceSerializer] Failed to send HTTP request: " + str(error))
		publish_completed.emit(false, "HTTP Connection Error: " + str(error))

func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_text := body.get_string_from_utf8()
	print("[Luani PlaceSerializer] Server response (", response_code, "): ", response_text)
	
	if response_code == 200 or response_code == 201:
		publish_completed.emit(true, response_text)
	else:
		publish_completed.emit(false, "Server Error (" + str(response_code) + "): " + response_text)
