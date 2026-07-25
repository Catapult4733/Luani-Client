# client_and_studio/scripts/studio/studio_camera.gd
class_name StudioCamera
extends Camera3D

## 3D Studio Camera supporting Orbit navigation and WASD Flycam navigation

enum CameraMode { ORBIT, FLYCAM }

@export var mode: CameraMode = CameraMode.ORBIT
@export var move_speed: float = 12.0
@export var rotate_sensitivity: float = 0.005
@export var zoom_sensitivity: float = 1.5

var focus_point: Vector3 = Vector3.ZERO
var orbit_distance: float = 15.0
var pitch: float = -0.4
var yaw: float = 0.6
var is_dragging: bool = false

func _ready() -> void:
	update_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_dragging else Input.MOUSE_MODE_VISIBLE
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = max(2.0, orbit_distance - zoom_sensitivity)
			update_camera_transform()
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = min(100.0, orbit_distance + zoom_sensitivity)
			update_camera_transform()

	elif event is InputEventMouseMotion and is_dragging:
		yaw -= event.relative.x * rotate_sensitivity
		pitch = clamp(pitch - event.relative.y * rotate_sensitivity, -1.5, 1.5)
		update_camera_transform()

func _process(delta: float) -> void:
	if is_dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var input_dir := Vector3.ZERO
		if Input.is_key_pressed(KEY_W): input_dir.z -= 1.0
		if Input.is_key_pressed(KEY_S): input_dir.z += 1.0
		if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
		if Input.is_key_pressed(KEY_E): input_dir.y += 1.0
		if Input.is_key_pressed(KEY_Q): input_dir.y -= 1.0
		
		if input_dir != Vector3.ZERO:
			input_dir = input_dir.normalized()
			var move_vec := global_transform.basis * input_dir
			focus_point += move_vec * move_speed * delta
			update_camera_transform()

func update_camera_transform() -> void:
	var rot_quat := Quaternion.from_euler(Vector3(pitch, yaw, 0))
	var offset := rot_quat * Vector3(0, 0, orbit_distance)
	global_position = focus_point + offset
	look_at(focus_point, Vector3.UP)
