# client_and_studio/scenes/ui/touch_controls_overlay.gd
extends CanvasLayer

## Dynamic Floating Virtual Touch Joystick & Action Buttons Overlay for Mobile

signal move_vector_changed(vector: Vector2)
signal jump_pressed
signal attack_pressed

@onready var joystick_base: Control = %JoystickBase
@onready var joystick_knob: Control = %JoystickKnob
@onready var btn_jump: Button = %BtnJump
@onready var btn_attack: Button = %BtnAttack

var is_joystick_active: bool = false
var joystick_touch_index: int = -1
var joystick_origin: Vector2 = Vector2.ZERO
var joystick_max_radius: float = 65.0
var current_move_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		hide()
		return

	# Show touch controls on mobile or desktop touch simulation
	show()

	# Start with joystick hidden until touched
	if joystick_base:
		joystick_base.hide()

	if btn_jump:
		btn_jump.pressed.connect(func(): jump_pressed.emit())
	if btn_attack:
		btn_attack.pressed.connect(func(): attack_pressed.emit())

func _input(event: InputEvent) -> void:
	if not visible or not joystick_base:
		return

	var screen_width := get_viewport().get_visible_rect().size.x

	# 1. Screen Touch / Mouse Click Press on Left 50% of screen
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var is_press: bool = event.is_pressed()
		var pos: Vector2 = event.position
		var idx: int = event.index if event is InputEventScreenTouch else 0

		if is_press and pos.x < (screen_width * 0.5):
			# Start floating joystick at touch point
			is_joystick_active = true
			joystick_touch_index = idx
			joystick_origin = pos

			# Reposition JoystickBase centered at touch point
			joystick_base.global_position = pos - (joystick_base.size / 2.0)
			joystick_base.show()

			_update_joystick(pos)

		elif not is_press:
			# Release matching touch index
			if idx == joystick_touch_index or not (event is InputEventScreenTouch):
				_reset_joystick()

	# 2. Screen Drag / Mouse Motion relative to touch origin
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		var idx: int = event.index if event is InputEventScreenDrag else 0
		if is_joystick_active and (idx == joystick_touch_index or not (event is InputEventScreenDrag)):
			_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2) -> void:
	if not joystick_base or not joystick_knob:
		return

	var diff := touch_pos - joystick_origin
	if diff.length() > joystick_max_radius:
		diff = diff.normalized() * joystick_max_radius

	# Move knob inside base
	var knob_center := (joystick_base.size / 2.0) - (joystick_knob.size / 2.0)
	joystick_knob.position = knob_center + diff

	# Calculate normalized movement vector (X: left/right, Y: forward/backward)
	current_move_vector = diff / joystick_max_radius
	move_vector_changed.emit(current_move_vector)

func _reset_joystick() -> void:
	is_joystick_active = false
	joystick_touch_index = -1
	current_move_vector = Vector2.ZERO
	if joystick_knob and joystick_base:
		joystick_knob.position = (joystick_base.size / 2.0) - (joystick_knob.size / 2.0)
		joystick_base.hide()
	move_vector_changed.emit(Vector2.ZERO)
