extends SceneTree
## Reviewer runtime contract: run on edward, not the Pi. No real account/network.
const Avatar = preload("res://scripts/avatar.gd")
const Data = preload("res://scripts/avatar_data.gd")
const Sync = preload("res://scripts/avatar_sync.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var defaults: Dictionary = Data.normalize({"skin":"123456", "sleeves":"556677"})
	assert(defaults.colors.head == "123456")
	assert(defaults.colors.left_arm == "556677" and defaults.colors.right_arm == "556677")
	assert(defaults.accessories.is_empty(), "Catalog presence must never equip anything")
	var rig := Avatar.new()
	root.add_child(rig)
	await process_frame
	assert(rig._accessory_nodes.is_empty())
	var arm: Node3D = rig.right_arm
	var held_tool := Node3D.new()
	held_tool.name = "TestOnlyHeldTool"
	arm.add_child(held_tool)
	var saved: Dictionary = Data.normalize({})
	saved.colors.left_arm = "112233"; saved.colors.right_arm = "ff2211"
	saved.accessories = [{"id":"orbit-cap", "position":[0.25,0.1,-0.15], "rotation":[15,45,90]}]
	saved.revision = 1
	rig.apply_appearance(saved)
	assert(rig.right_arm == arm and held_tool.get_parent() == arm, "Hot refresh must preserve held tools/pivots")
	assert((rig._body_materials.left_arm as StandardMaterial3D).albedo_color.is_equal_approx(Color("112233")))
	assert((rig._body_materials.right_arm as StandardMaterial3D).albedo_color.is_equal_approx(Color("ff2211")))
	assert(rig._accessory_nodes.size() == 1)
	var cap: Node3D = rig._accessory_nodes[0]
	assert(cap.get_parent() == rig.head)
	assert(cap.position.is_equal_approx(Vector3(0.25,0.1,-0.15)))
	assert(cap.rotation_order == EULER_ORDER_XYZ)
	var expected := Basis.from_euler(Vector3(deg_to_rad(15),deg_to_rad(45),deg_to_rad(90)), EULER_ORDER_XYZ)
	assert(cap.basis.is_equal_approx(expected))
	# Every original SKU must construct its own local data-only mesh, not an URL.
	for item: Dictionary in Data.definition().catalog:
		saved.accessories = [{"id":item.id, "position":[0,0,0], "rotation":[0,0,0]}]
		saved.revision += 1
		rig.apply_appearance(saved)
		assert(rig._accessory_nodes.size() == 1)
		assert(rig._accessory_nodes[0].get_child_count() == item.primitives.size())
	saved.accessories = []; saved.revision += 1; rig.apply_appearance(saved)
	assert(rig._accessory_nodes.is_empty() and held_tool.get_parent() == arm)
	var peers := {
		1:{"phase":"admitted","admission_id":"fixture-admission-a","room":"room-a","profile":{"public_id":1,"avatar":{"revision":0}}},
		2:{"phase":"admitted","admission_id":"fixture-admission-b","room":"room-b","profile":{"public_id":2,"avatar":{"revision":0}}}
	}
	var rooms: Array[String] = Sync.apply_updates(peers,[{"admission_id":"fixture-admission-a","public_id":2,"avatar":{"revision":1}}])
	assert(rooms.is_empty(), "Cross-player identity must not refresh a different peer")
	rooms = Sync.apply_updates(peers,[{"admission_id":"fixture-admission-a","public_id":1,"avatar":saved}])
	assert(rooms == ["room-a"] and peers[2].profile.avatar.revision == 0)
	assert(Sync.apply_updates(peers,[{"admission_id":"fixture-admission-a","public_id":1,"avatar":{"revision":0}}]).is_empty())
	rig.queue_free()
	await process_frame
	print("Avatar rendering and admission-bound refresh runtime contracts passed; fixture-only, no backend or multiplayer verification.")
	quit(0)
