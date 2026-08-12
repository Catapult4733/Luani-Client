# client_and_studio/scenes/player/player_avatar.gd
extends CharacterBody3D

## Multiplayer 3D Modular R6 Humanoid Player Avatar with WASD, Jump, Orbit Camera, Camera Zoom (PC/Mobile), Customization Sync, Inventory & Limb Animations

@export var move_speed: float = 8.0
@export var jump_velocity: float = 6.5
@export var mouse_sensitivity: float = 0.003
@export var max_health: float = 100.0
@export var current_health: float = 100.0

@export var min_camera_distance: float = 2.0
@export var max_camera_distance: float = 12.0
var camera_distance: float = 3.5

@onready var camera: Camera3D = %Camera3D
@onready var camera_pivot: Node3D = %CameraPivot
@onready var synchronizer: MultiplayerSynchronizer = %MultiplayerSynchronizer
@onready var username_label: Label3D = %UsernameLabel

# Body & Limb Pivot Nodes (R6 Rig)
@onready var body_mesh: Node3D = $BodyMesh
@onready var left_arm_pivot: Node3D = $BodyMesh/LeftArmPivot
@onready var right_arm_pivot: Node3D = $BodyMesh/RightArmPivot
@onready var left_leg_pivot: Node3D = $BodyMesh/LeftLegPivot
@onready var right_leg_pivot: Node3D = $BodyMesh/RightLegPivot

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var player_username: String = "LuaniPlayer"
var avatar_colors: Dictionary = {
	"head": "#e0ac69",
	"torso": "#0000ff",
	"left_arm": "#e0ac69",
	"right_arm": "#e0ac69",
	"left_leg": "#00ff00",
	"right_leg": "#00ff00"
}

var is_shiftlock_active: bool = false
var is_rmb_down: bool = false
var is_dead: bool = false
var last_input_time: float = 0.0

var health_bar_label: Label3D = null
var equipped_item_node: Node3D = null
var equipped_item_id: String = ""

var hotbar_overlay_inst: CanvasLayer = null
var crosshair_overlay_inst: CanvasLayer = null
var respawn_overlay_inst: CanvasLayer = null
var touch_overlay_inst: CanvasLayer = null

var touch_move_dir: Vector2 = Vector2.ZERO
var walk_anim_time: float = 0.0
var attack_anim_time: float = -1.0

# Mobile Pinch-to-Zoom Tracking
var active_touches: Dictionary = {}
var initial_pinch_dist: float = -1.0

const SWORD_SCENE := preload("res://scenes/weapons/sword.tscn")
const PICKABLE_SCENE := preload("res://scenes/items/pickable_item.tscn")
const HOTBAR_SCENE := preload("res://scenes/ui/hotbar_overlay.tscn")
const TOUCH_SCENE := preload("res://scenes/ui/touch_controls_overlay.tscn")

func _enter_tree() -> void:
	var peer_id := name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)

func _ready() -> void:
	last_input_time = Time.get_ticks_msec() / 1000.0
	var is_local := is_multiplayer_authority()
	camera.current = is_local

	_load_profile_identity()

	username_label.text = player_username
	apply_avatar_colors(avatar_colors)
	_setup_health_bar()

	if is_local and not DisplayServer.get_name() == "headless":
		_setup_local_ui()
		# Broadcast RPC username & customization data to all connected peers
		rpc("rpc_sync_player_data", multiplayer.get_unique_id(), player_username, avatar_colors)

