extends Node
## A real loopback-only, ephemeral-DTLS local authority. No production keys or writes.
const Transport = preload("res://scripts/secure_transport.gd")
const Runtime = preload("res://scripts/studio_runtime.gd")
const Data = preload("res://scripts/studio_data.gd")
var world_document: Dictionary = {}
var profile: Dictionary = {}
var transport: Transport
var runtime: Runtime
var body: CharacterBody3D
var admission: String = ""
var endpoint: Dictionary = {}
var _peer: int = -1
var _authenticated: bool = false
var _move: Vector2 = Vector2.ZERO
var _jump: bool = false
var _sprint: bool = false
var _yaw: float = 0.0
var _seq: int = 0
var _input_at: float = 0.0
var _snapshot: float = 0.0
var _deadline: float = 0.0
var _rate_at: float = 0.0
var _rate: int = 0

func start() -> Error:
	if not Data.validate(world_document).is_empty(): return ERR_INVALID_DATA
	var isolated := SubViewport.new(); isolated.own_world_3d = true; isolated.size = Vector2i(16,16); isolated.render_target_update_mode = SubViewport.UPDATE_DISABLED; add_child(isolated)
	runtime = Runtime.new(); isolated.add_child(runtime)
	if not runtime.build(world_document,"server").is_empty(): return ERR_INVALID_DATA
	body = CharacterBody3D.new(); body.collision_layer = 2; body.collision_mask = 1; body.floor_snap_length = 0.25
	var shape := CapsuleShape3D.new(); shape.radius = 0.46; shape.height = 3.04
	var collision := CollisionShape3D.new(); collision.shape = shape; collision.position.y = 1.53; body.add_child(collision)
	runtime.add_child(body); body.position = runtime.spawn_position()
	var crypto := Crypto.new(); var key: CryptoKey = crypto.generate_rsa(2048)
	var certificate: X509Certificate = crypto.generate_self_signed_certificate(key,"CN=luani-game,O=Luani Studio,C=ES")
	if key == null or certificate == null: return ERR_CANT_CREATE
	transport = Transport.new(); add_child(transport)
	transport.peer_joined.connect(_joined); transport.peer_left.connect(_left); transport.message_received.connect(_message)
	var error: Error = transport.start_server(0,key,certificate)
	if error != OK: return error
	admission = Marshalls.raw_to_base64(crypto.generate_random_bytes(32)).replace("+","-").replace("/","_").replace("=","")
	var cert_nonce: String = Marshalls.raw_to_base64(crypto.generate_random_bytes(12)).replace("+","").replace("/","").replace("=","")
	var cert_path := "user://studio_loopback_%d_%s.crt" % [OS.get_process_id(), cert_nonce]
	var cert_global_path := ProjectSettings.globalize_path(cert_path)
	var save_error: Error = certificate.save(cert_path)
	var cert_string := ""
	var read_error: Error = OK
	if save_error == OK:
		cert_string = FileAccess.get_file_as_string(cert_path)
		read_error = FileAccess.get_open_error()
	if FileAccess.file_exists(cert_path):
		DirAccess.remove_absolute(cert_global_path)
	if save_error != OK:
		transport.close()
		return save_error
	if read_error != OK or cert_string.is_empty():
		transport.close()
		return ERR_FILE_CANT_READ if read_error == OK else read_error
	endpoint = {"host":"127.0.0.1","port":transport.local_port(),"certificate":cert_string,"common_name":"luani-game"}
	_deadline = Time.get_ticks_msec() * 0.001 + 20.0
	return OK

func launch_data() -> Dictionary:
	var payload: Dictionary = {"protocol":1,"studio_local":true,"instance_id":"studio-local","profile":profile,"admission":admission,"endpoint":endpoint,"world":world_document,"game":{"id":"studio-local","title":"Studio local playtest","studio_local":true},"datastore":{"slots":["","","","","","","","","","","","","","","","","",""],"equipped":-1}}
	# Match the JSON-decoded HTTPS/UDP representation, including numeric public IDs.
	return JSON.parse_string(JSON.stringify(payload))

func _joined(id: int) -> void:
	if _peer != -1: transport.disconnect_peer(id); return
	_peer = id

func _left(id: int) -> void:
	if id == _peer: _authenticated = false; _peer = -1

func _message(id: int, message: Dictionary) -> void:
	if id != _peer: return
	var now: float = Time.get_ticks_msec() * 0.001
	if now - _rate_at >= 1: _rate_at = now; _rate = 0
	_rate += 1
	if _rate > 90: transport.disconnect_peer(id); return
	if not _authenticated:
		if admission.is_empty() or message.size() != 4 or message.get("studio_worlds") != 1 or message.get("type") != "auth" or message.get("protocol") != 1 or message.get("admission") != admission or now > _deadline:
			transport.disconnect_peer(id); return
		_authenticated = true; admission = ""
		transport.send_message(id,{"type":"welcome","player_key":str(profile.get("public_id","local")),"profile":profile,"instance_id":"studio-local","inventory":{"slots":["","","","","","","","","","","","","","","","","",""],"equipped":-1}})
		transport.send_message(id,{"type":"world","players":[{"key":str(profile.get("public_id","local")),"username":profile.get("username","Creator"),"avatar":profile.get("avatar",{})}],"pickups":[],"targets":[]})
		return
	if message.get("type") == "leave": transport.disconnect_peer(id); return
	if message.get("type") == "action":
		if message.get("action") == "respawn": body.position = runtime.spawn_position(); body.velocity = Vector3.ZERO
		return
	if message.get("type") != "input" or not message.get("move") is Array or message.move.size() != 2: return
	for value: Variant in [message.move[0],message.move[1],message.get("yaw"),message.get("seq")]:
		if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > 10000000: transport.disconnect_peer(id); return
	if int(message.seq) <= _seq or int(message.seq) > _seq + 1000: return
	_seq = int(message.seq); _move = Vector2(float(message.move[0]),float(message.move[1])).limit_length(1)
	_yaw = wrapf(float(message.yaw),-PI,PI); _jump = _jump or message.get("jump") == true; _sprint = message.get("sprint") == true; _input_at = now

func _physics_process(delta: float) -> void:
	if not _authenticated or body == null: return
	var now: float = Time.get_ticks_msec() * 0.001
	var move: Vector2 = _move if now - _input_at < 0.35 else Vector2.ZERO
	if not body.is_on_floor(): body.velocity.y -= 25 * delta
	if body.is_on_floor() and _jump: body.velocity.y = 9
	_jump = false
	var speed: float = 12 if _sprint else 7
	var acceleration: float = 38 if move.is_zero_approx() else 28
	body.velocity.x = move_toward(body.velocity.x,move.x*speed,acceleration*delta)
	body.velocity.z = move_toward(body.velocity.z,move.y*speed,acceleration*delta)
	body.move_and_slide()
	if body.position.y < runtime.kill_height(): body.position = runtime.spawn_position(); body.velocity = Vector3.ZERO
	_snapshot -= delta
	if _snapshot <= 0:
		_snapshot = 1.0/15.0
		var p: Vector3 = body.position
		transport.send_message(_peer,{"type":"poses","players":[[str(profile.get("public_id","local")),p.x,p.y,p.z,body.velocity.x,body.velocity.y,body.velocity.z,_yaw,body.is_on_floor(),_sprint,"",true,0,_seq]],"parts":runtime.dynamic_state()},false)
