extends Node
## First-party server. Multiple bounded, isolated logical instances share one UDP relay.
const Transport = preload("res://scripts/secure_transport.gd")
const Bag = preload("res://scripts/inventory.gd")
const Catalog = preload("res://scripts/item_catalog.gd")
const Facing = preload("res://scripts/facing.gd")
const AvatarSync = preload("res://scripts/avatar_sync.gd")
const AvatarData = preload("res://scripts/avatar_data.gd")
const SCATTER = [
 ["sword",4,-5],["lantern",-5,-4],["spring_coil",2,6],
 ["sword",14,-13],["lantern",-17,8],["spring_coil",15,15],
 ["sword",-25,-19],["lantern",27,-8],["spring_coil",-22,26],
 ["sword",33,29],["lantern",-37,-31],["spring_coil",7,-39],
 ["sword",-48,10],["lantern",45,-34],["spring_coil",39,48],
 ["sword",58,12],["lantern",-12,55],["spring_coil",-54,-46]
]
const TARGETS = [Vector2(4,-10),Vector2(-9,-9),Vector2(12,4),Vector2(-14,7),Vector2(0,20)]
var _transport: Transport
var _peers: Dictionary = {}
var _rooms: Dictionary = {}
var _leaving: Array[Dictionary] = []
var _actions: Array[Dictionary] = []
var _boot: String = ""
var _api: String = ""
var _key: String = ""
var _last_ok: float = 0.0
var _pulse_due: float = 0.0
var _snapshot_due: float = 0.0
var _pulsing := false

func _ready() -> void:
	Engine.max_fps = 60
	_api = OS.get_environment("LUANI_API_URL")
	_key = OS.get_environment("LUANI_CONTROL_KEY")
	if _api != "https://ffghvwuuqmvzvjuiynkn.supabase.co/functions/v1/luani-play" or _key.length() != 43:
		push_error("Server configuration unavailable."); get_tree().quit(1); return

	var key := CryptoKey.new()
	var certificate := X509Certificate.new()
	if key.load(OS.get_environment("LUANI_TLS_KEY")) != OK or certificate.load(OS.get_environment("LUANI_TLS_CERT")) != OK:
		push_error("Server TLS material unavailable."); get_tree().quit(1); return
	_transport = Transport.new()
	add_child(_transport)
	_transport.peer_joined.connect(_peer_joined)
	_transport.peer_left.connect(_peer_left)
	_transport.message_received.connect(_receive)
	_transport.failed.connect(func(_message: String) -> void: get_tree().quit(1))
	if _transport.start_server(19070, key, certificate) != OK:
		push_error("Secure UDP listener could not start."); get_tree().quit(1); return
	print("Luani production server listening on loopback UDP19070 with DTLS; capacity12 per instance, max4 instances.")
	_start_control()

func _start_control() -> void:
	var answer: Dictionary = await _control({"action":"boot"})
	_boot = str(answer.get("boot_id", ""))
	if _boot.length() != 36:
		push_error("Server control startup unavailable."); get_tree().quit(1); return
	_pulse()

func _clock() -> float:
	return Time.get_ticks_msec() * 0.001

func _peer_joined(id: int) -> void:
	_peers[id] = {"deadline":_clock()+8.0,"phase":"pending","rate_at":_clock(),"rate":0}

func _peer_left(id: int) -> void:
	if not _peers.has(id): return
	var member: Dictionary = _peers[id]
	_peers.erase(id)
	if member.has("admission_id"):
		_leaving.append({"admission_id":member.admission_id,"data":_bag_data(member.bag),"leaving":true})
		var room: String = member.room
		(member.body as CharacterBody3D).queue_free()
		_broadcast_state(room)

func _receive(id: int, message: Dictionary) -> void:
	if not _peers.has(id): return
	var member: Dictionary = _peers[id]
	if _clock()-float(member.rate_at) > 1.0: member.rate_at=_clock(); member.rate=0
	member.rate = int(member.rate)+1
	if int(member.rate)>90: _transport.disconnect_peer(id); return
	if member.phase == "pending":
		if message.get("type") != "auth" or message.size()!=3 or message.get("protocol") != 1 or not message.get("admission") is String or str(message.admission).length()!=43:
			_transport.disconnect_peer(id); return
		member.phase = "verifying"
		_authorize(id, str(message.admission))
		return
	if member.phase != "admitted": return
	if _clock()-_last_ok > 20.0: _transport.disconnect_peer(id); return
	if message.get("type") == "leave":
		_transport.disconnect_peer(id)
		if not _pulsing: _pulse()
		return
	if message.get("type") == "input":
		var move: Variant = message.get("move")
		if not move is Array or move.size()!=2 or not _number(move[0]) or not _number(move[1]) or not _number(message.get("yaw")) or not _number(message.get("seq")):
			_transport.disconnect_peer(id); return
		var sequence := int(message.seq)
		if sequence<=int(member.seq) or sequence>int(member.seq)+1000: return
		member.seq=sequence
		member.move=Vector2(float(move[0]),float(move[1])).limit_length(1.0)
		member.yaw=wrapf(float(message.yaw),-PI,PI)
		if message.has("look_locked") and not message.look_locked is bool:
			_transport.disconnect_peer(id); return
		# Legacy clients did not transmit mode: keep their original aim-facing contract.
		member.look_locked=message.get("look_locked", true)==true
		member.sprint=message.get("sprint")==true
		member.jump=member.jump or message.get("jump")==true
		member.input_at=_clock()
	elif message.get("type") == "action" and _actions.size()<128:
		_actions.append({"peer":id,"message":message})

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value))<10000000.0

