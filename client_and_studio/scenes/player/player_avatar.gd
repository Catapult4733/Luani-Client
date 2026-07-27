# client_and_studio/scenes/player/player_avatar.gd
extends CharacterBody3D

## Multiplayer 3D Humanoid Player Avatar with WASD, Jump, Mouse Orbit, Shiftlock, Health/Combat, and Sword Equipment

@export var move_speed: float = 8.0
@export var jump_velocity: float = 6.5
@export var mouse_sensitivity: float = 0.003
@export var max_health: float = 100.0
@export var current_health: float = 100.0

@onready var camera: Camera3D = %Camera3D
@onready var camera_pivot: Node3D = %CameraPivot
@onready var synchronizer: MultiplayerSynchronizer = %MultiplayerSynchronizer
@onready var username_label: Label3D = %UsernameLabel

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var player_username: String = "Player"
var avatar_colors: Dictionary = {}

var is_shiftlock_active: bool = false
var is_rmb_down: bool = false
var is_dead: bool = false
var last_input_time: float = 0.0

var health_bar_label: Label3D = null
var equipped_sword: Node3D = null
var hotbar_overlay_inst: CanvasLayer = null
var crosshair_overlay_inst: CanvasLayer = null
var respawn_overlay_inst: CanvasLayer = null

const SWORD_SCENE := preload("res://scenes/weapons/sword.tscn")
const HOTBAR_SCENE := preload("res://scenes/ui/hotbar_overlay.tscn")

func _enter_tree() -> void:
	var peer_id := name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)

func _ready() -> void:
	last_input_time = Time.get_ticks_msec() / 1000.0
	var is_local := is_multiplayer_authority()
	camera.current = is_local

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if is_local and net_mgr and net_mgr.local_username != "":
		player_username = net_mgr.local_username
		if not net_mgr.local_avatar_colors.is_empty():
			avatar_colors = net_mgr.local_avatar_colors
	elif player_username == "Player":
		player_username = "Player_" + str(name)

	username_label.text = player_username
	if not avatar_colors.is_empty():
		apply_avatar_colors(avatar_colors)

	_setup_health_bar()

	if is_local and not DisplayServer.get_name() == "headless":
		_setup_local_ui()

func _setup_health_bar() -> void:
	if not health_bar_label:
		health_bar_label = Label3D.new()
		health_bar_label.position = Vector3(0, 2.4, 0)
		health_bar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		health_bar_label.font_size = 22
		health_bar_label.modulate = Color(0.2, 0.95, 0.4)
		add_child(health_bar_label)
	_update_health_bar_text()

func _update_health_bar_text() -> void:
	if health_bar_label:
		health_bar_label.text = "[ HP: %d / %d ]" % [int(current_health), int(max_health)]
		var pct := current_health / max_health
		if pct > 0.5:
			health_bar_label.modulate = Color(0.2, 0.95, 0.4)
		elif pct > 0.25:
			health_bar_label.modulate = Color(0.95, 0.8, 0.2)
		else:
			health_bar_label.modulate = Color(0.95, 0.25, 0.25)

func _setup_local_ui() -> void:
	# Hotbar UI
	hotbar_overlay_inst = HOTBAR_SCENE.instantiate() as CanvasLayer
	add_child(hotbar_overlay_inst)
	if hotbar_overlay_inst.has_signal("sword_equip_toggled"):
		hotbar_overlay_inst.connect("sword_equip_toggled", _on_sword_equip_toggled)

	# Crosshair UI for Shiftlock
	crosshair_overlay_inst = CanvasLayer.new()
	crosshair_overlay_inst.layer = 20
	var center_ctrl := Control.new()
	center_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var crosshair := Label.new()
	crosshair.text = "┼"
	crosshair.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - 6, get_viewport().get_visible_rect().size.y / 2.0 - 12)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	crosshair.add_theme_font_size_override("font_size", 20)
	center_ctrl.add_child(crosshair)
	crosshair_overlay_inst.add_child(center_ctrl)
	crosshair_overlay_inst.hide()
	add_child(crosshair_overlay_inst)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	last_input_time = Time.get_ticks_msec() / 1000.0

	# Shiftlock Toggle via Ctrl Key
	if event is InputEventKey and event.keycode == KEY_CTRL and event.is_pressed() and not event.is_echo():
		_toggle_shiftlock()
		get_viewport().set_input_as_handled()

	# RMB Camera Orbit Toggle
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_rmb_down = event.is_pressed()
		if is_rmb_down or is_shiftlock_active:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Camera Mouse Orbit Motion
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Left-Click Sword Swing
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if equipped_sword and equipped_sword.has_method("swing"):
			equipped_sword.call("swing")

