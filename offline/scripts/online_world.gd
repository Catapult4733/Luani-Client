extends "res://scripts/world.gd"
## Client-side map/visuals. Server decides movement, claims, items, targets and identity.

const Remote = preload("res://scripts/remote_player.gd")
var connection
var _remotes: Dictionary = {}
var _local_swing: int = 0

func _ready() -> void:
	_build_environment(); _build_baseplate()
	inventory=InventoryScript.new(); inventory.server_owned=true
	player=PlayerScript.new(); player.network_driver=connection; player.name="AuthenticatedPlayer"
	add_child(player)
	inventory.equipped_changed.connect(player.set_equipped_item)
	inventory.equip_requested.connect(func(index: int) -> void: connection.action("equip",{"slot":index}))
	inventory.apply_server(connection.initial_inventory)
	for point: Vector2 in [Vector2(4,-10),Vector2(-9,-9),Vector2(12,4),Vector2(-14,7),Vector2(0,20)]:
		var target := TargetScript.new(); target.position=Vector3(point.x,0,point.y); add_child(target); _targets.append(target)
	connection.room_changed.connect(_room_state)
	connection.inventory_received.connect(inventory.apply_server)
	connection.poses_received.connect(_poses)
	connection.status.connect(func(message: String) -> void: status_changed.emit(message))
	var hud := HudScript.new(); hud.player=player; hud.inventory=inventory; hud.world=self; add_child(hud)

func roster() -> Array:
	return connection.roster

func _room_state(data: Dictionary) -> void:
	var present: Dictionary = {}
	for person in data.get("players",[]):
		var key := str(person.get("key","")); present[key]=true
		if key!=connection.player_key and not _remotes.has(key):
			var remote := Remote.new(); remote.profile=person; add_child(remote); _remotes[key]=remote
	for key in _remotes.keys():
		if not present.has(key): _remotes[key].queue_free(); _remotes.erase(key)
	var wanted: Dictionary = {}
	for entry in data.get("pickups",[]):
		if not entry is Array or entry.size()!=4: continue
		var key := str(entry[0]); wanted[key]=true
		var existing: PickupScript = null
		for pickup in _pickups:
			if pickup.network_id==key: existing=pickup; break
		if existing==null:
			existing=_spawn_pickup(str(entry[1]),Vector3(float(entry[2]),0,float(entry[3])))
			existing.network_id=key
	for pickup in _pickups.duplicate():
		if not wanted.has(pickup.network_id):
			if pickup==_nearest: _nearest=null
			_pickups.erase(pickup); pickup.queue_free()
	var hits: Array = data.get("targets",[])
	for i in range(mini(hits.size(),_targets.size())): _targets[i].apply_server_hits(int(hits[i]))
	roster_changed.emit()

func _poses(poses: Array) -> void:
	for pose in poses:
		if not pose is Array or pose.size()!=14: continue
		var key := str(pose[0])
		if key==connection.player_key:
			var location := Vector3(float(pose[1]),float(pose[2]),float(pose[3]))
			var velocity_value := Vector3(float(pose[4]),float(pose[5]),float(pose[6]))
			player.reconcile(location+velocity_value*minf(connection.rtt()*0.5,0.15),velocity_value)
			player.set_lantern_state(bool(pose[11]))
			if _local_swing!=int(pose[12]): _local_swing=int(pose[12]); player.swing_tool()
		elif _remotes.has(key): _remotes[key].apply_pose(pose)

func _collect_nearest() -> void:
	if is_instance_valid(_nearest): connection.action("pickup",{"pickup_id":_nearest.network_id})

func drop_slot(index: int) -> void:
	if player._window_focused: connection.action("drop",{"slot":index})

func _use_item() -> void:
	connection.action("use")

func leave_game() -> void:
	connection.leave()
	await get_tree().create_timer(0.35).timeout