func _authorize(id: int, admission: String) -> void:
	var data: Dictionary = await _control({"action":"admit","boot_id":_boot,"admission":admission})
	if data.is_empty() or not data.has("profile") or not data.has("datastore"):
		_transport.disconnect_peer(id); return
	if not _peers.has(id):
		_leaving.append({"admission_id":data.admission_id,"data":data.datastore,"leaving":true})
		return
	var room := str(data.instance_id)
	if not _rooms.has(room):
		if _rooms.size()>=4: _transport.disconnect_peer(id); return
		_make_room(room)
	var population := 0
	for other in _peers.values():
		if other.get("room")==room: population+=1
	if population>=12: _transport.disconnect_peer(id); return
	var bag := Bag.new()
	bag.apply_server(data.datastore)
	var body := CharacterBody3D.new()
	body.collision_layer=2; body.collision_mask=1; body.floor_snap_length=0.25
	var capsule := CapsuleShape3D.new(); capsule.radius=0.46; capsule.height=3.04
	var collision := CollisionShape3D.new(); collision.shape=capsule; collision.position.y=1.53
	body.add_child(collision)
	add_child(body)
	body.global_position=_rooms[room].origin+Vector3(population*2,0.2,0)
	var member: Dictionary = _peers[id]
	member.merge({"phase":"admitted","room":room,"admission_id":str(data.admission_id),"profile":data.profile,"body":body,"bag":bag,"seq":0,"move":Vector2.ZERO,"yaw":0.0,"facing":0.0,"look_locked":false,"sprint":false,"jump":false,"input_at":_clock(),"use_at":0.0,"action_at":0.0,"lantern":true,"swing":0},true)
	_transport.send_message(id,{"type":"welcome","player_key":str(data.profile.public_id),"profile":data.profile,"instance_id":room,"inventory":_bag_data(bag)})
	_broadcast_state(room)

func _make_room(id: String) -> void:
	var slot := 0
	for candidate in range(4):
		var taken := false
		for existing in _rooms.values():
			if int(existing.slot) == candidate: taken = true
		if not taken: slot = candidate; break
	var origin := Vector3(float(slot)*1024.0,0,0)
	var room_root := Node3D.new(); add_child(room_root)
	var room := {"origin":origin,"root":room_root,"slot":slot,"last_used":_clock(),"pickups":{},"targets":[],"next_pickup":19}
	for i in range(SCATTER.size()):
		var entry: Array = SCATTER[i]
		room.pickups[str(i+1)]={"item":entry[0],"point":Vector3(float(entry[1]),0,float(entry[2])),"ready":0.0}
	var floor_body := StaticBody3D.new(); floor_body.collision_layer=1; floor_body.collision_mask=2
	floor_body.position=origin+Vector3(0,-0.5,0)
	var shape := BoxShape3D.new(); shape.size=Vector3(240,1,240)
	var collision := CollisionShape3D.new(); collision.shape=shape
	floor_body.add_child(collision); room_root.add_child(floor_body)
	for point in TARGETS:
		var prop := StaticBody3D.new(); prop.position=origin+Vector3(point.x,1.05,point.y); prop.collision_layer=1; prop.collision_mask=2
		var prop_shape := BoxShape3D.new(); prop_shape.size=Vector3(1.05,2.10,0.65)
		var prop_collision := CollisionShape3D.new(); prop_collision.shape=prop_shape; prop.add_child(prop_collision); room_root.add_child(prop)
		room.targets.append({"point":Vector3(point.x,0,point.y),"hits":3,"reset":0.0,"body":prop})
	_rooms[id]=room

