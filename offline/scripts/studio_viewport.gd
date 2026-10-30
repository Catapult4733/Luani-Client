extends SubViewportContainer
signal selected(id: String)
signal transformed(id: String, property: String, value: Array)
const Runtime = preload("res://scripts/studio_runtime.gd")
const Data = preload("res://scripts/studio_data.gd")
var viewport: SubViewport
var runtime: Runtime
var camera: Camera3D
var mode: String = "select"
var selected_id: String = ""
var snap: bool = true
var _target: Vector3 = Vector3.ZERO
var _yaw: float = 0.65
var _pitch: float = -0.55
var _distance: float = 38
var _orbit: bool = false
var _pan: bool = false
var _gizmo: Node3D
var _gizmo_length: float = 4
var _axis: int = -1
var _start_mouse: Vector2
var _start_value: Array = []
var _pending_value: Array = []
var _start_world: Vector3
var _pending_pick: Variant = null
var _document: Dictionary = {}

func _ready() -> void:
	stretch = true; mouse_filter = Control.MOUSE_FILTER_STOP; focus_mode = Control.FOCUS_ALL
	viewport = SubViewport.new(); viewport.own_world_3d = true; viewport.handle_input_locally = false; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(viewport)
	runtime = Runtime.new(); viewport.add_child(runtime)
	camera = Camera3D.new(); camera.current = true; camera.fov = 55; camera.far = 20000; viewport.add_child(camera)
	_gizmo = Node3D.new(); viewport.add_child(_gizmo)
	var grid := MeshInstance3D.new(); var lines := ImmediateMesh.new(); lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for step: int in range(-15,16):
		lines.surface_add_vertex(Vector3(step*4,0.015,-60)); lines.surface_add_vertex(Vector3(step*4,0.015,60))
		lines.surface_add_vertex(Vector3(-60,0.015,step*4)); lines.surface_add_vertex(Vector3(60,0.015,step*4))
	lines.surface_end(); grid.mesh = lines
	var material := StandardMaterial3D.new(); material.albedo_color = Color("8c98ad"); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; grid.material_override = material; viewport.add_child(grid)
	gui_input.connect(_input_viewport); _camera()

func set_document(document: Dictionary, id: String) -> void:
	_document = document.duplicate(true); selected_id = id
	runtime.build(document); runtime.environment(); _draw_gizmo()

func set_selection(id: String) -> void:
	selected_id = id; _draw_gizmo()

func set_mode(value: String) -> void:
	mode = value; _axis = -1; _draw_gizmo()

func frame_selected() -> void:
	if runtime.nodes.has(selected_id): _target = (runtime.nodes[selected_id] as Node3D).global_position
	else: _target = Vector3.ZERO
	_distance = 18; _camera()

func _camera() -> void:
	if camera == null: return
	camera.position = _target + Vector3(sin(_yaw)*cos(_pitch),-sin(_pitch),cos(_yaw)*cos(_pitch)) * _distance
	camera.look_at(_target)
	_draw_gizmo()

func _draw_gizmo() -> void:
	if _gizmo == null: return
	for child: Node in _gizmo.get_children(): _gizmo.remove_child(child); child.queue_free()
	if not runtime.nodes.has(selected_id) or mode == "select": return
	var node: Node3D = runtime.nodes[selected_id]
	var item: Dictionary = Data.by_id(_document,selected_id)
	if not item.properties.has("position") or mode == "scale" and not item.properties.has("size"): return
	_gizmo.global_transform = Transform3D(node.global_basis.orthonormalized(),node.global_position)
	_gizmo_length = clampf(camera.global_position.distance_to(node.global_position)*0.14,1.5,24)
	for axis: int in range(3):
		if mode == "rotate":
			var ring := MeshInstance3D.new(); var circle := ImmediateMesh.new(); circle.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for step: int in range(65): circle.surface_add_vertex(_ring_point(axis,float(step)*TAU/64))
			circle.surface_end(); ring.mesh = circle
			var ink := StandardMaterial3D.new(); ink.albedo_color = [Color("f16c6c"),Color("75d493"),Color("6aabff")][axis]; ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; ink.no_depth_test = true; ring.material_override = ink; _gizmo.add_child(ring)
			continue
		var visual := MeshInstance3D.new(); var mesh := BoxMesh.new(); var dimensions := Vector3.ONE * (_gizmo_length * 0.025); dimensions[axis] = _gizmo_length
		mesh.size = dimensions; visual.mesh = mesh; visual.position[axis] = _gizmo_length * 0.5
		var material := StandardMaterial3D.new(); material.albedo_color = [Color("f16c6c"),Color("75d493"),Color("6aabff")][axis]; material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.no_depth_test = true; visual.material_override = material; _gizmo.add_child(visual)
		var tip := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size = Vector3.ONE * _gizmo_length * 0.09; tip.mesh = cube; tip.position[axis] = _gizmo_length; tip.material_override = material; _gizmo.add_child(tip)

