class_name LuaniAvatar
extends Node3D
## Original six-piece block humanoid. No Roblox meshes, textures or animation files.

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

func _ready() -> void:
	var cloth := _material(_appearance_color("cloth", "424b69"))
	var sleeves := _material(_appearance_color("sleeves", "e6e8ef"))
	var trousers := _material(_appearance_color("trousers", "33384c"))
	var skin := _material(_appearance_color("skin", "d6b49a"))
	var ink := _material(Color("292b39"))
	var accent := _material(_appearance_color("accent", "c1adff"))
	torso = _part("Torso", Vector3(0, 1.70, 0), Vector3(1.02, 1.12, 0.58), Vector3.ZERO, cloth)
	head = _part("Head", Vector3(0, 2.66, 0), Vector3(0.74, 0.74, 0.70), Vector3.ZERO, skin)
	left_arm = _part("LeftArm", Vector3(-0.75, 2.19, 0), Vector3(0.43, 1.14, 0.52), Vector3(0, -0.52, 0), sleeves)
	right_arm = _part("RightArm", Vector3(0.75, 2.19, 0), Vector3(0.43, 1.14, 0.52), Vector3(0, -0.52, 0), sleeves)
	left_leg = _part("LeftLeg", Vector3(-0.27, 1.14, 0), Vector3(0.49, 1.10, 0.55), Vector3(0, -0.55, 0), trousers)
	right_leg = _part("RightLeg", Vector3(0.27, 1.14, 0), Vector3(0.49, 1.10, 0.55), Vector3(0, -0.55, 0), trousers)
	# Luani's own small uniform accent, not another platform's logo.
	var stripe := _box(Vector3(0.12, 0.52, 0.018), accent)
	stripe.position = Vector3(-0.25, 0.10, -0.301)
	stripe.rotation.z = -0.30
	torso.add_child(stripe)
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.038
		sphere.height = 0.076
		eye.mesh = sphere
		eye.material_override = ink
		eye.position = Vector3(side * 0.145, 0.065, -0.355)
		eye.scale = Vector3(1, 1.15, 0.35)
		head.add_child(eye)
		_eyes.append(eye)
	var mouth := _box(Vector3(0.13, 0.022, 0.014), ink)
	mouth.position = Vector3(0, -0.12, -0.357)
	head.add_child(mouth)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _appearance_color(key: String, fallback: String) -> Color:
	var value := str(appearance.get(key, fallback))
	return Color.from_string("#" + value, Color(fallback)) if value.length() == 6 else Color(fallback)

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
