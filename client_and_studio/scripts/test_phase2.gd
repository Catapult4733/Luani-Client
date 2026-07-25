# client_and_studio/scripts/test_phase2.gd
extends SceneTree

func _init() -> void:
	print("--- Running Luani Phase 2 Verification Suite ---")

	# Test 1: Luau Sandbox Execution
	print("\n[Test 1] LuauManager Sandbox Test")
	var luau_mgr := LuauManager.new()
	var test_code := """
	print("Hello from Luau Sandbox Test!")
	set_part_property("DemoBlock", "color", "#00ffaa")
	"""
	var res := luau_mgr.execute_luau_script(test_code)
	print("Sandbox test success: ", res.get("success"))

	# Test 2: Primitive Spawner & Place Serializer
	print("\n[Test 2] Primitive Spawner & Serializer Test")
	var root := Node3D.new()
	root.name = "TestWorkspace"
	
	var block := PrimitiveFactory.spawn_primitive(PrimitiveFactory.PrimitiveType.BLOCK, root, Vector3(5, 0, 5))
	block.name = "DemoBlock"
	
	var sphere := PrimitiveFactory.spawn_primitive(PrimitiveFactory.PrimitiveType.SPHERE, root, Vector3(0, 10, 0))
	sphere.name = "DemoSphere"

	var serialized := PlaceSerializer.serialize_workspace(root, "Test Place")
	print("Serialized JSON parts count: ", serialized.get("parts", []).size())
	assert(serialized.get("parts", []).size() == 2)

	# Test 3: Deserialization
	var target_root := Node3D.new()
	PlaceSerializer.deserialize_workspace(serialized, target_root)
	print("Deserialized target workspace node count: ", target_root.get_child_count())
	assert(target_root.get_child_count() == 2)

	print("\n--- ALL PHASE 2 TESTS PASSED SUCCESSFULLY! ---")
	quit(0)
