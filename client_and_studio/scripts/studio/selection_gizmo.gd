# client_and_studio/scripts/studio/selection_gizmo.gd
class_name SelectionGizmo
extends Node3D

## Manages 3D Part Selection and Move/Rotate/Scale Transform Handles

signal selection_changed(selected_node: Node3D)
signal transform_modified(selected_node: Node3D)

enum GizmoMode { MOVE, ROTATE, SCALE }

@export var camera: Camera3D

var current_mode: GizmoMode = GizmoMode.MOVE
var selected_part: Node3D = null

# Visual gizmo handles
var handles_root: Node3D
var active_axis: String = "" # "X", "Y", "Z"
var is_transforming: bool = false
var drag_start_mouse_pos: Vector2
var drag_start_transform: Transform3D

func _ready() -> void:
	_create_gizmo_mesh_handles()

func _create_gizmo_mesh_handles() -> void:
	handles_root = Node3D.new()
	handles_root.name = "GizmoHandles"
	handles_root.visible = false
	add_child(handles_root)

	# X Axis (Red)
	_add_axis_handle("Axis_X", Vector3(1, 0, 0), Color(0.9, 0.2, 0.2))
	# Y Axis (Green)
	_add_axis_handle("Axis_Y", Vector3(0, 1, 0), Color(0.2, 0.9, 0.2))
	# Z Axis (Blue)
	_add_axis_handle("Axis_Z", Vector3(0, 0, 1), Color(0.2, 0.4, 0.9))

func _add_axis_handle(axis_name: String, dir: Vector3, color: Color) -> void:
	var handle := MeshInstance3D.new()
	handle.name = axis_name
	
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = 1.5
	handle.mesh = cyl
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.no_depth_test = true
	handle.material_override = mat
	
	handles_root.add_child(handle)
	
	# Align cylinder to axis direction
	if dir == Vector3(1, 0, 0):
		handle.rotation_degrees = Vector3(0, 0, -90)
		handle.position = Vector3(0.75, 0, 0)
	elif dir == Vector3(0, 1, 0):
		handle.position = Vector3(0, 0.75, 0)
	elif dir == Vector3(0, 0, 1):
		handle.rotation_degrees = Vector3(90, 0, 0)
		handle.position = Vector3(0, 0, 0.75)

func set_selected_part(part: Node3D) -> void:
	selected_part = part
	if selected_part:
		handles_root.visible = true
		handles_root.global_position = selected_part.global_position
		handles_root.global_rotation = selected_part.global_rotation
	else:
		handles_root.visible = false
		
	selection_changed.emit(selected_part)

func set_gizmo_mode(mode: GizmoMode) -> void:
	current_mode = mode
	print("[Luani SelectionGizmo] Switched mode to: ", GizmoMode.keys()[mode])

func handle_viewport_click(mouse_pos: Vector2, viewport: Viewport) -> void:
	if not camera:
		return

	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var ray_length := 1000.0

	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * ray_length)
	
	var result := space_state.intersect_ray(query)
	if result and result.has("collider"):
		var collider: Object = result["collider"]
		if collider is Node3D:
			set_selected_part(collider as Node3D)
	else:
		set_selected_part(null)

func _process(_delta: float) -> void:
	if selected_part and is_instance_valid(selected_part):
		handles_root.global_position = selected_part.global_position