func _toggle_shiftlock() -> void:
	is_shiftlock_active = not is_shiftlock_active
	if is_shiftlock_active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if crosshair_overlay_inst: crosshair_overlay_inst.show()
	else:
		if not is_rmb_down:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if crosshair_overlay_inst: crosshair_overlay_inst.hide()

func _on_sword_equip_toggled(equipped: bool) -> void:
	rpc("set_sword_equipped", equipped)

@rpc("any_peer", "call_local", "reliable")
func set_sword_equipped(equipped: bool) -> void:
	if equipped:
		if not equipped_sword:
			var right_arm := get_node_or_null("BodyMesh/RightArm")
			if right_arm:
				equipped_sword = SWORD_SCENE.instantiate()
				equipped_sword.position = Vector3(0, -0.4, 0.2)
				equipped_sword.rotation_degrees = Vector3(-90, 0, 0)
				right_arm.add_child(equipped_sword)
				if equipped_sword.has_method("set_owner_player"):
					equipped_sword.call("set_owner_player", self)
	else:
		if equipped_sword:
			equipped_sword.queue_free()
			equipped_sword = null

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float) -> void:
	if is_dead:
		return

	current_health = max(0.0, current_health - amount)
	_update_health_bar_text()

	if current_health <= 0:
		_die_and_respawn()

func _die_and_respawn() -> void:
	is_dead = true
	visible = false

	if is_multiplayer_authority() and not DisplayServer.get_name() == "headless":
		_show_respawning_overlay()

	get_tree().create_timer(3.0).timeout.connect(func():
		current_health = max_health
		_update_health_bar_text()
		visible = true
		is_dead = false

		if respawn_overlay_inst:
			respawn_overlay_inst.queue_free()
			respawn_overlay_inst = null

		# Pick random spawn location
		_teleport_to_random_spawn()
	)

func _teleport_to_random_spawn() -> void:
	var spawn_nodes: Array = []
	var game_world := get_node_or_null("/root/GameWorld")
	if game_world:
		var spawns_group := game_world.get_node_or_null("SpawnLocations")
		if not spawns_group:
			spawns_group = game_world.get_node_or_null("WorldRoot/SpawnLocations")

		if spawns_group:
			spawn_nodes = spawns_group.get_children()

	if spawn_nodes.size() > 0:
		var chosen: Node3D = spawn_nodes.pick_random()
		global_position = chosen.global_position + Vector3(0, 1.0, 0)
	else:
		global_position = Vector3(randf_range(-5, 5), 2.0, randf_range(-5, 5))

func _show_respawning_overlay() -> void:
	respawn_overlay_inst = CanvasLayer.new()
	respawn_overlay_inst.layer = 30

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var label := Label.new()
	label.text = "⚔️ You Were Defeated!\nRespawning in 3 seconds..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	panel.add_child(label)
	
	respawn_overlay_inst.add_child(panel)
	add_child(respawn_overlay_inst)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		return

	# AFK 30-Minute Inactivity Kick Check (1800s)
	var current_time := Time.get_ticks_msec() / 1000.0
	if (current_time - last_input_time) > 1800.0:
		last_input_time = current_time
		print("[Luani AFK Manager] 30 minutes of inactivity reached. Kicking player...")
		var net_mgr := get_node_or_null("/root/NetworkManager")
		if net_mgr and net_mgr.has_method("_handle_connection_failure"):
			net_mgr.call("_handle_connection_failure", "[Kicked] You were disconnected for 30 minutes of inactivity (AFK).")

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

	# Movement
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

func set_player_username(uname: String) -> void:
	if uname != "":
		player_username = uname
		if username_label:
			username_label.text = uname

func apply_avatar_colors(colors: Dictionary) -> void:
	if colors.is_empty():
		return
	avatar_colors = colors

	var part_map := {
		"head": "BodyMesh/Head",
		"torso": "BodyMesh/Torso",
		"left_arm": "BodyMesh/LeftArm",
		"right_arm": "BodyMesh/RightArm",
		"left_leg": "BodyMesh/LeftLeg",
		"right_leg": "BodyMesh/RightLeg"
	}

	for key in part_map:
		if colors.has(key):
			var node_path: String = part_map[key]
			var mesh_inst: MeshInstance3D = get_node_or_null(node_path)
			if mesh_inst:
				var hex_str: String = str(colors[key])
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color.html(hex_str)
				mesh_inst.material_override = mat