func _axis_screen(axis: int) -> Vector2:
	var direction: Vector3 = _gizmo.global_basis[axis].normalized()
	return camera.unproject_position(_gizmo.global_position+direction*_gizmo_length)-camera.unproject_position(_gizmo.global_position)

func _ring_point(axis: int, angle: float) -> Vector3:
	var point := Vector3.ZERO; point[(axis+1)%3] = cos(angle)*_gizmo_length; point[(axis+2)%3] = sin(angle)*_gizmo_length
	return point

func _input_viewport(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed: grab_focus()
		if event.button_index == MOUSE_BUTTON_RIGHT: _orbit = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE: _pan = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance*(0.87 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.15),2,8000); _camera()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_axis = _pick_axis(event.position)
				if _axis >= 0:
					var item: Dictionary = Data.by_id(_document,selected_id)
					var key: String = "position" if mode == "move" else "rotation" if mode == "rotate" else "size"
					_start_value = item.properties[key].duplicate(); _pending_value = _start_value.duplicate(); _start_mouse = event.position; _start_world = (runtime.nodes[selected_id] as Node3D).global_position
				else: _pending_pick = event.position
			elif _axis >= 0:
				var key: String = "position" if mode == "move" else "rotation" if mode == "rotate" else "size"
				_axis = -1; transformed.emit(selected_id,key,_pending_value)
	elif event is InputEventMouseMotion:
		if _orbit: _yaw -= event.relative.x*0.006; _pitch = clampf(_pitch-event.relative.y*0.006,-1.5,1.3); _camera()
		elif _pan: _target += (-camera.global_basis.x*event.relative.x+camera.global_basis.y*event.relative.y)*_distance*0.0015; _camera()
		elif _axis >= 0: _drag(event.position)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F: frame_selected()

func _pick_axis(point: Vector2) -> int:
	if not _gizmo.visible or _gizmo.get_child_count() == 0: return -1
	var start: Vector2 = camera.unproject_position(_gizmo.global_position)
	var best: int = -1; var distance: float = 15
	for axis: int in range(3):
		if mode == "rotate":
			for step: int in range(64):
				var a: Vector2 = camera.unproject_position(_gizmo.to_global(_ring_point(axis,float(step)*TAU/64)))
				var b: Vector2 = camera.unproject_position(_gizmo.to_global(_ring_point(axis,float(step+1)*TAU/64)))
				var hit: Vector2 = Geometry2D.get_closest_point_to_segment(point,a,b)
				if point.distance_to(hit)<distance: best = axis; distance = point.distance_to(hit)
			continue
		var end: Vector2 = start+_axis_screen(axis)
		var hit: Vector2 = Geometry2D.get_closest_point_to_segment(point,start.lerp(end,0.2),end)
		if point.distance_to(hit)<distance: best = axis; distance = point.distance_to(hit)
	return best

func _drag(point: Vector2) -> void:
	var node: Node3D = runtime.nodes[selected_id]
	var delta: Vector2 = point-_start_mouse
	var axis_screen: Vector2 = _axis_screen(_axis)
	var amount: float = delta.dot(axis_screen.normalized())/maxf(axis_screen.length(),1)*_gizmo_length
	_pending_value = _start_value.duplicate()
	if mode == "move":
		if snap: amount = snappedf(amount,0.25)
		var global_point: Vector3 = _start_world+_gizmo.global_basis[_axis].normalized()*amount
		var local: Vector3 = (node.get_parent() as Node3D).to_local(global_point)
		_pending_value = [snappedf(local.x,0.001),snappedf(local.y,0.001),snappedf(local.z,0.001)]
		node.position = local
	elif mode == "rotate":
		var center: Vector2 = camera.unproject_position(_gizmo.global_position)
		var angle: float = rad_to_deg((point-center).angle()-(_start_mouse-center).angle())
		if _gizmo.global_basis[_axis].dot(camera.global_position-_gizmo.global_position)<0: angle = -angle
		if snap: angle = snappedf(angle,15)
		_pending_value[_axis] = wrapf(float(_start_value[_axis])+angle,-180,180)
		node.rotation_degrees = Data.vector(_pending_value)
	elif mode == "scale":
		if snap: amount = snappedf(amount,0.25)
		_pending_value[_axis] = clampf(float(_start_value[_axis])+amount,0.1,512)
		var preview: Dictionary = _document.duplicate(true); Data.by_id(preview,selected_id).properties.size = _pending_value
		runtime.build(preview); runtime.environment()
	# Keep the original drag origin fixed so movement does not compound per event.

func _physics_process(_delta: float) -> void:
	if _pending_pick == null or camera == null: return
	var point: Vector2 = _pending_pick; _pending_pick = null
	var start: Vector3 = camera.project_ray_origin(point)
	var end: Vector3 = start+camera.project_ray_normal(point)*20000
	var query := PhysicsRayQueryParameters3D.create(start,end,4)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	selected.emit(str(hit.collider.get_meta("studio_id","")) if not hit.is_empty() else "")
