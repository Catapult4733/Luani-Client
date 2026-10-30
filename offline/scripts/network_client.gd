extends Node
## HTTPS admission has already been redeemed by the URI handler. DTLS verifies the game host.
signal entered
signal room_changed(data: Dictionary)
signal inventory_received(data: Dictionary)
signal poses_received(players: Array)
signal parts_received(parts: Array)
signal lost(message: String)
signal status(message: String)
const Transport = preload("res://scripts/secure_transport.gd")
var player_key: String = ""
var roster: Array = []
var initial_inventory: Dictionary = {}
var world_data: Dictionary = {}
var _transport: Transport
var _server: int = -1
var _launch: Dictionary = {}
var _deadline: float = 0.0
var _entered := false
var _sequence: int = 0

func start(launch: Dictionary) -> void:
	world_data.clear()
	if launch.get("world") is Dictionary:
		var validation: String = preload("res://scripts/studio_data.gd").validate(launch.world)
		if not validation.is_empty(): _fail("Invalid published game world."); return
		world_data = launch.world.duplicate(true)
	_launch=launch
	_transport=Transport.new(); add_child(_transport)
	_transport.peer_joined.connect(_connected)
	_transport.peer_left.connect(func(_id: int) -> void: _fail("Connection closed. Join again from the website."))
	_transport.message_received.connect(_message)
	_transport.failed.connect(_fail)
	_deadline=Time.get_ticks_msec()*0.001+20.0
	if _transport.start_client(launch.get("endpoint",{}))!=OK: _fail("Could not establish a verified game connection.")

func _connected(id: int) -> void:
	_server=id
	var hello := {"type":"auth","protocol":1,"admission":str(_launch.get("admission",""))}
	if not world_data.is_empty(): hello.studio_worlds = 1
	_transport.send_message(id,hello)
	_launch.erase("admission")

func _message(id: int, message: Dictionary) -> void:
	if id!=_server: return
	match str(message.get("type","")):
		"welcome":
			if _entered or str(message.get("instance_id",""))!=str(_launch.get("instance_id","")): _fail("Unexpected server admission."); return
			var profile: Dictionary = message.get("profile",{})
			if str(profile.get("public_id",""))!=str(_launch.get("profile",{}).get("public_id","")): _fail("Unexpected player identity."); return
			player_key=str(message.get("player_key",""))
			initial_inventory=message.get("inventory",{})
			SessionState.set_identity(profile)
			SessionState.game=_launch.get("game",{})
			SessionState.online=_launch.get("studio_local") != true
			_entered=true; _launch.clear(); entered.emit()
		"world":
			if _entered:
				roster=message.get("players",[])
				for person: Variant in roster:
					if person is Dictionary and str(person.get("key",""))==player_key and person.get("avatar") is Dictionary:
						SessionState.apply_server_avatar(person.avatar)
				room_changed.emit(message)
		"inventory":
			if _entered: inventory_received.emit(message.get("data",{}))
		"poses":
			if _entered:
				poses_received.emit(message.get("players",[]))
				if message.get("parts") is Array: parts_received.emit(message.parts)
		"status": status.emit(str(message.get("message","")).substr(0,200))

func send_input(direction: Vector3, yaw: float, sprint: bool, jump: bool, look_locked: bool = false) -> void:
	if not _entered: return
	_sequence+=1
	_transport.send_message(_server,{"type":"input","seq":_sequence,"move":[direction.x,direction.z],"yaw":yaw,"look_locked":look_locked,"sprint":sprint,"jump":jump},false)

func action(name_text: String, values: Dictionary = {}) -> void:
	if not _entered: return
	var message := {"type":"action","action":name_text}
	message.merge(values)
	_transport.send_message(_server,message)

func rtt() -> float:
	return _transport.rtt(_server) if _transport!=null else 0.0

func leave() -> void:
	if _entered and _transport != null:
		_transport.send_message(_server,{"type":"leave"})
		_transport.flush()
		_transport.close()
		_entered=false

func _process(_delta: float) -> void:
	if not _entered and _deadline>0 and Time.get_ticks_msec()*0.001>_deadline:
		_deadline=0; _fail("Game connection timed out. Join again from the website.")

func _fail(message: String) -> void:
	if _transport!=null: _transport.close()
	SessionState.online=false
	_entered=false; _deadline=0; _launch.clear()
	lost.emit(message)