func _physics_process(delta: float) -> void:
	if _transport==null or _boot.is_empty(): return
	var now := _clock()
	for id: int in _peers.keys():
		var member: Dictionary = _peers[id]
		if member.phase != "admitted":
			if now>float(member.deadline): _transport.disconnect_peer(id)
			continue
		if now-_last_ok>20.0: _transport.disconnect_peer(id); continue
		var body := member.body as CharacterBody3D
		var bag: Bag = member.bag
		var movement: Vector2 = member.move if now-float(member.input_at)<0.35 else Vector2.ZERO
		if not body.is_on_floor(): body.velocity.y-=25.0*delta
		if body.is_on_floor() and member.jump:
			body.velocity.y=13.5 if bag.equipped_id()=="spring_coil" else 9.0
		member.jump=false
		var speed := 12.0 if member.sprint else 7.0
		var acceleration := 38.0 if movement.is_zero_approx() else 28.0
		body.velocity.x=move_toward(body.velocity.x,movement.x*speed,acceleration*delta)
		body.velocity.z=move_toward(body.velocity.z,movement.y*speed,acceleration*delta)
		body.move_and_slide()
		var face_target := Facing.target(movement, float(member.yaw), bool(member.look_locked), float(member.facing))
		member.facing=lerp_angle(float(member.facing), face_target, minf(delta*Facing.rate(bool(member.look_locked)),1.0))
		if body.position.y< -35.0: body.position=_rooms[member.room].origin+Vector3(0,0.2,0); body.velocity=Vector3.ZERO
	for action in _actions:
		if _peers.has(action.peer): _action(int(action.peer),action.message)
	_actions.clear()
	for room_id: String in _rooms.keys():
		var changed := false
		var occupied := false
		for member in _peers.values():
			if member.get("room") == room_id: occupied = true
		if occupied: _rooms[room_id].last_used = now
		elif now - float(_rooms[room_id].last_used) > 90.0:
			_rooms[room_id].root.queue_free(); _rooms.erase(room_id); continue
		for target in _rooms[room_id].targets:
			if int(target.hits)==0 and now>=float(target.reset):
				target.hits=3; target.body.collision_layer=1; changed=true
		if changed: _broadcast_state(room_id)
	_snapshot_due-=delta; _pulse_due-=delta
	if _snapshot_due<=0: _snapshot_due=0.05; _broadcast_snapshots()
	if _pulse_due<=0 and not _pulsing:
		var active := false
		for member in _peers.values():
			if member.get("phase") == "admitted": active = true
		_pulse_due = 5.0 if active else 10.0
		_pulse()

func _action(id: int, message: Dictionary) -> void:
	var member: Dictionary = _peers[id]
	var now := _clock()
	if member.phase!="admitted" or now-float(member.action_at)<0.12: return
	member.action_at=now
	var room: Dictionary = _rooms[member.room]
	var body := member.body as CharacterBody3D
	var point: Vector3 = body.global_position-room.origin
	var bag: Bag = member.bag
	match str(message.get("action","")):
		"pickup":
			var pickup_id := str(message.get("pickup_id",""))
			if not room.pickups.has(pickup_id): return
			var pickup: Dictionary = room.pickups[pickup_id]
			if now<float(pickup.ready) or point.distance_to(pickup.point)>3.3 or not _clear(body,pickup.point+room.origin+Vector3.UP): return
			var empty := bag.occupied_count()==0
			if not bag.add_item(str(pickup.item)): _status(id,"Inventory full."); return
			room.pickups.erase(pickup_id)
			if empty: bag.equip(0)
		"equip":
			if not _number(message.get("slot")): return
			if not bag.equip(int(message.slot)): return
			member.lantern=true
		"drop":
			if not _number(message.get("slot")) or room.pickups.size()>=96: return
			var item: Dictionary = bag.remove_slot(int(message.slot))
			if item.is_empty(): return
			var forward := Vector3.FORWARD.rotated(Vector3.UP,float(member.yaw))
			var dropped := point+forward*2.2
			dropped=Vector3(clampf(dropped.x,-112,112),0,clampf(dropped.z,-112,112))
			var pickup_id := str(room.next_pickup); room.next_pickup=int(room.next_pickup)+1
			room.pickups[pickup_id]={"item":str(item.id),"point":dropped,"ready":now+0.8}
		"respawn":
			body.position=room.origin+Vector3(0,0.2,0); body.velocity=Vector3.ZERO
		"use":
			if now<float(member.use_at): return
			if bag.equipped_id()=="sword":
				member.use_at=now+0.45; member.swing=int(member.swing)+1
				member.facing=member.yaw
				var forward := Vector3.FORWARD.rotated(Vector3.UP,float(member.yaw))
				for target in room.targets:
					var offset: Vector3 = target.point-point
					var flat := Vector3(offset.x,0,offset.z)
					if int(target.hits)>0 and flat.length()<=3.4 and absf(offset.y)<2.5 and (flat.is_zero_approx() or forward.dot(flat.normalized())>0.25):
						var target_body := target.body as StaticBody3D
						if _clear(body,target.point+room.origin+Vector3.UP*1.4,[target_body.get_rid()]):
							target.hits=int(target.hits)-1; target.reset=now+5.0
							if int(target.hits) == 0: target.body.collision_layer = 0
			elif bag.equipped_id()=="lantern": member.use_at=now+0.25; member.lantern=not member.lantern
			else: return
		_: return
	_transport.send_message(id,{"type":"inventory","data":_bag_data(bag)})
	_broadcast_state(str(member.room))

