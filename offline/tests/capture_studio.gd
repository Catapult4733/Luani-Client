extends Node
## Owned virtual-display screenshot; never touches the user's desktop/browser.
const Editor = preload("res://scripts/studio_editor.gd")
var editor: Editor
func _ready() -> void:
	Engine.max_fps = 30
	get_window().size = Vector2i(1440,900)
	editor = Editor.new(); add_child(editor)
	editor.document.insert("Part")
	var id: String = editor.document.selected
	editor.document.edit(id,"position",[6,3,0]); editor.document.edit(id,"size",[7,6,7]); editor.document.edit(id,"color","6b8cc9")
	editor._set_mode("move")
	_capture.call_deferred()
func _capture() -> void:
	for index: int in range(8): await get_tree().process_frame
	var id: String = editor.document.selected
	var gizmo: Node3D = editor.view._gizmo
	var camera: Camera3D = editor.view.camera
	var start: Vector2 = camera.unproject_position(gizmo.global_position+gizmo.global_basis.x*editor.view._gizmo_length*0.8)
	var end: Vector2 = start+editor.view._axis_screen(0).normalized()*40
	var before: float = float(editor.document.world.objects.back().properties.position[0])
	await _drag(start,end)
	if float(editor.document.world.objects.back().properties.position[0]) == before: push_error("Native pointer gizmo did not move the selected Part"); get_tree().quit(1); return
	print("Native pointer move gizmo changed Part X")
	await RenderingServer.frame_post_draw
	var target: String = "/home/username/.local/share/luani-build/studio-v1-smoke/studio-desktop.png"
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(target) != OK: push_error("Studio screenshot unavailable"); get_tree().quit(1); return
	print("Studio rendered screenshot: ",target)
	print(JSON.stringify({"viewport":editor.view.size,"explorer":editor.explorer.size,"property_controls":editor.properties.get_child_count(),"renderer":RenderingServer.get_current_rendering_method()}))
	editor._set_mode("rotate")
	await get_tree().process_frame
	var pick: Vector2 = Vector2.ZERO
	var angle: float = 0
	for step: int in range(1,30):
		angle = float(step)*0.2
		pick = camera.unproject_position(gizmo.to_global(editor.view._ring_point(1,angle)))
		if editor.view._pick_axis(pick) == 1: break
	var finish: Vector2 = camera.unproject_position(gizmo.to_global(editor.view._ring_point(1,angle+0.6)))
	await _drag(pick,finish)
	if is_zero_approx(float(editor.document.world.objects.back().properties.rotation[1])): push_error("Native pointer rotation gizmo did not rotate the Part"); get_tree().quit(1); return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(target.replace("studio-desktop","studio-rotate"))
	print("Native pointer rotation gizmo changed Part Y rotation")
	get_tree().quit(0)

func _drag(start: Vector2, finish: Vector2) -> void:
	var offset: Vector2 = editor.view.global_position
	var down := InputEventMouseButton.new(); down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = offset+start; down.global_position = down.position; Input.parse_input_event(down)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new(); motion.position = offset+finish; motion.global_position = motion.position; motion.relative = finish-start; motion.button_mask = MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(motion)
	await get_tree().process_frame
	var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = offset+finish; up.global_position = up.position; Input.parse_input_event(up)
	await get_tree().process_frame
