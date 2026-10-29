extends Node
## Local controls/audio only; online identity comes exclusively from verified admission.
signal preferences_changed
const AvatarData = preload("res://scripts/avatar_data.gd")
const SETTINGS_PATH := "user://offline_settings.cfg"
var display_name: String = "Explorer"
var avatar: Dictionary = {}
var online: bool = false
var profile: Dictionary = {}
var game: Dictionary = {}
var shift_lock_enabled: bool = true
var game_volume: float = 0.7
var mobile_move: Vector2 = Vector2.ZERO
var mobile_jump: bool = false
var mobile_sprint: bool = false
var mobile_joystick_mode: String = "fixed"
var mobile_camera_locked: bool = false

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		shift_lock_enabled = bool(config.get_value("controls", "shift_lock_enabled", true))
		game_volume = clampf(float(config.get_value("audio", "volume", 0.7)), 0.0, 1.0)
		var mode := str(config.get_value("controls", "mobile_joystick_mode", "fixed"))
		mobile_joystick_mode = mode if mode in ["fixed", "floating"] else "fixed"
		mobile_camera_locked = bool(config.get_value("controls", "mobile_camera_locked", false))
	_apply_volume()
	_register_keys()

func set_identity(value: Dictionary) -> void:
	profile = value.duplicate(true)
	display_name = str(value.get("username", "Explorer")).substr(0, 50)
	avatar = value.get("avatar", {}).duplicate(true)
	preferences_changed.emit()

func apply_server_avatar(value: Dictionary) -> void:
	if AvatarData.revision(value) <= AvatarData.revision(avatar): return
	avatar = value.duplicate(true)
	profile["avatar"] = avatar.duplicate(true)
	# Cosmetic hot refresh must not emit the controls/audio preference signal.

func set_shift_lock_enabled(value: bool) -> void:
	shift_lock_enabled = value
	save_preferences()
	preferences_changed.emit()

func set_volume(value: float) -> void:
	game_volume = clampf(value, 0.0, 1.0)
	_apply_volume()

func set_mobile_joystick_mode(value: String) -> void:
	if value not in ["fixed", "floating"]: return
	mobile_joystick_mode = value
	save_preferences()
	preferences_changed.emit()

func set_mobile_camera_locked(value: bool) -> void:
	mobile_camera_locked = value
	save_preferences()
	preferences_changed.emit()

func _apply_volume() -> void:
	AudioServer.set_bus_mute(0, game_volume < 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(game_volume, 0.0001)))

func save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "shift_lock_enabled", shift_lock_enabled)
	config.set_value("controls", "mobile_joystick_mode", mobile_joystick_mode)
	config.set_value("controls", "mobile_camera_locked", mobile_camera_locked)
	config.set_value("audio", "volume", game_volume)
	if config.save(SETTINGS_PATH) != OK: push_warning("Luani could not save local preferences.")

func _register_keys() -> void:
	var keys := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "shift_lock": KEY_CTRL}
	for action: String in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var key := InputEventKey.new(); key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)
