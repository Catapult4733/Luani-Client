# client_and_studio/scenes/player/player_avatar.gd
extends CharacterBody3D

## Multiplayer 3D Humanoid Player Avatar with WASD, Jump, Mouse Look, and Username Label

@export var move_speed: float = 8.0
@export var jump_velocity: float = 6.5
@export var mouse_sensitivity: float = 0.003

@onready var camera: Camera3D = %Camera3D
@onready var camera_pivot: Node3D = %CameraPivot
@onready var synchronizer: MultiplayerSynchronizer = %MultiplayerSynchronizer
@onready var username_label: Label3D = %UsernameLabel

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var player_username: String = "Player"

func _enter_tree() -> void:
	# Set multiplayer authority based on node name (peer id)
	var peer_id := name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)

func _ready() -> void:
	var is_local := is_multiplayer_authority()
	camera.current = is_local

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if is_local and net_mgr and net_mgr.local_username != "":
		player_username = net_mgr.local_username
	elif player_username == "Player":
		player_username = "Player_" + str(name)

	username_label.text = player_username

func set_player_username(uname: String) -> void:
	if uname != "":
		player_username = uname
		if username_label:
			username_label.text = uname

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	elif event is InputEventKey and event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()