func _clear(body: CharacterBody3D, point: Vector3, extra: Array[RID] = []) -> bool:
	var excluded: Array[RID] = [body.get_rid()]; excluded.append_array(extra)
	var query := PhysicsRayQueryParameters3D.create(body.global_position+Vector3.UP*1.4,point,1,excluded)
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _status(id: int, text: String) -> void:
	_transport.send_message(id,{"type":"status","message":text})

func _bag_data(bag: Bag) -> Dictionary:
	var slots: Array[String] = []
	for i in range(bag.CAPACITY): slots.append(str(bag.get_slot(i).get("id","")))
	return {"slots":slots,"equipped":bag.equipped_slot}

func _broadcast_state(room_id: String) -> void:
	if not _rooms.has(room_id): return
	var room: Dictionary = _rooms[room_id]
	var roster: Array[Dictionary] = []
	for member in _peers.values():
		if member.get("room")==room_id: roster.append({"key":str(member.profile.public_id),"username":str(member.profile.username),"avatar":member.profile.avatar})
	var pickups: Array = []
	for id in room.pickups:
		var p: Dictionary = room.pickups[id]
		pickups.append([id,p.item,p.point.x,p.point.z])
	var hits: Array[int] = []
	for target in room.targets: hits.append(int(target.hits))
	_broadcast(room_id,{"type":"world","players":roster,"pickups":pickups,"targets":hits})

func _broadcast_snapshots() -> void:
	for room_id: String in _rooms:
		var poses: Array = []
		for member in _peers.values():
			if member.get("room")!=room_id: continue
			var body := member.body as CharacterBody3D
			var p: Vector3 = body.global_position-_rooms[room_id].origin
			poses.append([str(member.profile.public_id),snappedf(p.x,0.001),snappedf(p.y,0.001),snappedf(p.z,0.001),body.velocity.x,body.velocity.y,body.velocity.z,member.facing,body.is_on_floor(),member.sprint,member.bag.equipped_id(),member.lantern,member.swing,member.seq])
		_broadcast(room_id,{"type":"poses","players":poses},false)

func _broadcast(room_id: String, message: Dictionary, reliable: bool = true) -> void:
	for id: int in _peers:
		if _peers[id].get("room")==room_id: _transport.send_message(id,message,reliable)

func _control(payload: Dictionary) -> Dictionary:
	var request := HTTPRequest.new(); request.timeout=8.0; request.max_redirects=0; request.body_size_limit=65536
	add_child(request)
	var error := request.request(_api,PackedStringArray(["Content-Type: application/json","X-Luani-Host-Key: "+_key]),HTTPClient.METHOD_POST,JSON.stringify(payload))
	if error!=OK: request.queue_free(); return {}
	var result: Array = await request.request_completed
	request.queue_free()
	if int(result[0])!=HTTPRequest.RESULT_SUCCESS or int(result[1])!=200: return {}
	var data: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return data if data is Dictionary else {}

func _pulse() -> void:
	_pulsing=true
	var outgoing: Array[Dictionary] = _leaving.duplicate(true)
	for member in _peers.values():
		if member.get("phase")=="admitted": outgoing.append({"admission_id":member.admission_id,"data":_bag_data(member.bag),"avatar_revision":AvatarData.revision(member.profile.get("avatar",{}))})
	var answer: Dictionary = await _control({"action":"pulse","boot_id":_boot,"players":outgoing,"avatar_updates":true})
	if answer.get("ok")==true:
		if _last_ok == 0.0: print("Luani control heartbeat accepted; host is ready for admissions.")
		_last_ok=_clock()
		for room: String in AvatarSync.apply_updates(_peers,answer.get("avatars",[])): _broadcast_state(room)
		for entry in outgoing:
			if entry.get("leaving")==true: _leaving.erase(entry)
	_pulsing=false
	if not _leaving.is_empty(): _pulse_due=0.0
