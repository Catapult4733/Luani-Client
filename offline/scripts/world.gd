extends Node3D
## A single offline world. Pickups and practice props are session-local, not server entities.
signal status_changed(message: String)
signal roster_changed
const PlayerScript = preload("res://scripts/player.gd")
const HudScript = preload("res://scripts/hud.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const TargetScript = preload("res://scripts/practice_target.gd")
const Catalog = preload("res://scripts/item_catalog.gd")
const PICKUP_RANGE := 3.2
const SCATTER := [
	["sword", Vector2(4, -5)], ["lantern", Vector2(-5, -4)], ["spring_coil", Vector2(2, 6)],
	["sword", Vector2(14, -13)], ["lantern", Vector2(-17, 8)], ["spring_coil", Vector2(15, 15)],
	["sword", Vector2(-25, -19)], ["lantern", Vector2(27, -8)], ["spring_coil", Vector2(-22, 26)],
	["sword", Vector2(33, 29)], ["lantern", Vector2(-37, -31)], ["spring_coil", Vector2(7, -39)],
	["sword", Vector2(-48, 10)], ["lantern", Vector2(45, -34)], ["spring_coil", Vector2(39, 48)],
	["sword", Vector2(58, 12)], ["lantern", Vector2(-12, 55)], ["spring_coil", Vector2(-54, -46)],
]
var player: PlayerScript
var inventory: InventoryScript
var hud
var _pickups: Array[PickupScript] = []
var _targets: Array[TargetScript] = []
var _nearest: PickupScript
var _pickup_requested := false
var _use_requested := false
var _drop_requested := false
var _use_cooldown: float = 0.0

func roster() -> Array:
	return [{"key":"offline","username":SessionState.display_name,"avatar":SessionState.avatar}]

func leave_game() -> void:
	pass

func _ready() -> void:
	_build_environment()
	_build_baseplate()
	inventory = InventoryScript.new()
	player = PlayerScript.new()
	player.name = "LocalPlayer"
	player.position = Vector3(0, 0.2, 0)
	add_child(player)
	inventory.equipped_changed.connect(player.set_equipped_item)
	for entry in SCATTER:
		var point: Vector2 = entry[1]
		_spawn_pickup(str(entry[0]), Vector3(point.x, 0, point.y))
	for point: Vector2 in [Vector2(4, -10), Vector2(-9, -9), Vector2(12, 4), Vector2(-14, 7), Vector2(0, 20)]:
		var target := TargetScript.new()
		target.position = Vector3(point.x, 0, point.y)
		add_child(target)
		_targets.append(target)
	hud = HudScript.new()
	hud.player = player
	hud.inventory = inventory
	hud.world = self
	add_child(hud)
	_attach_mobile_controls()

func _attach_mobile_controls() -> void:
	if not OS.has_feature("android"): return
	var layer := CanvasLayer.new()
	layer.layer = 2
	var controls: Control = load("res://scripts/mobile_controls.gd").new()
	controls.player = player
	controls.world = self
	layer.add_child(controls)
	add_child(layer)

func _spawn_pickup(id: String, point: Vector3, cooldown: float = 0.0) -> PickupScript:
	var pickup := PickupScript.new()
	pickup.item_id = id
	pickup.position = point
	pickup.cooldown = cooldown
	add_child(pickup)
	_pickups.append(pickup)
	return pickup

func _unhandled_input(event: InputEvent) -> void:
	# Emulated mouse clicks still operate GUI, never use a tool from a camera swipe.
	if OS.has_feature("android") and event is InputEventMouseButton and event.device == -1: return
	if not player.can_use_tools():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			_pickup_requested = true
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_Q:
			_drop_requested = true
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_use_requested = true
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_use_cooldown = maxf(0.0, _use_cooldown - delta)
	_select_pickup()
	if player.can_use_tools():
		if _pickup_requested: _collect_nearest()
		if _drop_requested: drop_slot(inventory.equipped_slot)
		if _use_requested: _use_item()
	_pickup_requested = false
	_drop_requested = false
	_use_requested = false

func _clear_line(point: Vector3, excluded: Array[RID] = []) -> bool:
	var start: Vector3 = player.global_position + Vector3.UP * 1.4
	var query := PhysicsRayQueryParameters3D.create(start, point, 1, excluded)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _select_pickup() -> void:
	var best: PickupScript = null
	var distance := PICKUP_RANGE
	if player.can_use_tools():
		for pickup in _pickups:
			if not is_instance_valid(pickup) or pickup.claimed or pickup.cooldown > 0:
				continue
			var d: float = (player.global_position + Vector3.UP).distance_to(pickup.global_position + Vector3.UP * 0.8)
			if d < distance and _clear_line(pickup.global_position + Vector3.UP):
				best = pickup
				distance = d
	if best == _nearest:
		return
	if is_instance_valid(_nearest): _nearest.highlight(false)
	_nearest = best
	if is_instance_valid(_nearest): _nearest.highlight(true)

func pickup_title() -> String:
	return Catalog.title(_nearest.item_id) if is_instance_valid(_nearest) and not _nearest.claimed else ""

func _collect_nearest() -> void:
	if not is_instance_valid(_nearest) or _nearest.claimed:
		return
	var was_empty := inventory.occupied_count() == 0
	if not inventory.add_item(_nearest.item_id):
		status_changed.emit("Inventory full. Drop an item to make space.")
		return
	# Claim before scheduling free so repeated input cannot duplicate one pickup.
	_nearest.claimed = true
	if was_empty:
		inventory.equip(0)
	status_changed.emit("Picked up " + Catalog.title(_nearest.item_id))
	_pickups.erase(_nearest)
	_nearest.queue_free()
	_nearest = null

func drop_slot(index: int) -> void:
	if not player._window_focused:
		return
	var data: Dictionary = inventory.get_slot(index)
	if data.is_empty():
		return
	var direction := Vector3.FORWARD.rotated(Vector3.UP, player.camera_yaw)
	var point: Vector3 = player.global_position + direction * 2.2
	point = Vector3(clampf(point.x, -112.0, 112.0), 0, clampf(point.z, -112.0, 112.0))
	_spawn_pickup(str(data["id"]), point, 0.8)
	inventory.remove_slot(index)
	status_changed.emit("Dropped " + Catalog.title(str(data["id"])))

func _use_item() -> void:
	if _use_cooldown > 0:
		return
	match inventory.equipped_id():
		"sword":
			_use_cooldown = 0.45
			player.swing_tool()
			var forward := Vector3.FORWARD.rotated(Vector3.UP, player.camera_yaw)
			for target in _targets:
				if target.hits_remaining <= 0:
					continue
				var offset: Vector3 = target.global_position - player.global_position
				var flat := Vector3(offset.x, 0, offset.z)
				if flat.length() <= 3.4 and absf(offset.y) < 2.5 and (flat.is_zero_approx() or forward.dot(flat.normalized()) > 0.25):
					if _clear_line(target.global_position + Vector3.UP * 1.4, [target.body.get_rid()]):
						target.hit()
						status_changed.emit("Target hit · %d/%d" % [target.hits_remaining, target.MAX_HITS])
		"lantern":
			_use_cooldown = 0.25
			var on: bool = player.toggle_lantern()
			status_changed.emit("Lantern on" if on else "Lantern off")
		"spring_coil":
			_use_cooldown = 0.6
			status_changed.emit("Spring Coil active · Space to jump higher")

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color("718fae")
	material.sky_horizon_color = Color("dce5ed")
	material.ground_bottom_color = Color("909bab")
	material.ground_horizon_color = Color("dce5ed")
	sky.sky_material = material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dbe3ef")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("fff1d9")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	if OS.has_feature("android"):
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 42.0
	add_child(sun)

func _build_baseplate() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Baseplate"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 2
	floor_body.position.y = -0.5
	var shape := BoxShape3D.new()
	shape.size = Vector3(240, 1, 240)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = mesh
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("a8b2be")
	material.roughness = 1.0
	floor_mesh.material_override = material
	floor_body.add_child(floor_mesh)
	add_child(floor_body)
	var grid := MultiMeshInstance3D.new()
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	var line := BoxMesh.new()
	line.size = Vector3(0.022, 0.008, 240)
	var grid_material := StandardMaterial3D.new()
	grid_material.albedo_color = Color("929eae")
	grid_material.roughness = 1.0
	line.material = grid_material
	instances.mesh = line
	instances.instance_count = 122
	for index in range(61):
		var coordinate := float(index * 4 - 120)
		instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(coordinate, 0.006, 0)))
		instances.set_instance_transform(index + 61, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.006, coordinate)))
	grid.multimesh = instances
	add_child(grid)
