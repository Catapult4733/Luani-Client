extends Node3D
## Only trusted fixed constructors. Weld components become one rigid assembly.
const Data = preload("res://scripts/studio_data.gd")
var nodes: Dictionary = {}
var bodies: Dictionary = {}
var dynamic_ids: Array[String] = []
var _document: Dictionary = {}
var _mode: String = "editor"

func build(document: Dictionary, mode: String = "editor") -> String:
	var error: String = Data.validate(document)
	if not error.is_empty(): return error
	for child: Node in get_children(): remove_child(child); child.queue_free()
	nodes.clear(); bodies.clear(); dynamic_ids.clear()
	_document = document.duplicate(true); _mode = mode
	for item: Dictionary in _document.objects: _make_node(item)
	if mode != "editor": _weld_assemblies()
	return ""

func environment() -> void:
	var world_environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("91aec7")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b9c8dd")
	settings.ambient_light_energy = 0.65
	world_environment.environment = settings
	add_child(world_environment)

func _make_node(item: Dictionary) -> Node3D:
	if nodes.has(item.id): return nodes[item.id]
	var node := Node3D.new()
	node.rotation_order = EULER_ORDER_XYZ
	node.name = item.id; node.set_meta("studio_id", str(item.id))
	var parent: Node3D = self
	if item.parent != null: parent = _make_node(Data.by_id(_document,str(item.parent)))
	parent.add_child(node); nodes[item.id] = node
	var properties: Dictionary = item.properties
	if properties.has("position"): node.position = Data.vector(properties.position)
	if properties.has("rotation"): node.rotation_degrees = Data.vector(properties.rotation)
	match str(item["class"]):
		"Part", "SpawnPoint": _part(node,item)
		"PointLight", "SpotLight", "DirectionalLight": _light(node,item)
	return node

func _mesh(properties: Dictionary) -> Mesh:
	var size: Vector3 = Data.vector(properties.size)
	match str(properties.get("shape","Block")):
		"Ball":
			var mesh := SphereMesh.new(); mesh.radius = 0.5; mesh.height = 1.0; mesh.radial_segments = 16; mesh.rings = 8
			return mesh
		"Cylinder":
			var mesh := CylinderMesh.new(); mesh.top_radius = 0.5; mesh.bottom_radius = 0.5; mesh.height = 1.0; mesh.radial_segments = 16
			return mesh
	var mesh := BoxMesh.new(); mesh.size = size
	return mesh

func _part(node: Node3D, item: Dictionary) -> void:
	var p: Dictionary = item.properties
	var movable: bool = item["class"] == "Part" and p.get("anchored",true) == false
	var body: PhysicsBody3D
	if movable and _mode == "server": body = RigidBody3D.new()
	else: body = StaticBody3D.new()
	body.name = "Body"; body.collision_layer = 4 if _mode == "editor" else (1 if p.get("collidable",true) else 0)
	body.collision_mask = 0 if _mode == "editor" else 3
	body.set_meta("studio_id",str(item.id)); node.add_child(body); bodies[item.id] = body
	if movable: dynamic_ids.append(str(item.id))
	var visual := MeshInstance3D.new(); visual.mesh = _mesh(p)
	var dimensions: Vector3 = Data.vector(p.size)
	if p.get("shape","Block") != "Block": visual.scale = dimensions
	var material := StandardMaterial3D.new(); material.albedo_color = Color(str(p.color))
	material.albedo_color.a = 1.0 - float(p.get("transparency",0))
	if material.albedo_color.a < 1: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = material; body.add_child(visual)
	var collision := CollisionShape3D.new()
	if p.get("shape","Block") == "Block":
		var shape := BoxShape3D.new(); shape.size = dimensions; collision.shape = shape
	else:
		var shape := ConvexPolygonShape3D.new(); var points: PackedVector3Array = visual.mesh.get_faces()
		for index: int in range(points.size()): points[index] *= dimensions
		shape.points = points; collision.shape = shape
	body.add_child(collision)

