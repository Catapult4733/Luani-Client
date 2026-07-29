# client_and_studio/scripts/test_phase2.gd
extends SceneTree

func _init() -> void:
	print("--- Running Luani Phase 2 Verification Suite ---")

	# Test 1: Luau Sandbox Execution
	print("\n[Test 1] LuauManager Sandbox Test")
	var luau_mgr = load("res://scripts/core/luau_manager.gd").new()
	var test_code := """
	print("Hello from Luau Sandbox Test!")
	set_part_property("DemoBlock", "color", "#00ffaa")
	"""
	var res: Dictionary = luau_mgr.execute_luau_script(test_code)
	print("Sandbox test success: ", res.get("success", false))

	# Test 2: Primitive Spawner & Place Serializer
	print("\n[Test 2] Primitive Spawner & Serializer Test")
	var root := Node3D.new()
	root.name = "TestWorkspace"
	
	var factory_script = load("res://scripts/studio/primitive_factory.gd")
	var serializer_script = load("res://scripts/studio/place_serializer.gd")

	var block = factory_script.spawn_primitive(factory_script.PrimitiveType.BLOCK, root, Vector3(5, 0, 5))
	block.name = "DemoBlock"
	
	var sphere = factory_script.spawn_primitive(factory_script.PrimitiveType.SPHERE, root, Vector3(0, 10, 0))
	sphere.name = "DemoSphere"

	var serialized: Dictionary = serializer_script.serialize_workspace(root, "Test Place")
	print("Serialized JSON parts count: ", serialized.get("parts", []).size())
	assert(serialized.get("parts", []).size() == 2)

	# Test 3: Deserialization
	var target_root := Node3D.new()
	serializer_script.deserialize_workspace(serialized, target_root)
	print("Deserialized target workspace node count: ", target_root.get_child_count())
	assert(target_root.get_child_count() == 2)

	print("\n--- ALL PHASE 2 TESTS PASSED SUCCESSFULLY! ---")
	quit(0)
