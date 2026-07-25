# client_and_studio/studio/studio_main.gd
extends Control

## Main Luani Studio controller managing 3D Viewport, Docks, Toolbar, and Simulation

@onready var workspace: Node3D = %Workspace
@onready var studio_camera: Camera3D = %StudioCamera
@onready var selection_gizmo: SelectionGizmo = %SelectionGizmo

# Docks
@onready var hierarchy_dock: Control = %HierarchyDock
@onready var inspector_dock: Control = %InspectorDock
@onready var script_editor_dock: Control = %ScriptEditorDock

# Toolbar buttons
@onready var spawn_block_btn: Button = %SpawnBlockBtn
@onready var spawn_sphere_btn: Button = %SpawnSphereBtn
@onready var spawn_cylinder_btn: Button = %SpawnCylinderBtn
@onready var spawn_wedge_btn: Button = %SpawnWedgeBtn

@onready var mode_move_btn: Button = %ModeMoveBtn
@onready var mode_rotate_btn: Button = %ModeRotateBtn
@onready var mode_scale_btn: Button = %ModeScaleBtn

@onready var sim_play_btn: Button = %SimPlayBtn
@onready var sim_pause_btn: Button = %SimPauseBtn
@onready var sim_stop_btn: Button = %SimStopBtn

@onready var save_file_btn: Button = %SaveFileBtn
@onready var publish_btn: Button = %PublishBtn
@onready var status_banner: Label = %StatusBanner

# Simulation state
var pre_sim_snapshot: Dictionary = {}
var is_simulating: bool = false

func _ready() -> void:
	# Connect spawner buttons
	spawn_block_btn.pressed.connect(func(): _spawn_part(PrimitiveFactory.PrimitiveType.BLOCK))
	spawn_sphere_btn.pressed.connect(func(): _spawn_part(PrimitiveFactory.PrimitiveType.SPHERE))
	spawn_cylinder_btn.pressed.connect(func(): _spawn_part(PrimitiveFactory.PrimitiveType.CYLINDER))
	spawn_wedge_btn.pressed.connect(func(): _spawn_part(PrimitiveFactory.PrimitiveType.WEDGE))
	
	# Connect mode buttons
	mode_move_btn.pressed.connect(func(): selection_gizmo.set_gizmo_mode(SelectionGizmo.GizmoMode.MOVE))
	mode_rotate_btn.pressed.connect(func(): selection_gizmo.set_gizmo_mode(SelectionGizmo.GizmoMode.ROTATE))
	mode_scale_btn.pressed.connect(func(): selection_gizmo.set_gizmo_mode(SelectionGizmo.GizmoMode.SCALE))
	
	# Connect sim controls
	sim_play_btn.pressed.connect(_on_sim_play)
	sim_pause_btn.pressed.connect(_on_sim_pause)
	sim_stop_btn.pressed.connect(_on_sim_stop)
	
	# Connect publish & save
	save_file_btn.pressed.connect(_on_save_local)
	publish_btn.pressed.connect(_on_publish_click)
	
	# Connect selection gizmo to inspector & hierarchy
	selection_gizmo.selection_changed.connect(_on_selection_changed)
	selection_gizmo.camera = studio_camera
	
	if hierarchy_dock.has_method("setup"):
		hierarchy_dock.setup(workspace)
		hierarchy_dock.node_selected.connect(_on_hierarchy_node_selected)
		
	# Spawn initial default starter scene
	_spawn_starter_scene()

func _spawn_starter_scene() -> void:
	var baseplate := PrimitiveFactory.spawn_primitive(PrimitiveFactory.PrimitiveType.BLOCK, workspace, Vector3(0, -1, 0))
	baseplate.name = "Baseplate"
	baseplate.scale = Vector3(15, 0.5, 15)
	
	var demo_block := PrimitiveFactory.spawn_primitive(PrimitiveFactory.PrimitiveType.BLOCK, workspace, Vector3(0, 1, 0))
	demo_block.name = "InteractiveBlock"
	demo_block.set_meta("luau_script", "print('Executing Luau Script on InteractiveBlock!')\nrotate_y(30)")
	
	if hierarchy_dock.has_method("refresh_tree"):
		hierarchy_dock.refresh_tree()

func _spawn_part(type: PrimitiveFactory.PrimitiveType) -> void:
	var spawn_pos := Vector3(randf_range(-3, 3), 2.0, randf_range(-3, 3))
	var new_part := PrimitiveFactory.spawn_primitive(type, workspace, spawn_pos)
	
	if hierarchy_dock.has_method("refresh_tree"):
		hierarchy_dock.refresh_tree()
		
	selection_gizmo.set_selected_part(new_part)
	status_banner.text = "Spawned " + new_part.name

func _on_selection_changed(part: Node3D) -> void:
	if inspector_dock.has_method("inspect_node"):
		inspector_dock.inspect_node(part)
	if script_editor_dock.has_method("attach_to_node"):
		script_editor_dock.attach_to_node(part)
	if hierarchy_dock.has_method("select_node_in_tree") and part:
		hierarchy_dock.select_node_in_tree(part)

func _on_hierarchy_node_selected(node: Node3D) -> void:
	selection_gizmo.set_selected_part(node)

func _on_sim_play() -> void:
	if not is_simulating:
		pre_sim_snapshot = PlaceSerializer.serialize_workspace(workspace)
		is_simulating = true

		# Un-freeze non-anchored physics parts
		for child in workspace.get_children():
			if child is RigidBody3D:
				var is_anchored: bool = child.get_meta("anchored", true)
				child.freeze = is_anchored

				# Execute attached Luau scripts
				var script_code: String = child.get_meta("luau_script", "")
				if script_code != "":
					var luau_mgr := get_node_or_null("/root/LuauManager")
					if luau_mgr:
						luau_mgr.execute_luau_script(script_code, child)

		status_banner.text = "Simulation PLAYING..."
	get_tree().paused = false

func _on_sim_pause() -> void:
	get_tree().paused = true
	status_banner.text = "Simulation PAUSED."

func _on_sim_stop() -> void:
	get_tree().paused = false
	if is_simulating:
		is_simulating = false
		if pre_sim_snapshot.size() > 0:
			PlaceSerializer.deserialize_workspace(pre_sim_snapshot, workspace)
			if hierarchy_dock.has_method("refresh_tree"):
				hierarchy_dock.refresh_tree()
		status_banner.text = "Simulation STOPPED. Workspace restored."

func _on_save_local() -> void:
	var place_dict := PlaceSerializer.serialize_workspace(workspace, "Luani Local Place")
	var json_str := JSON.stringify(place_dict, "  ")
	var file := FileAccess.open("user://place_local.luani", FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		status_banner.text = "Saved place to user://place_local.luani"

func _on_publish_click() -> void:
	status_banner.text = "Publishing place to luani.fyi backend..."
	var place_dict := PlaceSerializer.serialize_workspace(workspace, "Luani Studio Creation")
	
	var publisher := PlaceSerializer.new()
	add_child(publisher)
	publisher.publish_completed.connect(func(success, msg):
		if success:
			status_banner.text = "Published successfully to luani.fyi!"
		else:
			status_banner.text = "Publishing error: " + msg
	)
	publisher.publish_place_to_backend(place_dict)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selection_gizmo.handle_viewport_click(event.position, get_viewport())
