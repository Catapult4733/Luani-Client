extends Node
## Isolated unit contracts: no main game scene, networking, credentials or admissions.
const Facing = preload("res://scripts/facing.gd")
const Geometry = preload("res://scripts/touch_geometry.gd")
const Client = preload("res://scripts/network_client.gd")
const Server = preload("res://scripts/dedicated_server.gd")
const Bag = preload("res://scripts/inventory.gd")
const Remote = preload("res://scripts/remote_player.gd")
const Widgets = preload("res://scripts/ui_controls.gd")
class Capture extends "res://scripts/secure_transport.gd":
	var packets: Array = []
	var dropped: Array = []
	func send_message(id: int, message: Dictionary, reliable: bool = true) -> void:
		packets.append({"peer":id,"data":message.duplicate(true),"reliable":reliable})
	func disconnect_peer(id: int) -> void:
		dropped.append(id)
var checks := 0
var failed := false
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failed = true; push_error("CONTRACT FAILED: " + label)
func near(a: float, b: float) -> bool:
	return absf(wrapf(a-b,-PI,PI)) < 0.00001
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	var button := Widgets.HudButton.new()
	check(button._make_custom_tooltip("")==null,"empty custom tooltip cannot display a desktop hint on touch")
	button.free()
	check(near(Facing.target(Vector2.UP,1.2,false,0.5),0),"free forward ignores camera yaw")
	check(near(Facing.target(Vector2.RIGHT,0,false,0),-PI/2),"free strafe faces movement")
	check(near(Facing.target(Vector2.DOWN,0,false,0),PI),"free backward faces backward")
	check(near(Facing.target(Vector2.ZERO,2,false,0.6),0.6),"idle camera orbit preserves body")
	check(near(Facing.target(Vector2.RIGHT,1.1,true,0),1.1),"camera lock preserves aim-facing")
	check(near(Facing.target(Vector2.ZERO,TAU+0.25,true,0),0.25),"wrapped aim")
	var long_drag := Vector2(500,600)
	check(Geometry.stick_offset(long_drag,Vector2.ZERO,false).length() <= 80.001,"fixed pad is bounded")
	check(Geometry.stick_offset(long_drag,Vector2.ZERO,true)==long_drag,"floating pad stretches freely")
	check(Geometry.movement(long_drag).length() <= 1.00001,"floating speed cannot increase")
	check(Geometry.movement(Vector2(2,2))==Vector2.ZERO,"dead zone")
	check(Geometry.can_start(Vector2(200,100),Vector2(854,480),true,Vector2(120,336)),"floating accepts left-side origin")
	check(not Geometry.can_start(Vector2(700,100),Vector2(854,480),true,Vector2(120,336)),"right side is look, not joystick")
	check(not Geometry.can_start(Vector2(200,100),Vector2(854,480),false,Vector2(120,336)),"fixed requires its pad")
	var wire := Capture.new()
	var client := Client.new();client._entered=true;client._server=7;client._transport=wire
	client.send_input(Vector3.RIGHT,1.2,true,false,false)
	check(wire.packets.back().data.look_locked==false and near(wire.packets.back().data.yaw,1.2),"input keeps aim separate from free facing")
	client.send_input(Vector3.LEFT,-0.7,false,true,true)
	check(wire.packets.back().data.look_locked==true,"input transmits lock mode")
	var server := Server.new();server._transport=wire;server._last_ok=server._clock()
	var body := CharacterBody3D.new();get_tree().root.add_child(body)
	var bag := Bag.new()
	var member := {"phase":"admitted","rate_at":server._clock(),"rate":0,"seq":0,"move":Vector2.ZERO,"yaw":0.0,"facing":-0.6,"look_locked":false,"sprint":false,"jump":false,"input_at":server._clock(),"room":"unit","body":body,"profile":{"public_id":"unit"},"bag":bag,"lantern":true,"swing":0}
	server._peers[7]=member;server._rooms["unit"]={"origin":Vector3.ZERO}
	server._receive(7,{"type":"input","seq":1,"move":[1.0,0.0],"yaw":1.2,"look_locked":false})
	check(member.move==Vector2.RIGHT and near(member.yaw,1.2) and member.look_locked==false,"server input does not replace tool aim")
	server._boot="unit";server._pulse_due=10000;server._snapshot_due=10000;server._rooms["unit"].targets=[]
	member.facing=0.0
	server._physics_process(1.0/60.0)
	check(member.facing < 0.0 and near(member.yaw,1.2),"actual server physics turns the free body without changing tool aim")
	member.look_locked=true
	var previous: float=member.facing
	server._physics_process(1.0/60.0)
	check(member.facing > previous and near(member.yaw,1.2),"actual server physics follows aim when locked")
	member.facing=-0.6
	wire.packets.clear();server._broadcast_snapshots()
	var pose: Array=wire.packets.back().data.players[0]
	check(pose.size()==14 and near(float(pose[7]),-0.6),"snapshot broadcasts body facing in unchanged14-field protocol")
	var replica := Remote.new();replica.apply_pose(pose)
	check(near(replica._yaw,-0.6),"remote consumes authoritative body yaw")
	server._receive(7,{"type":"input","seq":2,"move":[0.0,-1.0],"yaw":0.0})
	check(member.look_locked==true,"legacy clients retain their existing aim-facing behavior")
	server._receive(7,{"type":"input","seq":3,"move":[0.0,0.0],"yaw":0.0,"look_locked":"invalid"})
	check(wire.dropped.has(7),"malformed lock field fails closed")
	replica.free();client.free();server.free();body.free();wire.free()
	print(JSON.stringify({"contract_checks":checks,"passed":not failed,"live_network_used":false,"main_game_scene_started":false}))
	get_tree().quit(1 if failed else 0)
