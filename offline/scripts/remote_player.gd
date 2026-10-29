extends Node3D
## Visual-only remote replica; server snapshots own all gameplay state.
const Avatar = preload("res://scripts/avatar.gd")
const Visual = preload("res://scripts/item_visual.gd")
const AvatarData = preload("res://scripts/avatar_data.gd")
var profile: Dictionary = {}
var rig: Avatar
var _target: Vector3
var _yaw: float = 0.0
var _speed: float = 0.0
var _vertical: float = 0.0
var _grounded := true
var _running := false
var _model: Node3D
var _item := ""
var _lantern := true
var _last_swing: int = 0
var _has_pose := false
var _name_tag: Label3D

func _ready() -> void:
	rig=Avatar.new(); rig.appearance=profile.get("avatar",{}); add_child(rig)
	_name_tag = Label3D.new(); _name_tag.text=str(profile.get("username","Player")).substr(0,50); _name_tag.position.y=3.4
	_name_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED; _name_tag.font_size=40; _name_tag.pixel_size=0.004
	add_child(_name_tag)

func apply_profile(value: Dictionary) -> void:
	if str(value.get("key","")) != str(profile.get("key","")) or not value.get("avatar") is Dictionary: return
	var next: Dictionary = value.avatar
	if AvatarData.revision(next) < AvatarData.revision(profile.get("avatar",{})): return
	profile = value.duplicate(true)
	if is_instance_valid(rig): rig.apply_appearance(next)
	if is_instance_valid(_name_tag): _name_tag.text=str(profile.get("username","Player")).substr(0,50)

func apply_pose(pose: Array) -> void:
	if pose.size()!=14: return
	_target=Vector3(float(pose[1]),float(pose[2]),float(pose[3])); _yaw=float(pose[7])
	_speed=Vector2(float(pose[4]),float(pose[6])).length(); _vertical=float(pose[5]); _grounded=bool(pose[8]); _running=bool(pose[9])
	if not _has_pose: position=_target; _has_pose=true
	var item := str(pose[10])
	if item!=_item:
		if is_instance_valid(_model): _model.queue_free()
		_model=null; _item=item; rig.holding_tool=not item.is_empty()
		if not item.is_empty():
			_model=Visual.make(item); rig.right_arm.add_child(_model)
			_model.position=Vector3(0,-1.0,-0.10); _model.rotation.x=-PI*0.5
			if item=="lantern": _model.position=Vector3(0,-1.8,-0.03); _model.rotation=Vector3.ZERO
		_lantern=not bool(pose[11])
	if int(pose[12])!=_last_swing: _last_swing=int(pose[12]); rig.tool_swing=0.32
	if _model!=null and _lantern!=bool(pose[11]):
		_lantern=bool(pose[11])
		for light in _model.find_children("LanternLight","OmniLight3D",true,false):
			(light as OmniLight3D).visible=_lantern
		for mesh in _model.find_children("LanternGlow","MeshInstance3D",true,false):
			var instance := mesh as MeshInstance3D
			(instance.material_override as StandardMaterial3D).emission_enabled=_lantern

func _process(delta: float) -> void:
	if not _has_pose: return
	position=position.lerp(_target,minf(delta*16.0,1.0)); rotation.y=lerp_angle(rotation.y,_yaw,minf(delta*16.0,1.0))
	rig.motion_speed=_speed; rig.vertical_speed=_vertical; rig.airborne=not _grounded; rig.running=_running
