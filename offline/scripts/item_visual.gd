extends RefCounted
## Original primitive-built game items. Never loads third-party meshes or scripts.

static func material(color: String, metallic: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.metallic = metallic
	m.roughness = 0.45 if metallic > 0 else 0.8
	if glow:
		m.emission_enabled = true
		m.emission = Color(color)
		m.emission_energy_multiplier = 0.7
	return m

static func box(parent: Node3D, dimensions: Vector3, position: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	n.mesh = mesh
	n.material_override = mat
	n.position = position
	parent.add_child(n)
	return n

static func cylinder(parent: Node3D, radius: float, height: float, position: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	n.mesh = mesh
	n.material_override = mat
	n.position = position
	parent.add_child(n)
	return n

static func make(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "OriginalTool_" + id
	match id:
		"sword":
			var steel := material("dbe4f1", 0.8)
			var lavender := material("c1adff", 0.55)
			var grip := material("292b39")
			cylinder(root, 0.055, 0.34, Vector3.ZERO, grip)
			box(root, Vector3(0.58, 0.09, 0.14), Vector3(0, 0.20, 0), lavender)
			box(root, Vector3(0.16, 1.15, 0.055), Vector3(0, 0.81, 0), steel)
			var tip := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.09
			cone.height = 0.20
			cone.radial_segments = 4
			tip.mesh = cone
			tip.material_override = steel
			tip.position.y = 1.48
			root.add_child(tip)
			cylinder(root, 0.08, 0.08, Vector3(0, -0.21, 0), lavender)
		"lantern":
			var frame := material("33384c", 0.65)
			var warm := material("f0cd8d", 0.0, true)
			var cap := material("c1adff", 0.4)
			var glow := box(root, Vector3(0.34, 0.42, 0.34), Vector3(0, 0.30, 0), warm)
			glow.name = "LanternGlow"
			box(root, Vector3(0.44, 0.07, 0.44), Vector3(0, 0.06, 0), frame)
			box(root, Vector3(0.44, 0.07, 0.44), Vector3(0, 0.55, 0), cap)
			for x: float in [-0.19, 0.19]:
				for z: float in [-0.19, 0.19]:
					box(root, Vector3(0.035, 0.46, 0.035), Vector3(x, 0.30, z), frame)
			box(root, Vector3(0.24, 0.025, 0.035), Vector3(0, 0.76, 0), frame)
			for x: float in [-0.11, 0.11]:
				box(root, Vector3(0.025, 0.18, 0.035), Vector3(x, 0.66, 0), frame)
			var light := OmniLight3D.new()
			light.name = "LanternLight"
			light.position.y = 0.35
			light.light_color = Color("ffe1a8")
			light.light_energy = 2.0
			light.omni_range = 9.0
			light.shadow_enabled = false
			root.add_child(light)
		"spring_coil":
			var mint := material("b8dfcb", 0.5, true)
			var dark := material("33384c", 0.5)
			cylinder(root, 0.06, 0.70, Vector3(0, 0.26, 0), dark)
			for index in range(6):
				var ring := MeshInstance3D.new()
				var mesh := TorusMesh.new()
				mesh.inner_radius = 0.13
				mesh.outer_radius = 0.19
				mesh.rings = 16
				mesh.ring_segments = 8
				ring.mesh = mesh
				ring.material_override = mint
				ring.position.y = float(index) * 0.10
				root.add_child(ring)
	return root
