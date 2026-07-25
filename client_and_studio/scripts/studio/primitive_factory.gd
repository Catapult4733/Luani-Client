# client_and_studio/scripts/studio/primitive_factory.gd
class_name PrimitiveFactory
extends Node

## Factory utility to instantiate 3D Primitive Parts with Collision Shapes and Materials

enum PrimitiveType { BLOCK, SPHERE, CYLINDER, WEDGE }

static var part_counter: int = 1

## Spawns a primitive Node3D object (RigidBody3D or StaticBody3D) under parent_node
static func spawn_primitive(type: PrimitiveType, parent_node: Node, spawn_pos: Vector3 = Vector3.ZERO) -> RigidBody3D:
	var part := RigidBody3D.new()
	part.freeze = true # Anchored by default in Studio edit mode
	
	var part_name := ""
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	
	var col_shape := CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	
	var default_mat := StandardMaterial3D.new()
	default_mat.roughness = 0.4
	
	match type:
		PrimitiveType.BLOCK:
			part_name = "Block_" + str(part_counter)
			default_mat.albedo_color = Color(0.2, 0.6, 0.9)
			var box := BoxMesh.new()
			box.size = Vector3(2, 2, 2)
			mesh_inst.mesh = box
			
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(2, 2, 2)
			col_shape.shape = box_shape
			
		PrimitiveType.SPHERE:
			part_name = "Sphere_" + str(part_counter)
			default_mat.albedo_color = Color(0.9, 0.3, 0.3)
			var sphere := SphereMesh.new()
			sphere.radius = 1.0
			sphere.height = 2.0
			mesh_inst.mesh = sphere
			
			var sphere_shape := SphereShape3D.new()
			sphere_shape.radius = 1.0
			col_shape.shape = sphere_shape
			
		PrimitiveType.CYLINDER:
			part_name = "Cylinder_" + str(part_counter)
			default_mat.albedo_color = Color(0.3, 0.8, 0.4)
			var cyl := CylinderMesh.new()
			cyl.top_radius = 1.0
			cyl.bottom_radius = 1.0
			cyl.height = 2.0
			mesh_inst.mesh = cyl
			
			var cyl_shape := CylinderShape3D.new()
			cyl_shape.radius = 1.0
			cyl_shape.height = 2.0
			col_shape.shape = cyl_shape
			
		PrimitiveType.WEDGE:
			part_name = "Wedge_" + str(part_counter)
			default_mat.albedo_color = Color(0.9, 0.7, 0.2)
			var prism := PrismMesh.new()
			prism.size = Vector3(2, 2, 2)
			mesh_inst.mesh = prism
			
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(2, 2, 2)
			col_shape.shape = box_shape

	part_counter += 1
	part.name = part_name
	mesh_inst.material_override = default_mat
	
	part.add_child(mesh_inst)
	part.add_child(col_shape)
	
	# Set owner for scenes / serialization
	mesh_inst.owner = part
	col_shape.owner = part
	
	# Store metadata for serialization
	part.set_meta("primitive_type", type)
	part.set_meta("luau_script", "-- Attached Luau script\nprint('Hello from " + part_name + "')")
	part.set_meta("anchored", true)
	
	parent_node.add_child(part)
	part.global_position = spawn_pos
	
	return part
