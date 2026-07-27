# client_and_studio/scripts/core/place_loader.gd
extends Node

## Loads and instantiates .luani place JSON files from API endpoints or local storage

signal place_loading_started(place_id: String)
signal place_loaded(place_id: String, world_root: Node3D)
signal place_load_failed(place_id: String, error_msg: String)

@export var backend_api_url: String = "https://www.luani.fyi/api/places"

## Loads a place by ID into target_world_root (downloads from backend or falls back to starter place)
func load_place(place_id: String, target_world_root: Node3D) -> void:
	place_loading_started.emit(place_id)
	print("[Luani PlaceLoader] Requesting place ID: ", place_id)

	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		_on_place_download_completed(result, response_code, body, place_id, target_world_root)
		http.queue_free()
	)

	var url := "%s/%s" % [backend_api_url, place_id]
	var err := http.request(url)
	if err != OK:
		print("[Luani PlaceLoader] API connection failed. Using fallback default place for ID: ", place_id)
		_instantiate_default_starter_world(place_id, target_world_root)

func _on_place_download_completed(result: int, response_code: int, body: PackedByteArray, place_id: String, target_world_root: Node3D) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 201):
		var json_str := body.get_string_from_utf8()
		var json_result = JSON.parse_string(json_str)
		if json_result is Dictionary:
			print("[Luani PlaceLoader] Successfully downloaded place JSON from backend.")
			_populate_world_from_dict(json_result, target_world_root)
			place_loaded.emit(place_id, target_world_root)
			return

	print("[Luani PlaceLoader] Place API fetch returned code ", response_code, ". Loading local fallback world.")
	_instantiate_default_starter_world(place_id, target_world_root)

func _populate_world_from_dict(data: Dictionary, target_world_root: Node3D) -> void:
	var place_payload: Dictionary = data.get("place", data)
	PlaceSerializer.deserialize_workspace(place_payload, target_world_root)
	
	# Execute attached Luau scripts on server boot
	var luau_mgr := get_node_or_null("/root/LuauManager")
	if luau_mgr:
		for child in target_world_root.get_children():
			if child.has_meta("luau_script"):
				var code: String = child.get_meta("luau_script")
				if code != "":
					luau_mgr.execute_luau_script(code, child)

func _instantiate_default_starter_world(place_id: String, target_world_root: Node3D) -> void:
	# Clear existing children
	for child in target_world_root.get_children():
		child.queue_free()

	# Spawn Baseplate
	var baseplate := PrimitiveFactory.spawn_primitive(PrimitiveFactory.PrimitiveType.BLOCK, target_world_root, Vector3(0, -0.5, 0))
	baseplate.name = "Baseplate"
	baseplate.scale = Vector3(30, 0.5, 30)

	# Spawn SpawnLocation Marker
	var spawn_pad := PrimitiveFactory.spawn_primitive(PrimitiveFactory.PrimitiveType.CYLINDER, target_world_root, Vector3(0, 0.1, 0))
	spawn_pad.name = "SpawnLocation"
	spawn_pad.scale = Vector3(2, 0.1, 2)
	
	# Apply green material to spawn location
	var mesh_inst: MeshInstance3D = spawn_pad.get_node("MeshInstance3D")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.4)
	mesh_inst.material_override = mat

	print("[Luani PlaceLoader] Instantiated default starter world for place: ", place_id)
	place_loaded.emit(place_id, target_world_root)
