extends Control
## Multi-touch input; fixed/floating joystick only changes input geometry, never authority.
const UI = preload("res://scripts/ui_theme.gd")
const Geometry = preload("res://scripts/touch_geometry.gd")
var player
var world
var _joy_id: int = -1
var _look_id: int = -1
var _stick := Vector2.ZERO
var _floating_origin := Vector2.ZERO
var _mode := "fixed"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.make_theme()
	_mode = SessionState.mobile_joystick_mode
	SessionState.preferences_changed.connect(_preferences)

func _preferences() -> void:
	if _mode != SessionState.mobile_joystick_mode:
		_reset()
		_mode = SessionState.mobile_joystick_mode

func _fixed_center() -> Vector2:
	return Vector2(120, get_viewport_rect().size.y - 144)

func _joy_center() -> Vector2:
	return _floating_origin if _mode == "floating" else _fixed_center()

func _buttons() -> Dictionary:
	var s := get_viewport_rect().size
	return {"JUMP":s-Vector2(88,134), "USE":s-Vector2(180,92), "PICK":s-Vector2(272,92), "DROP":s-Vector2(88,228), "RUN":s-Vector2(180,188)}

func _blocked() -> bool:
	return not is_instance_valid(player) or player.input_blocked or not player._window_focused

func _hits_ui(point: Vector2) -> bool:
	return is_instance_valid(world.hud) and world.hud.touch_hits_ui(point)

func _reset() -> void:
	_joy_id = -1; _look_id = -1; _stick = Vector2.ZERO
	SessionState.mobile_move = Vector2.ZERO
	SessionState.mobile_jump = false
	SessionState.mobile_sprint = false

func _input(event: InputEvent) -> void:
	if _blocked(): _reset(); return
	if event is InputEventScreenTouch:
		if not event.pressed:
			if event.index == _joy_id: _joy_id = -1; _stick = Vector2.ZERO; SessionState.mobile_move = Vector2.ZERO
			if event.index == _look_id: _look_id = -1
			return
		if _hits_ui(event.position): return
		for action: String in _buttons():
			if event.position.distance_to(_buttons()[action]) < 38:
				_press(action); get_viewport().set_input_as_handled(); return
		if _joy_id < 0 and Geometry.can_start(event.position, get_viewport_rect().size, _mode == "floating", _fixed_center()):
			_joy_id = event.index
			_floating_origin = event.position
			_move_stick(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _joy_id:
		_move_stick(event.position); get_viewport().set_input_as_handled()

func _move_stick(point: Vector2) -> void:
	_stick = Geometry.stick_offset(point, _joy_center(), _mode == "floating")
	SessionState.mobile_move = Geometry.movement(_stick)

func _press(action: String) -> void:
	match action:
		"JUMP": SessionState.mobile_jump = true
		"RUN": SessionState.mobile_sprint = not SessionState.mobile_sprint
		"PICK": world._pickup_requested = true
		"USE": world._use_requested = true
		"DROP": world._drop_requested = true

func _unhandled_input(event: InputEvent) -> void:
	if _blocked(): return
	if event is InputEventScreenTouch and event.pressed and event.position.x >= get_viewport_rect().size.x * 0.5 and not _hits_ui(event.position):
		_look_id = event.index
	elif event is InputEventScreenDrag and event.index == _look_id:
		player.camera_yaw = wrapf(player.camera_yaw - event.relative.x * 0.003, -PI, PI)
		player.camera_pitch = clampf(player.camera_pitch - event.relative.y * 0.003, -player.PITCH_LIMIT, player.PITCH_LIMIT)
		player._update_camera()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	visible = not _blocked()
	if not visible: _reset()
	queue_redraw()

func _draw() -> void:
	var base := Color(0.07, 0.07, 0.10, 0.72)
	if _mode == "fixed" or _joy_id >= 0:
		draw_line(_joy_center(), _joy_center() + _stick, Color(0.6,0.55,0.75,0.6), 6, true)
		draw_circle(_joy_center(), 84, base)
		draw_arc(_joy_center(), 84, 0, TAU, 64, Color(0.6,0.55,0.75,0.7), 2, true)
		draw_circle(_joy_center() + _stick, 30, Color(0.61,0.51,0.85,0.8))
	for action: String in _buttons():
		var point: Vector2 = _buttons()[action]
		draw_circle(point, 36, Color(0.43,0.31,0.7,0.85) if action == "RUN" and SessionState.mobile_sprint else base)
		draw_string(get_theme_default_font(), point + Vector2(-34,6), action, HORIZONTAL_ALIGNMENT_CENTER, 68, 15, Color(0.94,0.93,0.98))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _reset()
func _exit_tree() -> void:
	_reset()
