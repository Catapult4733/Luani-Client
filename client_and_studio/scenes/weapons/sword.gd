# client_and_studio/scenes/weapons/sword.gd
extends Node3D

## Sword Melee Weapon script with swing animation and hit detection

signal hit_player(target_player: Node, damage: float)

@onready var blade_area: Area3D = $BladeArea
@onready var mesh_holder: Node3D = $MeshHolder

var is_swinging: bool = false
var swing_timer: float = 0.0
const SWING_DURATION: float = 0.35
const DAMAGE_PER_HIT: float = 25.0

var owner_player: Node = null
var hit_targets: Array[Node] = []

func _ready() -> void:
	if blade_area:
		blade_area.body_entered.connect(_on_blade_body_entered)

func set_owner_player(player_node: Node) -> void:
	owner_player = player_node

func swing() -> void:
	if is_swinging:
		return

	is_swinging = true
	swing_timer = 0.0
	hit_targets.clear()

	if blade_area:
		blade_area.monitoring = true

	# Spawn Slash Particle Trail
	_spawn_slash_trail()

func _spawn_slash_trail() -> void:
	var trail := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 45.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 5.0
	mat.color = Color(0.3, 0.8, 1.0, 0.9)
	trail.process_material = mat
	var pmesh := QuadMesh.new()
	pmesh.size = Vector2(0.2, 0.2)
	trail.draw_pass_1 = pmesh
	trail.one_shot = true
	trail.explosiveness = 0.95
	add_child(trail)
	trail.emitting = true
	get_tree().create_timer(0.4).timeout.connect(func(): if is_instance_valid(trail): trail.queue_free())

func _on_blade_body_entered(body: Node) -> void:
	if not is_swinging:
		return

	if body == owner_player or body in hit_targets:
		return

	if body.has_method("take_damage"):
		hit_targets.append(body)
		print("[Luani Sword] Hit target ", body.name, " dealing ", DAMAGE_PER_HIT, " damage.")

		if body.has_method("rpc"):
			body.rpc("take_damage", DAMAGE_PER_HIT)
		else:
			body.take_damage(DAMAGE_PER_HIT)

		# Target Flash Effect
		if body.has_node("BodyMesh"):
			var bmesh: Node3D = body.get_node("BodyMesh")
			var orig_pos := bmesh.position
			bmesh.position += Vector3(0.05, 0.05, 0.05)
			get_tree().create_timer(0.08).timeout.connect(func(): if is_instance_valid(bmesh): bmesh.position = orig_pos)

		# Camera Shake
		if owner_player and owner_player.get_node_or_null("CameraPivot/Camera3D"):
			var cam: Camera3D = owner_player.get_node("CameraPivot/Camera3D")
			var orig_rot := cam.rotation_degrees
			cam.rotation_degrees += Vector3(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5), 0)
			get_tree().create_timer(0.06).timeout.connect(func(): if is_instance_valid(cam): cam.rotation_degrees = orig_rot)

		hit_player.emit(body, DAMAGE_PER_HIT)

