class_name LuaniPlayer
extends CharacterBody3D

signal shift_lock_changed(active: bool)
signal camera_mode_changed(first_person_active: bool)
const AvatarScript = preload("res://scripts/avatar.gd")
const Visual = preload("res://scripts/item_visual.gd")
const Facing = preload("res://scripts/facing.gd")
const WALK_SPEED := 7.0
const RUN_SPEED := 12.0
const JUMP_SPEED := 9.0
const GRAVITY := 25.0
const MIN_ORBIT_DISTANCE := 1.8
const MAX_ORBIT_DISTANCE := 16.0
const ZOOM_STEP := 0.6
const PITCH_LIMIT := deg_to_rad(89.0)
const FIRST_PERSON_EYE_HEIGHT := 2.70
var input_blocked: bool = false
var shift_locked: bool = false
var orbit_dragging: bool = false
var first_person: bool = false
var _window_focused: bool = true
var camera_yaw: float = 0.0
var camera_pitch: float = -0.25
var camera_distance: float = 7.0
var avatar: AvatarScript
var camera_pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var _footstep: AudioStreamPlayer
var _step_clock: float = 0.0
var _name_tag: Label3D
var equipped_item_id: String = ""
var _held_model: Node3D
var _view_model: Node3D
var _swing_remaining: float = 0.0
var _lantern_on: bool = true
var network_driver
var respawn_floor: float = -35.0
var _network_clock: float = 0.0
var _network_jump: bool = false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.25
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.46
	capsule.height = 3.04
	collision.shape = capsule
	collision.position.y = 1.53
	add_child(collision)
	avatar = AvatarScript.new()
	avatar.appearance = SessionState.avatar
	add_child(avatar)
	_name_tag = Label3D.new()
	_name_tag.text = SessionState.display_name
	_name_tag.position.y = 3.40
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.font_size = 40
	_name_tag.pixel_size = 0.004
	add_child(_name_tag)
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 2.1
	add_child(camera_pivot)
	arm = SpringArm3D.new()
	arm.spring_length = camera_distance
	arm.collision_mask = 1
	arm.margin = 0.12
	arm.add_excluded_object(get_rid())
	camera_pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.current = true
	arm.add_child(camera)
	_footstep = AudioStreamPlayer.new()
	_footstep.stream = _make_step_sound()
	_footstep.volume_db = -17.0
	add_child(_footstep)
	SessionState.preferences_changed.connect(_preferences_changed)
	if OS.has_feature("android"): set_shift_lock(SessionState.mobile_camera_locked)
	_update_camera()

func _preferences_changed() -> void:
	_name_tag.text = SessionState.display_name
	if OS.has_feature("android"):
		set_shift_lock(SessionState.mobile_camera_locked)
	elif not SessionState.shift_lock_enabled:
		set_shift_lock(false)

func set_shift_lock(value: bool) -> void:
	shift_locked = value and (OS.has_feature("android") or SessionState.shift_lock_enabled)
	shift_lock_changed.emit(shift_locked)
	update_mouse_mode()

func update_mouse_mode() -> void:
	if OS.has_feature("android"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if input_blocked:
		orbit_dragging = false
	var capture := _window_focused and not input_blocked and (first_person or shift_locked or orbit_dragging)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE

func set_first_person(value: bool) -> void:
	if first_person == value:
		return
	first_person = value
	camera_distance = 0.0 if first_person else MIN_ORBIT_DISTANCE
	# The independent Players avatar viewer remains visible.
	avatar.visible = not first_person
	_name_tag.visible = not first_person
	_sync_tool_visibility()
	orbit_dragging = false
	_update_camera()
	update_mouse_mode()
	camera_mode_changed.emit(first_person)

func _zoom(inward: bool) -> void:
	if inward:
		if first_person:
			return
		var next_distance := camera_distance - ZOOM_STEP
		if next_distance < MIN_ORBIT_DISTANCE - 0.001:
			set_first_person(true)
		else:
			camera_distance = maxf(MIN_ORBIT_DISTANCE, next_distance)
	else:
		if first_person:
			set_first_person(false)
		else:
			camera_distance = minf(MAX_ORBIT_DISTANCE, camera_distance + ZOOM_STEP)
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked or not _window_focused:
		return
	if event.is_action_pressed("shift_lock") and not event.is_echo():
		if SessionState.shift_lock_enabled:
			set_shift_lock(not shift_locked)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			orbit_dragging = event.pressed
			update_mouse_mode()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(true)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(false)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontal rotation is unlimited; only prevent a vertical upside-down flip.
		camera_yaw = wrapf(camera_yaw - event.screen_relative.x * 0.003, -PI, PI)
		camera_pitch = clampf(camera_pitch - event.screen_relative.y * 0.003, -PITCH_LIMIT, PITCH_LIMIT)
		_update_camera()

func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	if not grounded:
		velocity.y -= GRAVITY * delta
	var movement := Vector2.ZERO
	if not input_blocked and _window_focused:
		movement = (Input.get_vector("move_left", "move_right", "move_forward", "move_back") + SessionState.mobile_move).limit_length(1.0)
		if grounded and (Input.is_action_just_pressed("jump") or SessionState.mobile_jump):
			_network_jump = true
			velocity.y = JUMP_SPEED * (1.5 if equipped_item_id == "spring_coil" else 1.0)
			_play_step(1.5)
	SessionState.mobile_jump = false
	var direction := Vector3(movement.x, 0, movement.y).rotated(Vector3.UP, camera_yaw)
	var sprinting := not input_blocked and _window_focused and (Input.is_action_pressed("sprint") or SessionState.mobile_sprint) and movement.length() > 0.1
	var speed := RUN_SPEED if sprinting else WALK_SPEED
	_network_clock -= delta
	if network_driver != null and _network_clock <= 0:
		_network_clock = 1.0 / 30.0
		network_driver.send_input(direction, camera_yaw, sprinting, _network_jump, shift_locked or first_person)
		_network_jump = false
	var acceleration := 38.0 if direction.is_zero_approx() else 28.0
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	move_and_slide()
	if global_position.y < respawn_floor:
		respawn()
	var locked := shift_locked or first_person
	var body_facing := Facing.target(Vector2(direction.x, direction.z), camera_yaw, locked, avatar.rotation.y)
	avatar.rotation.y = lerp_angle(avatar.rotation.y, body_facing, minf(delta * Facing.rate(locked), 1.0))
	avatar.motion_speed = Vector2(velocity.x, velocity.z).length()
	avatar.airborne = not is_on_floor()
	avatar.vertical_speed = velocity.y
	avatar.running = sprinting
	if is_on_floor() and avatar.motion_speed > 1.0:
		_step_clock += delta
		if _step_clock > (0.24 if sprinting else 0.36):
			_step_clock = 0.0
			_play_step(1.1 if sprinting else 0.92)
	else:
		_step_clock = 0.0
	_update_camera()

func _update_camera() -> void:
	var shoulder := Vector3(0.8, 0, 0).rotated(Vector3.UP, camera_yaw) if shift_locked and not first_person else Vector3.ZERO
	var height := FIRST_PERSON_EYE_HEIGHT if first_person else 2.1
	camera_pivot.position = Vector3(0, height, 0) + shoulder
	camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0)
	arm.spring_length = 0.0 if first_person else camera_distance

