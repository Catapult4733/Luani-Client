extends Node
## Data-only mesh/resource contract, no main game, networking or rendering.
var checks:=0
var failed:=false
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failed=true;push_error("RENDER CONTRACT: "+label)
func _ready() -> void:
	var visual: Variant=load("res://scripts/item_visual.gd")
	var names: Array=[]
	for method in visual.get_script_method_list():names.append(str(method.name))
	check(names.has("compact_for_mobile"),"mobile rigid meshes must be batched without changing shape")
	if failed:get_tree().quit(1);return
	for id in ["sword","lantern","spring_coil"]:
		var root: Node3D=visual.make(id)
		var before:=measure(root)
		visual.compact_for_mobile(root,id)
		var after:=measure(root)
		check(after.faces==before.faces,id+" triangle count")
		check(after.bounds.position.is_equal_approx(before.bounds.position) and after.bounds.size.is_equal_approx(before.bounds.size),id+" bounds and transforms")
		check(int(after.meshes)<=3,id+" mobile mesh-node budget")
		for child in root.get_children():
			if child is MeshInstance3D:
				for surface in range(child.mesh.get_surface_count()):check(child.mesh.surface_get_material(surface)!=null or child.material_override!=null,id+" material retained")
		if id=="lantern":check(root.find_child("LanternGlow",true,false)!=null and root.find_child("LanternLight",true,false)!=null,"lantern toggles retained")
		var second: Node3D=visual.make(id);visual.compact_for_mobile(second,id)
		check(root.get_node("MobileBatch").mesh==second.get_node("MobileBatch").mesh,id+" immutable mesh cache shared, not nodes")
		check(root.get_node("MobileBatch")!=second.get_node("MobileBatch"),id+" node independence")
		root.free();second.free()
	print(JSON.stringify({"render_contract_checks":checks,"passed":not failed,"main_game_scene_started":false}))
	get_tree().quit(1 if failed else 0)
func measure(root: Node3D) -> Dictionary:
	var faces:=0
	var count:=0
	var bounds:=AABB()
	var first:=true
	for child in root.get_children():
		if child is MeshInstance3D:
			count+=1
			var points: PackedVector3Array=child.mesh.get_faces();faces+=points.size()
			for point in points:
				var p: Vector3=child.transform*point
				if first:bounds=AABB(p,Vector3.ZERO);first=false
				else:bounds=bounds.expand(p)
	return {"faces":faces,"meshes":count,"bounds":bounds}
