extends Node
## Isolated engine contract. Synthetic profile, real local ENet/DTLS; no cloud calls.
const Data = preload("res://scripts/studio_data.gd")
const Document = preload("res://scripts/studio_document.gd")
const Editor = preload("res://scripts/studio_editor.gd")
const LocalServer = preload("res://scripts/studio_local_server.gd")
const Network = preload("res://scripts/network_client.gd")
var _entered: bool = false
var _lost: String = ""
var _last_pose: Array = []
var root: Window

func _ready() -> void:
	Engine.max_fps = 60
	root = get_tree().root
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition: push_error(message); get_tree().quit(1)

func _run() -> void:
	_check(Data.validate(Data.new_world()).is_empty(),"New world validation failed")
	var doc := Document.new()
	_check(doc.insert("Part").is_empty(),"Part insertion failed")
	var added: String = doc.selected
	_check(doc.edit(added,"color","123456").is_empty(),"Property edit failed")
	doc.undo(); _check(Data.by_id(doc.world,added).properties.color != "123456","Undo failed")
	doc.redo(); _check(Data.by_id(doc.world,added).properties.color == "123456","Redo failed")
	_check(doc.insert("Weld").is_empty(),"Weld creation failed")
	var editor := Editor.new(); root.add_child(editor)
	await get_tree().process_frame
	_check(editor.view.camera != null and editor.explorer.get_root() != null,"Studio viewport/Explorer failed")
	editor.document.select("spawn"); await get_tree().process_frame
	_check(editor.properties.get_child_count() > 3,"Studio Properties failed")
	var name_field: LineEdit = editor.properties.get_child(1)
	name_field.text = "Named fixture spawn"; name_field.text_changed.emit(name_field.text)
	_check(Data.by_id(editor.document.world,"spawn").name == name_field.text and editor.properties.get_child(1) == name_field,"Properties rename failed or discarded the focused field")
	_check(str(editor.explorer.get_selected().get_metadata(0)) == "spawn","Viewport/Explorer selection diverged")
	var file_path: String = ProjectSettings.globalize_path("user://studio-fixture.luani.json")
	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
	var saved_document: Dictionary = editor.document.world.duplicate(true)
	editor._write_file(file_path)
	editor.document.edit("baseplate","color","ff0000")
	editor._read_file(file_path)
	_check(Data.equivalent(editor.document.world,saved_document) and editor.game_id.is_empty(),"Local file roundtrip failed or trusted a cloud identity")
	DirAccess.remove_absolute(file_path)
	editor.queue_free(); await get_tree().process_frame
	var server := LocalServer.new(); server.world_document = Data.new_world(); server.profile = {"public_id":77,"username":"Studio engine fixture","avatar":{}}
	var first: Dictionary = Data.make_instance("Part","weld-a"); first.properties.position = [8,4,0]; first.properties.anchored = false
	var second: Dictionary = Data.make_instance("Part","weld-b"); second.properties.position = [12,4,0]; second.properties.anchored = false
	var weld: Dictionary = Data.make_instance("Weld","weld"); weld.properties.part0 = "weld-a"; weld.properties.part1 = "weld-b"
	server.world_document.objects.append_array([first,second,weld])
	root.add_child(server)
	_check(server.start() == OK,"Local ephemeral DTLS server failed")
	_check(server.runtime.bodies["weld-a"] == server.runtime.bodies["weld-b"] and server.runtime.bodies["weld-a"] is RigidBody3D,"Weld did not create one rigid physics assembly")
	_check(int(server.endpoint.port) >= 1024 and server.endpoint.host == "127.0.0.1","Local listener escaped loopback")
	var network := Network.new(); root.add_child(network)
	network.entered.connect(func() -> void: _entered = true)
	network.lost.connect(func(message: String) -> void: _lost = message)
	network.poses_received.connect(func(poses: Array) -> void: _last_pose = poses[0] if not poses.is_empty() else [])
	network.start(server.launch_data())
	for tick: int in range(300):
		await get_tree().physics_frame
		if _entered or not _lost.is_empty(): break
	_check(_entered and _lost.is_empty(),"Local admission failed: " + _lost)
	print("Studio local admission verified")
	_check(not root.get_node("SessionState").online,"Local playtest became a production account session")
	for tick: int in range(90):
		network.send_input(Vector3.RIGHT,0,false,false)
		await get_tree().physics_frame
	_check(_last_pose.size() == 14 and float(_last_pose[1]) > 1,"Local server did not authoritatively simulate movement")
	_check(_lost.is_empty(),"Local connection ended during simulation: " + _lost)
	print("Studio local movement verified; closing task-owned peers")
	network.leave(); await get_tree().create_timer(0.2).timeout
	network.queue_free(); server.queue_free(); await get_tree().process_frame
	print("Studio document/editor/local-loopback-DTLS authority contracts passed; synthetic identity, no cloud verification")
	get_tree().quit(0)
