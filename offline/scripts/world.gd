extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const HudScript = preload("res://scripts/hud.gd")

func _ready() -> void:
	_build_environment()
	_build_baseplate()
	var player := PlayerScript.new()
	player.name = "LocalPlayer"
	player.position = Vector3(0, 0.2, 0)
	add_child(player)
	var hud := HudScript.new()
	hud.player = player
	add_child(hud)

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
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("a8b2be")
	material.roughness = 1.0
	floor_mesh.material_override = material
	floor_body.add_child(floor_mesh)
	add_child(floor_body)
	var grid := MultiMeshInstance3D.new()
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
