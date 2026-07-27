# client_and_studio/scenes/ui/touch_controls_overlay.gd
extends CanvasLayer

## Virtual TouchScreen Controls & Touch Camera Drag Overlay for Android / iOS Mobile Clients

signal move_vector_changed(vector: Vector2)
signal jump_pressed
signal attack_pressed

@onready var joystick_base: Control = %JoystickBase
@onready var joystick_knob: Control = %JoystickKnob
@onready var btn_jump: Button = %BtnJump
@onready var btn_attack: Button = %BtnAttack
@onready var touch_camera_area: Control = %TouchCameraArea

var is_joystick_active: bool = false
var joystick_center: Vector2 = Vector2.ZERO
var joystick_max_radius: float = 60.0
var current_move_vector: Vector2 = Vector2.ZERO

var is_camera_touch_active: bool = false
var last_camera_touch_pos: Vector2 = Vector2.ZERO
var camera_touch_index: int = -1

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		hide()
		return

	# Show touch controls on mobile or touch-enabled devices
	if OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]:
		show()
	else:
		# Also visible if force-enabled or running on Android export
		show()

	if btn_jump:
		btn_jump.pressed.connect(func(): jump_pressed.emit())
	if btn_attack:
		btn_attack.pressed.connect(func(): attack_pressed.emit())

	if joystick_base:
		joystick_center = joystick_base.size / 2.0

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Joystick Touch Drag Handling
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var is_press: bool = event.is_pressed()
		var pos: Vector2 = event.position

		# Left side touch (Joystick)
		if pos.x < get_viewport().get_visible_rect().size.x * 0.45:
			if is_press:
				is_joystick_active = true
				_update_joystick(pos)
			else:
				is_joystick_active = false
				_reset_joystick()

	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if is_joystick_active:
			_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2) -> void:
	if not joystick_base:
		return
	var base_global_center := joystick_base.global_position + (joystick_base.size / 2.0)
	var diff := touch_pos - base_global_center
	if diff.length() > joystick_max_radius:
		diff = diff.normalized() * joystick_max_radius

	if joystick_knob:
		joystick_knob.position = (joystick_base.size / 2.0) + diff - (joystick_knob.size / 2.0)

	current_move_vector = diff / joystick_max_radius
	move_vector_changed.emit(current_move_vector)

func _reset_joystick() -> void:
	current_move_vector = Vector2.ZERO
	if joystick_knob and joystick_base:
		joystick_knob.position = (joystick_base.size / 2.0) - (joystick_knob.size / 2.0)
	move_vector_changed.emit(Vector2.ZERO)
