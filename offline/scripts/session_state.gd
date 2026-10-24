extends Node
## Device-local preferences only. This client has no account or multiplayer connection.

signal preferences_changed
const SETTINGS_PATH := "user://offline_settings.cfg"
var display_name: String = "Explorer"
var shift_lock_enabled: bool = true
var game_volume: float = 0.7

func _ready() -> void:
	var suggested := OS.get_environment("USER")
	if suggested.is_empty():
		suggested = OS.get_environment("USERNAME")
	display_name = clean_name(suggested)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		display_name = clean_name(str(config.get_value("player", "name", display_name)))
		shift_lock_enabled = bool(config.get_value("controls", "shift_lock_enabled", true))
		game_volume = clampf(float(config.get_value("audio", "volume", 0.7)), 0.0, 1.0)
	_apply_volume()
	_register_keys()

func clean_name(value: String) -> String:
	var result := ""
	for character in value.strip_edges():
		if character.unicode_at(0) >= 32 and character != ":" and character.unicode_at(0) != 127:
			result += character
	result = result.substr(0, 24).strip_edges()
	return result if not result.is_empty() else "Explorer"

func set_display_name(value: String) -> void:
	display_name = clean_name(value)
	save_preferences()
	preferences_changed.emit()

func set_shift_lock_enabled(value: bool) -> void:
	shift_lock_enabled = value
	save_preferences()
	preferences_changed.emit()

func set_volume(value: float) -> void:
	game_volume = clampf(value, 0.0, 1.0)
	_apply_volume()

func _apply_volume() -> void:
	AudioServer.set_bus_mute(0, game_volume < 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(game_volume, 0.0001)))

func save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", display_name)
	config.set_value("controls", "shift_lock_enabled", shift_lock_enabled)
	config.set_value("audio", "volume", game_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Luani could not save device-local preferences: " + error_string(error))

func _register_keys() -> void:
	var keys := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "shift_lock": KEY_CTRL}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)