func _load_profile_identity() -> void:
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if is_multiplayer_authority() and net_mgr:
		if net_mgr.local_username != "" and net_mgr.local_username != "Player":
			player_username = net_mgr.local_username
		if not net_mgr.local_avatar_colors.is_empty():
			avatar_colors = net_mgr.local_avatar_colors

	# Also check local user_profile.json
	if is_multiplayer_authority() and FileAccess.file_exists("user://user_profile.json"):
		var file := FileAccess.open("user://user_profile.json", FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary and parsed.get("username", "") != "":
				player_username = parsed.get("username")
				if parsed.get("colors") is Dictionary:
					avatar_colors = parsed.get("colors")

func _setup_health_bar() -> void:
	if not health_bar_label:
		health_bar_label = Label3D.new()
		health_bar_label.position = Vector3(0, 2.5, 0)
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
	if hotbar_overlay_inst.has_signal("slot_changed"):
		hotbar_overlay_inst.connect("slot_changed", _on_hotbar_slot_changed)
	if hotbar_overlay_inst.has_signal("drop_pressed"):
		hotbar_overlay_inst.connect("drop_pressed", _on_drop_pressed)

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

	# Dynamic Floating Virtual Joystick Overlay
	touch_overlay_inst = TOUCH_SCENE.instantiate() as CanvasLayer
	add_child(touch_overlay_inst)
	if touch_overlay_inst.has_signal("move_vector_changed"):
		touch_overlay_inst.connect("move_vector_changed", func(vec: Vector2): touch_move_dir = vec)
	if touch_overlay_inst.has_signal("jump_pressed"):
		touch_overlay_inst.connect("jump_pressed", func(): if is_on_floor(): velocity.y = jump_velocity)
	if touch_overlay_inst.has_signal("attack_pressed"):
		touch_overlay_inst.connect("attack_pressed", func(): perform_attack())
	if touch_overlay_inst.has_signal("zoom_in_pressed"):
		touch_overlay_inst.connect("zoom_in_pressed", func(): camera_distance = clamp(camera_distance - 0.75, min_camera_distance, max_camera_distance))
	if touch_overlay_inst.has_signal("zoom_out_pressed"):
		touch_overlay_inst.connect("zoom_out_pressed", func(): camera_distance = clamp(camera_distance + 0.75, min_camera_distance, max_camera_distance))

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	last_input_time = Time.get_ticks_msec() / 1000.0

	# Shiftlock Toggle via Ctrl Key
	if event is InputEventKey and event.keycode == KEY_CTRL and event.is_pressed() and not event.is_echo():
		_toggle_shiftlock()
		get_viewport().set_input_as_handled()

	# PC Camera Zoom Keybinds (Key I: Zoom In, Key O: Zoom Out)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_I:
			camera_distance = clamp(camera_distance - 0.5, min_camera_distance, max_camera_distance)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_O:
			camera_distance = clamp(camera_distance + 0.5, min_camera_distance, max_camera_distance)
			get_viewport().set_input_as_handled()

	# Mouse Wheel Camera Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
			camera_distance = clamp(camera_distance - 0.4, min_camera_distance, max_camera_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
			camera_distance = clamp(camera_distance + 0.4, min_camera_distance, max_camera_distance)

	# RMB Camera Orbit Toggle
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_rmb_down = event.is_pressed()
		if is_rmb_down or is_shiftlock_active:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Camera Mouse Motion
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Mobile Touch Camera Orbit & Pinch-to-Zoom
	elif event is InputEventScreenTouch:
		if event.is_pressed():
			active_touches[event.index] = event.position
		else:
			active_touches.erase(event.index)
		if active_touches.size() < 2:
			initial_pinch_dist = -1.0

	elif event is InputEventScreenDrag:
		active_touches[event.index] = event.position
		if active_touches.size() == 2:
			var touch_keys: Array = active_touches.keys()
			var pos1: Vector2 = active_touches[touch_keys[0]]
			var pos2: Vector2 = active_touches[touch_keys[1]]
			var current_dist: float = pos1.distance_to(pos2)
			if initial_pinch_dist < 0:
				initial_pinch_dist = current_dist
			else:
				var delta_dist: float = current_dist - initial_pinch_dist
				if abs(delta_dist) > 8.0:
					camera_distance = clamp(camera_distance - (delta_dist * 0.01), min_camera_distance, max_camera_distance)
					initial_pinch_dist = current_dist
		elif event.position.x > get_viewport().get_visible_rect().size.x * 0.4:
			rotate_y(-event.relative.x * mouse_sensitivity * 0.75)
			camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity * 0.75)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Left-Click Attack / Use Item
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		perform_attack()

func _toggle_shiftlock() -> void:
	is_shiftlock_active = not is_shiftlock_active
	if is_shiftlock_active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if crosshair_overlay_inst: crosshair_overlay_inst.show()
	else:
		if not is_rmb_down:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if crosshair_overlay_inst: crosshair_overlay_inst.hide()

func perform_attack() -> void:
	attack_anim_time = 0.0
	if equipped_item_node and equipped_item_node.has_method("swing"):
		equipped_item_node.call("swing")

func _on_hotbar_slot_changed(slot_idx: int) -> void:
	var inv := get_node_or_null("/root/InventoryManager")
	if inv:
		var item: Dictionary = inv.get_active_item()
		var item_id: String = item.get("id", "")
		rpc("rpc_equip_item_slot", item_id)

func _on_drop_pressed() -> void:
	var inv := get_node_or_null("/root/InventoryManager")
	if inv:
		var drop_pos := global_position + (transform.basis * Vector3(0, 1.0, 1.5))
		var dropped: Dictionary = inv.drop_active_item(drop_pos)
		if not dropped.is_empty():
			rpc("rpc_spawn_world_item", dropped, drop_pos)

@rpc("any_peer", "call_local", "reliable")
func rpc_sync_player_data(peer_id: int, uname: String, colors: Dictionary) -> void:
	set_player_username(uname)
	apply_avatar_colors(colors)

@rpc("any_peer", "call_local", "reliable")
func rpc_equip_item_slot(item_id: String) -> void:
	equipped_item_id = item_id
	if equipped_item_node:
		equipped_item_node.queue_free()
		equipped_item_node = null

	if item_id in ["sword", "axe", "pickaxe"]:
		if right_arm_pivot:
			equipped_item_node = SWORD_SCENE.instantiate()
			equipped_item_node.position = Vector3(0, -0.4, 0.2)
			equipped_item_node.rotation_degrees = Vector3(-90, 0, 0)
			right_arm_pivot.add_child(equipped_item_node)
			if equipped_item_node.has_method("set_owner_player"):
				equipped_item_node.call("set_owner_player", self)

@rpc("any_peer", "call_local", "reliable")
func rpc_spawn_world_item(item_data: Dictionary, spawn_pos: Vector3) -> void:
	var pickable := PICKABLE_SCENE.instantiate() as Area3D
	pickable.position = spawn_pos
	if "item_data" in pickable:
		pickable.item_data = item_data
	get_tree().root.add_child(pickable)

func pickup_item(item_data: Dictionary) -> void:
	if not is_multiplayer_authority():
		return
	var inv := get_node_or_null("/root/InventoryManager")
	if inv:
		inv.add_item(item_data)
		print("[Luani Player] Picked up item: ", item_data.get("name", ""))

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health = max(0.0, current_health - amount)
	_update_health_bar_text()
	var ui_mgr := get_node_or_null("/root/UIManager")
	if ui_mgr and ui_mgr.has_method("update_health_bar"):
		ui_mgr.call("update_health_bar", current_health, max_health)
	if current_health <= 0:
		_die_and_respawn()

func _die_and_respawn() -> void:
	is_dead = true
	visible = false

	# Play Death Sound Effect
	var sfx := AudioStreamPlayer.new()
	add_child(sfx)
	print("[Luani Player] Player died: ", player_username)

	var ui_mgr := get_node_or_null("/root/UIManager")

	if is_multiplayer_authority() and not DisplayServer.get_name() == "headless":
		_show_respawning_overlay()

	get_tree().create_timer(3.0).timeout.connect(func():
		current_health = max_health
		_update_health_bar_text()
		if ui_mgr and ui_mgr.has_method("update_health_bar"):
			ui_mgr.call("update_health_bar", current_health, max_health)
		visible = true
		is_dead = false

		if respawn_overlay_inst:
			respawn_overlay_inst.queue_free()
			respawn_overlay_inst = null

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

var last_synced_pos: Vector3 = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		if last_synced_pos != Vector3.ZERO and delta > 0.0001:
			var pos_delta := global_position - last_synced_pos
			# Ignore sudden teleport jumps
			if pos_delta.length() < 15.0:
				velocity = pos_delta / delta
			else:
				velocity = Vector3.ZERO
		last_synced_pos = global_position
		_update_camera_zoom(delta)
		_update_limb_animations(delta)
		return

	_update_camera_zoom(delta)
	_update_limb_animations(delta)

	if is_dead:
		return

	# AFK 30-Minute Inactivity Kick Check (1800s)
	var current_time := Time.get_ticks_msec() / 1000.0
	if (current_time - last_input_time) > 1800.0:
		last_input_time = current_time
		var net_mgr := get_node_or_null("/root/NetworkManager")
		if net_mgr and net_mgr.has_method("_handle_connection_failure"):
			net_mgr.call("_handle_connection_failure", "[Kicked] You were disconnected for 30 minutes of inactivity (AFK).")

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

	# Movement input
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0

	if touch_move_dir != Vector2.ZERO:
		input_dir = touch_move_dir

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()

func _update_camera_zoom(delta: float) -> void:
	if camera:
		camera.position.z = lerp(camera.position.z, camera_distance, delta * 10.0)

## Updates R6 Limb Swing & Action Animations (Idle, Walk, Jump/Fall, Attack)
func _update_limb_animations(delta: float) -> void:
	if not left_arm_pivot or not right_arm_pivot or not left_leg_pivot or not right_leg_pivot:
		return

	var is_moving := Vector2(velocity.x, velocity.z).length() > 0.5
	var on_floor := is_on_floor()

	# Attack Animation Sweep
	if attack_anim_time >= 0.0:
		attack_anim_time += delta * 6.0
		var slash_angle: float = lerp(-90.0, 30.0, clamp(attack_anim_time, 0.0, 1.0))
		right_arm_pivot.rotation_degrees.x = slash_angle
		if attack_anim_time >= 1.0:
			attack_anim_time = -1.0

	if on_floor:
		if is_moving:
			# Walk / Run limb swing
			walk_anim_time += delta * 12.0
			var arm_swing: float = sin(walk_anim_time) * 35.0
			var leg_swing: float = sin(walk_anim_time) * 35.0

			left_arm_pivot.rotation_degrees.x = arm_swing
			if attack_anim_time < 0.0:
				right_arm_pivot.rotation_degrees.x = -arm_swing

			left_leg_pivot.rotation_degrees.x = -leg_swing
			right_leg_pivot.rotation_degrees.x = leg_swing
		else:
			# Idle subtle breathing stance
			walk_anim_time += delta * 2.0
			var breath: float = sin(walk_anim_time) * 2.5
			left_arm_pivot.rotation_degrees.x = lerp(left_arm_pivot.rotation_degrees.x, breath, delta * 8.0)
			if attack_anim_time < 0.0:
				right_arm_pivot.rotation_degrees.x = lerp(right_arm_pivot.rotation_degrees.x, breath, delta * 8.0)
			left_leg_pivot.rotation_degrees.x = lerp(left_leg_pivot.rotation_degrees.x, 0.0, delta * 8.0)
			right_leg_pivot.rotation_degrees.x = lerp(right_leg_pivot.rotation_degrees.x, 0.0, delta * 8.0)
	else:
		# Jump / Fall pose
		left_arm_pivot.rotation_degrees.x = lerp(left_arm_pivot.rotation_degrees.x, -40.0, delta * 10.0)
		if attack_anim_time < 0.0:
			right_arm_pivot.rotation_degrees.x = lerp(right_arm_pivot.rotation_degrees.x, -40.0, delta * 10.0)
		left_leg_pivot.rotation_degrees.x = lerp(left_leg_pivot.rotation_degrees.x, 20.0, delta * 10.0)
		right_leg_pivot.rotation_degrees.x = lerp(right_leg_pivot.rotation_degrees.x, -20.0, delta * 10.0)

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
		"left_arm": "BodyMesh/LeftArmPivot/LeftArm",
		"right_arm": "BodyMesh/RightArmPivot/RightArm",
		"left_leg": "BodyMesh/LeftLegPivot/LeftLeg",
		"right_leg": "BodyMesh/RightLegPivot/RightLeg"
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

var equipped_accessories: Array = []

@rpc("any_peer", "call_local", "reliable")
func sync_equipped_accessories(accessory_ids: Array) -> void:
	equipped_accessories = accessory_ids
	_apply_equipped_accessories()

func _apply_equipped_accessories() -> void:
	var head_node: Node3D = get_node_or_null("BodyMesh/Head")
	var torso_node: Node3D = get_node_or_null("BodyMesh/Torso")
	if not head_node or not torso_node:
		return

	for child in head_node.get_children():
		if child.name.begins_with("Acc_"):
			child.queue_free()
	for child in torso_node.get_children():
		if child.name.begins_with("Acc_"):
			child.queue_free()

	for acc_id in equipped_accessories:
		match str(acc_id):
			"hat_cap":
				var cap := MeshInstance3D.new()
				cap.name = "Acc_Cap"
				var cap_mesh := BoxMesh.new()
				cap_mesh.size = Vector3(0.7, 0.25, 0.7)
				cap.mesh = cap_mesh
				cap.position = Vector3(0, 0.4, 0)
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.9, 0.2, 0.2)
				cap.material_override = mat
				head_node.add_child(cap)
			"glasses_shades":
				var shades := MeshInstance3D.new()
				shades.name = "Acc_Shades"
				var shades_mesh := BoxMesh.new()
				shades_mesh.size = Vector3(0.65, 0.15, 0.2)
				shades.mesh = shades_mesh
				shades.position = Vector3(0, 0.1, -0.32)
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.1, 0.1, 0.1)
				shades.material_override = mat
				head_node.add_child(shades)
			"backpack_pack":
				var pack := MeshInstance3D.new()
				pack.name = "Acc_Pack"
				var pack_mesh := BoxMesh.new()
				pack_mesh.size = Vector3(0.8, 0.9, 0.35)
				pack.mesh = pack_mesh
				pack.position = Vector3(0, 0.1, 0.4)
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.4, 0.25, 0.15)
				pack.material_override = mat
				torso_node.add_child(pack)

