class_name LuaniAvatar
extends Node3D
## Original six-piece block humanoid. No Roblox meshes, textures or animation files.
const AvatarData = preload("res://scripts/avatar_data.gd")

var motion_speed: float = 0.0
var airborne: bool = false
var vertical_speed: float = 0.0
var running: bool = false
var appearance: Dictionary = {}
var holding_tool: bool = false
var tool_swing: float = 0.0
var _phase: float = 0.0
var _clock: float = 0.0
var _blend: float = 0.0
var torso: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var _eyes: Array[MeshInstance3D] = []
var _body_materials: Dictionary = {}
var _pivots: Dictionary = {}
var _accessory_nodes: Array[Node3D] = []

func _ready() -> void:
	var spec: Dictionary = AvatarData.definition()
	if spec.is_empty(): set_process(false); return
	appearance = AvatarData.normalize(appearance)
	for part: Dictionary in spec.parts:
		var body_material := _material(Color.from_string("#" + str(appearance.colors[part.id]), Color(str(part.color))))
		_body_materials[part.id] = body_material
		_pivots[part.id] = _part(str(part.id).to_pascal_case(), _vector(part.origin), _vector(part.size), _vector(part.offset), body_material)
	torso = _pivots.torso; head = _pivots.head
	left_arm = _pivots.left_arm; right_arm = _pivots.right_arm
	left_leg = _pivots.left_leg; right_leg = _pivots.right_leg
	var ink := _material(Color("292b39"))
	var accent := _material(Color.from_string("#" + str(appearance.accent), Color("c1adff")))
	_body_materials["accent"] = accent
	# Luani's own small uniform accent, not another platform's logo.
	var stripe := _box(Vector3(0.12, 0.52, 0.018), accent)
	stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stripe.position = Vector3(-0.25, 0.10, -0.301)
	stripe.rotation.z = -0.30
	torso.add_child(stripe)
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.038
		sphere.height = 0.076
		sphere.radial_segments = 12
		sphere.rings = 6
		eye.mesh = sphere
		eye.material_override = ink
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.position = Vector3(side * 0.145, 0.065, -0.355)
		eye.scale = Vector3(1, 1.15, 0.35)
		head.add_child(eye)
		_eyes.append(eye)
	var mouth := _box(Vector3(0.13, 0.022, 0.014), ink)
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mouth.position = Vector3(0, -0.12, -0.357)
	head.add_child(mouth)
	_rebuild_accessories()

func apply_appearance(value: Dictionary) -> void:
	var normalized: Dictionary = AvatarData.normalize(value)
	if normalized == appearance: return
	appearance = normalized
	if not is_node_ready() or _body_materials.is_empty(): return
	for part: String in appearance.colors:
		(_body_materials[part] as StandardMaterial3D).albedo_color = Color.from_string("#" + str(appearance.colors[part]), Color.WHITE)
	(_body_materials.accent as StandardMaterial3D).albedo_color = Color.from_string("#" + str(appearance.accent), Color("c1adff"))
	# Keep body pivots, eyes, animation phase and any held game tool intact.
	_rebuild_accessories()

func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _rebuild_accessories() -> void:
	for node: Node3D in _accessory_nodes:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_accessory_nodes.clear()
	for saved: Dictionary in appearance.get("accessories", []):
		var item: Dictionary = AvatarData.catalog_item(str(saved.id))
		if item.is_empty() or not _pivots.has(item.anchor): continue
		var attachment := Node3D.new()
		attachment.name = "Accessory_" + str(item.id)
		attachment.position = _vector(saved.position)
		attachment.rotation_order = EULER_ORDER_XYZ
		attachment.rotation_degrees = _vector(saved.rotation)
		(_pivots[item.anchor] as Node3D).add_child(attachment)
		_accessory_nodes.append(attachment)
		for definition: Dictionary in item.primitives:
			var mesh: Mesh = _accessory_mesh(definition)
			if mesh == null: continue
			var piece := MeshInstance3D.new()
			piece.mesh = mesh
			piece.material_override = _material(Color.from_string("#" + str(definition.color), Color.WHITE))
			piece.position = _vector(definition.position)
			piece.rotation_order = EULER_ORDER_XYZ
			piece.rotation_degrees = _vector(definition.get("rotation", [0,0,0]))
			attachment.add_child(piece)

func _accessory_mesh(definition: Dictionary) -> Mesh:
	match str(definition.shape):
		"box":
			var box := BoxMesh.new(); box.size = _vector(definition.size); return box
		"sphere":
			var sphere := SphereMesh.new(); sphere.radius = float(definition.radius); sphere.height = sphere.radius * 2.0
			sphere.radial_segments = 16; sphere.rings = 8; return sphere
		"cylinder":
			var cylinder := CylinderMesh.new(); cylinder.top_radius = float(definition.radius); cylinder.bottom_radius = float(definition.radius)
			cylinder.height = float(definition.height); cylinder.radial_segments = 16; return cylinder
		"torus":
			var torus := TorusMesh.new(); torus.inner_radius = float(definition.radius) - float(definition.tube); torus.outer_radius = float(definition.radius) + float(definition.tube)
			torus.rings = 24; torus.ring_segments = 8; return torus
	return null

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	piece.material_override = material
	return piece

func _part(label: String, origin: Vector3, size: Vector3, offset: Vector3, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = origin
	add_child(pivot)
	var piece := _box(size, material)
	piece.position = offset
	pivot.add_child(piece)
	return pivot

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_clock += delta
	_blend = move_toward(_blend, clampf(motion_speed / 7.0, 0.0, 1.0), delta * 7.0)
	_phase += delta * (12.0 if running else 8.0) * clampf(motion_speed / 5.0, 0.0, 1.4)
	var swing := sin(_phase) * _blend * (0.90 if running else 0.62)
	var idle := sin(_clock * 2.0) * 0.025 * (1.0 - _blend)
	var target_left_arm := -swing - 0.04 + idle
	var target_right_arm := swing - 0.04 - idle
	var target_left_leg := swing
	var target_right_leg := -swing
	if airborne:
		target_left_arm = -0.65 if vertical_speed > 0 else -0.30
		target_right_arm = target_left_arm
		target_left_leg = 0.20
		target_right_leg = -0.25
	tool_swing = maxf(0.0, tool_swing - delta)
	if holding_tool:
		target_right_arm = 0.65
	if tool_swing > 0:
		var progress := 1.0 - tool_swing / 0.32
		target_right_arm = lerpf(1.45, -0.25, progress)
	var blend := minf(delta * 14.0, 1.0)
	left_arm.rotation.x = lerpf(left_arm.rotation.x, target_left_arm, blend)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, target_right_arm, blend)
	left_leg.rotation.x = lerpf(left_leg.rotation.x, target_left_leg, blend)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, target_right_leg, blend)
	left_arm.rotation.z = 0.06 + idle
	right_arm.rotation.z = -0.06 - idle
	if tool_swing > 0:
		right_arm.rotation.z = -0.35 + sin((1.0 - tool_swing / 0.32) * PI) * 0.65
	torso.position.y = 1.70 + absf(sin(_phase)) * _blend * 0.035 + idle * 0.25
	torso.rotation.x = lerpf(torso.rotation.x, -0.06 if running and motion_speed > 1 else 0.0, blend)
	head.rotation.z = idle * 0.5
	var blink := fmod(_clock, 4.7) > 4.58
	for eye in _eyes:
		eye.scale.y = 0.12 if blink else 1.15
