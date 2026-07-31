# client_and_studio/scripts/core/place_loader.gd
extends Node

## Loads and instantiates .luani place JSON files from API endpoints or local storage

signal place_loading_started(place_id: String)
signal place_loaded(place_id: String, world_root: Node3D)
signal place_load_failed(place_id: String, error_msg: String)

@export var backend_api_url: String = "https://www.luani.fyi/api/places"

const SWORD_ARENA_SCENE := preload("res://scenes/places/place_sword_arena.tscn")

## Loads a place by ID into target_world_root (downloads from backend or falls back to starter place)
func load_place(place_id: String, target_world_root: Node3D) -> void:
	place_loading_started.emit(place_id)
	print("[Luani PlaceLoader] Requesting place ID: ", place_id)

	# Local packed scene check for sword arena
	if place_id == "place_sword_arena" or place_id == "sword_arena":
		_instantiate_sword_arena(place_id, target_world_root)
		return

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
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary and parsed.has("place"):
			var place_dict: Dictionary = parsed["place"]
			if place_dict.has("allow_pets") and target_world_root:
				target_world_root.set_meta("allow_pets", bool(place_dict["allow_pets"]))
				print("[Luani PlaceLoader] Allow Pets setting for place: ", place_dict["allow_pets"])
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

func _instantiate_sword_arena(place_id: String, target_world_root: Node3D) -> void:
	for child in target_world_root.get_children():
		child.queue_free()

	var arena := SWORD_ARENA_SCENE.instantiate()
	target_world_root.add_child(arena)
	print("[Luani PlaceLoader] Instantiated Sword Arena place: ", place_id)
	place_loaded.emit(place_id, target_world_root)

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

	# Spawn Physics Baseplate Ball (RigidBody3D, 5.0 kg mass, glossy sphere)
	var ball := RigidBody3D.new()
	ball.name = "BaseplateBall"
	ball.mass = 5.0
	ball.position = Vector3(4.0, 2.5, 4.0)

	var ball_col := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 1.2
	ball_col.shape = sphere_shape
	ball.add_child(ball_col)

	var ball_mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.2
	sphere_mesh.height = 2.4
	ball_mesh.mesh = sphere_mesh

	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = Color(0.95, 0.35, 0.25)
	ball_mat.roughness = 0.2
	ball_mat.metallic = 0.5
	ball_mesh.material_override = ball_mat
	ball.add_child(ball_mesh)

	target_world_root.add_child(ball)

	print("[Luani PlaceLoader] Instantiated default starter world & physics baseplate ball for place: ", place_id)
	place_loaded.emit(place_id, target_world_root)