func respawn() -> void:
	if network_driver != null:
		network_driver.action("respawn")
		return
	global_position = Vector3(0, 0.2, 0)
	velocity = Vector3.ZERO
	avatar.motion_speed = 0.0
	_step_clock = 0.0
	_swing_remaining = 0.0
	avatar.tool_swing = 0.0

func can_use_tools() -> bool:
	return _window_focused and not input_blocked

func set_equipped_item(id: String) -> void:
	equipped_item_id = id
	for old in [_held_model, _view_model]:
		if is_instance_valid(old):
			old.hide()
			old.queue_free()
	_held_model = null
	_view_model = null
	avatar.holding_tool = not id.is_empty()
	avatar.tool_swing = 0.0
	_swing_remaining = 0.0
	_lantern_on = true
	if id.is_empty():
		return
	_held_model = Visual.make(id)
	avatar.right_arm.add_child(_held_model)
	_held_model.position = Vector3(0, -1.0, -0.10)
	_held_model.rotation.x = -PI * 0.5
	if id == "lantern":
		_held_model.position = Vector3(0, -1.8, -0.03)
		_held_model.rotation = Vector3.ZERO
	_view_model = Visual.make(id)
	camera.add_child(_view_model)
	_view_model.position = Vector3(0.40, -0.52, -0.85)
	_view_model.scale = Vector3.ONE * 0.5
	_view_model.rotation.z = -0.25
	_sync_tool_visibility()

func swing_tool() -> void:
	_swing_remaining = 0.32
	avatar.tool_swing = 0.32
	avatar.rotation.y = camera_yaw

func toggle_lantern() -> bool:
	_lantern_on = not _lantern_on
	for model in [_held_model, _view_model]:
		if not is_instance_valid(model):
			continue
		for node in model.find_children("LanternLight", "OmniLight3D", true, false):
			var light := node as OmniLight3D
			if light != null:
				light.visible = _lantern_on
		for node in model.find_children("LanternGlow", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh != null:
				var material := mesh.material_override as StandardMaterial3D
				material.emission_enabled = _lantern_on
				material.albedo_color = Color("f0cd8d") if _lantern_on else Color("685c49")
	return _lantern_on

func set_lantern_state(value: bool) -> void:
	if _lantern_on != value: toggle_lantern()

func reconcile(position_value: Vector3, velocity_value: Vector3) -> void:
	if global_position.distance_to(position_value) > 2.0:
		global_position = position_value
		velocity = velocity_value
	else:
		global_position = global_position.lerp(position_value, 0.15)

func _sync_tool_visibility() -> void:
	if is_instance_valid(_held_model):
		_held_model.visible = not first_person
	if is_instance_valid(_view_model):
		_view_model.visible = first_person and not input_blocked and _window_focused

func _process(delta: float) -> void:
	_swing_remaining = maxf(0.0, _swing_remaining - delta)
	_sync_tool_visibility()
	if is_instance_valid(_view_model):
		var phase := 1.0 - _swing_remaining / 0.32
		_view_model.rotation.z = -0.25 - (sin(phase * PI) * 0.85 if _swing_remaining > 0 else 0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
		orbit_dragging = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		_window_focused = true
		update_mouse_mode()

func _play_step(pitch: float) -> void:
	_footstep.pitch_scale = pitch
	_footstep.play()

func _make_step_sound() -> AudioStreamWAV:
	# Short original synthesized thud. No third-party audio or import pipeline.
	var samples := 2205
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for index in range(samples):
		var t := float(index) / 22050.0
		var wave := sin(TAU * 115.0 * t) + 0.3 * sin(TAU * 187.0 * t)
		var envelope := exp(-t * 65.0) * minf(t * 700.0, 1.0)
		bytes.encode_s16(index * 2, int(clampf(wave * envelope * 11000.0, -32767, 32767)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	return stream
