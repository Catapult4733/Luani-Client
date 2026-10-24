class_name LuaniPlayer
extends CharacterBody3D

signal shift_lock_changed(active: bool)
const AvatarScript = preload("res://scripts/avatar.gd")
const WALK_SPEED := 7.0
const RUN_SPEED := 12.0
const JUMP_SPEED := 9.0
const GRAVITY := 25.0
var input_blocked: bool = false
var shift_locked: bool = false
var orbit_dragging: bool = false
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
	camera.current = true
	arm.add_child(camera)
	_footstep = AudioStreamPlayer.new()
	_footstep.stream = _make_step_sound()
	_footstep.volume_db = -17.0
	add_child(_footstep)
	SessionState.preferences_changed.connect(_preferences_changed)
	_update_camera()

func _preferences_changed() -> void:
	_name_tag.text = SessionState.display_name
	if not SessionState.shift_lock_enabled:
		set_shift_lock(false)

func set_shift_lock(value: bool) -> void:
	shift_locked = value and SessionState.shift_lock_enabled
	shift_lock_changed.emit(shift_locked)
	update_mouse_mode()

func update_mouse_mode() -> void:
	if input_blocked:
		orbit_dragging = false
	var capture := not input_blocked and (shift_locked or orbit_dragging)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked:
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
			camera_distance = maxf(2.8, camera_distance - 0.6)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(16.0, camera_distance + 0.6)
	elif event is InputEventMouseMotion and (shift_locked or orbit_dragging):
		camera_yaw -= event.relative.x * 0.003
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.003, -1.15, 0.45)

func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	if not grounded:
		velocity.y -= GRAVITY * delta
	var movement := Vector2.ZERO
	if not input_blocked:
		movement = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if grounded and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_SPEED
			_play_step(1.5)
	var direction := Vector3(movement.x, 0, movement.y).rotated(Vector3.UP, camera_yaw)
	var sprinting := not input_blocked and Input.is_action_pressed("sprint") and movement.length() > 0.1
	var speed := RUN_SPEED if sprinting else WALK_SPEED
	var acceleration := 38.0 if direction.is_zero_approx() else 28.0
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	move_and_slide()
	if global_position.y < -35.0:
		respawn()
	if shift_locked:
		avatar.rotation.y = lerp_angle(avatar.rotation.y, camera_yaw, minf(delta * 16.0, 1.0))
	elif direction.length_squared() > 0.01:
		var facing := atan2(-direction.x, -direction.z)
		avatar.rotation.y = lerp_angle(avatar.rotation.y, facing, minf(delta * 12.0, 1.0))
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
	var shoulder := Vector3(0.8, 0, 0).rotated(Vector3.UP, camera_yaw) if shift_locked else Vector3.ZERO
	camera_pivot.position = Vector3(0, 2.1, 0) + shoulder
	camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0)
	arm.spring_length = camera_distance

func respawn() -> void:
	global_position = Vector3(0, 0.2, 0)
	velocity = Vector3.ZERO
	avatar.motion_speed = 0.0
	_step_clock = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		orbit_dragging = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
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
