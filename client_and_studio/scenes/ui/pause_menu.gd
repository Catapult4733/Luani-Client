# client_and_studio/scenes/ui/pause_menu.gd
extends Control

## In-Game ESC Pause Menu Overlay for Luani Client

@onready var leave_button: Button = %LeaveButton
@onready var respawn_button: Button = %RespawnButton
@onready var shift_lock_button: CheckButton = %ShiftLockButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_label: Label = %VolumeLabel
@onready var resume_button: Button = %ResumeButton

var is_shift_lock_enabled: bool = true

func _ready() -> void:
	hide()
	
	leave_button.pressed.connect(_on_leave_pressed)
	respawn_button.pressed.connect(_on_respawn_pressed)
	shift_lock_button.toggled.connect(_on_shift_lock_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	resume_button.pressed.connect(_on_resume_pressed)
	
	# Initial volume setup
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var current_db := AudioServer.get_bus_volume_db(bus_idx)
		volume_slider.value = db_to_linear(current_db) * 100.0

func toggle_menu() -> void:
	visible = not visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if is_shift_lock_enabled:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void:
	hide()
	if is_shift_lock_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_leave_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.disconnect_network()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_respawn_pressed() -> void:
	hide()
	if is_shift_lock_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	var my_peer_id := multiplayer.get_unique_id()
	var player_node: Node3D = get_node_or_null("/root/GameWorld/Players/" + str(my_peer_id))
	if not player_node:
		player_node = get_node_or_null("/root/Main/Players/" + str(my_peer_id))
		
	if player_node:
		player_node.global_position = Vector3(0, 2, 0)
		player_node.velocity = Vector3.ZERO
		print("[Luani PauseMenu] Respawned local player avatar at spawn location.")

func _on_shift_lock_toggled(pressed: bool) -> void:
	is_shift_lock_enabled = pressed
	if pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[Luani PauseMenu] Shift Lock toggled: ", pressed)

func _on_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var linear_val := value / 100.0
		var db_val := linear_to_db(linear_val)
		AudioServer.set_bus_volume_db(bus_idx, db_val)
		volume_label.text = "Master Volume: " + str(int(value)) + "%"