func _light(node: Node3D, item: Dictionary) -> void:
	var light: Light3D
	var p: Dictionary = item.properties
	match str(item["class"]):
		"PointLight":
			var point := OmniLight3D.new(); point.omni_range = float(p.range); light = point
		"SpotLight":
			var spot := SpotLight3D.new(); spot.spot_range = float(p.range); spot.spot_angle = float(p.angle); light = spot
		_:
			light = DirectionalLight3D.new()
	light.light_color = Color(str(p.color)); light.light_energy = float(p.brightness); light.shadow_enabled = bool(p.shadows)
	node.add_child(light)
	if _mode == "editor":
		var marker := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius = 0.25; sphere.height = 0.5
		marker.mesh = sphere; var material := StandardMaterial3D.new(); material.albedo_color = Color("ffe38e"); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; marker.material_override = material; node.add_child(marker)
		var pick := StaticBody3D.new(); pick.collision_layer = 4; pick.collision_mask = 0; pick.set_meta("studio_id",str(item.id)); node.add_child(pick)
		var collision := CollisionShape3D.new(); var shape := SphereShape3D.new(); shape.radius = 0.5; collision.shape = shape; pick.add_child(collision)

func _root(groups: Dictionary, id: String) -> String:
	var at: String = id
	while str(groups[at]) != at: at = str(groups[at])
	return at

func _weld_assemblies() -> void:
	var groups: Dictionary = {}
	for id: String in bodies: groups[id] = id
	for item: Dictionary in _document.objects:
		if item["class"] == "Weld" and item.properties.enabled:
			var first: String = _root(groups,str(item.properties.part0))
			var second: String = _root(groups,str(item.properties.part1))
			groups[second] = first
	var components: Dictionary = {}
	for id: String in groups:
		var root: String = _root(groups,id)
		if not components.has(root): components[root] = []
		components[root].append(id)
	var next_dynamic: Array[String] = []
	for id: String in components:
		var members: Array = components[id]
		var anchored: bool = false
		for member: String in members:
			var item: Dictionary = Data.by_id(_document,member)
			if item["class"] == "SpawnPoint" or item.properties.get("anchored",true): anchored = true
		if members.size() == 1:
			if not anchored: next_dynamic.append(id)
			continue
		var assembly: PhysicsBody3D
		if not anchored and _mode == "server": assembly = RigidBody3D.new()
		else: assembly = StaticBody3D.new()
		var origin: Transform3D = (bodies[id] as Node3D).global_transform
		add_child(assembly); assembly.global_transform = origin; assembly.collision_layer = 0; assembly.collision_mask = 3
		for member: String in members:
			var old: PhysicsBody3D = bodies[member]
			assembly.collision_layer |= old.collision_layer
			for child: Node in old.get_children():
				if child is CollisionShape3D and old.collision_layer == 0: child.disabled = true
				child.reparent(assembly,true)
			old.get_parent().remove_child(old); old.queue_free(); bodies[member] = assembly
		if not anchored: next_dynamic.append(id)
	dynamic_ids = next_dynamic

func spawn_position() -> Vector3:
	for item: Dictionary in _document.objects:
		if item["class"] == "SpawnPoint":
			var node: Node3D = nodes[item.id]
			return node.global_position - global_position + Vector3.UP * (float(item.properties.size[1]) * 0.5 + 0.25)
	return Vector3(0,3,0)

func dynamic_state() -> Array:
	var output: Array = []
	for id: String in dynamic_ids.slice(0,64):
		var body: Node3D = bodies[id]
		var p: Vector3 = body.global_position - global_position
		var r: Vector3 = body.global_rotation
		output.append([id,snappedf(p.x,0.001),snappedf(p.y,0.001),snappedf(p.z,0.001),snappedf(r.x,0.001),snappedf(r.y,0.001),snappedf(r.z,0.001)])
	return output

func kill_height() -> float:
	var lowest: float = 0
	for item: Dictionary in _document.objects:
		if item["class"] in ["Part","SpawnPoint"]:
			var node: Node3D = nodes[item.id]
			lowest = minf(lowest,node.global_position.y-global_position.y-Data.vector(item.properties.size).length()*0.5)
	return lowest-100

func apply_dynamic(state: Array) -> void:
	if state.size() > 64: return
	for row: Variant in state:
		if not row is Array or row.size() != 7 or not row[0] is String or not row[0] in dynamic_ids: continue
		var valid: bool = true
		for value: Variant in row.slice(1):
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > 200000: valid = false
		if not valid: continue
		var body: Node3D = bodies[row[0]]
		body.global_position = global_position + Vector3(float(row[1]),float(row[2]),float(row[3]))
		body.global_rotation = Vector3(float(row[4]),float(row[5]),float(row[6]))
