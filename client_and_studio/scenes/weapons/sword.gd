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

	# Enable blade collision during swing
	if blade_area:
		blade_area.monitoring = true

func _process(delta: float) -> void:
	if is_swinging:
		swing_timer += delta
		var progress := swing_timer / SWING_DURATION

		# Swing rotation animation arc
		if progress <= 1.0:
			var rot_z := sin(progress * PI) * -1.2
			var rot_y := sin(progress * PI) * 0.8
			mesh_holder.rotation = Vector3(0, rot_y, rot_z)
		else:
			is_swinging = false
			mesh_holder.rotation = Vector3.ZERO
			if blade_area:
				blade_area.monitoring = false

func _on_blade_body_entered(body: Node) -> void:
	if not is_swinging:
		return

	# Avoid hitting self or duplicate hits in a single swing
	if body == owner_player or body in hit_targets:
		return

	if body.has_method("take_damage"):
		hit_targets.append(body)
		print("[Luani Sword] Hit target ", body.name, " dealing ", DAMAGE_PER_HIT, " damage.")

		if body.has_method("rpc"):
			body.rpc("take_damage", DAMAGE_PER_HIT)
		else:
			body.take_damage(DAMAGE_PER_HIT)

		hit_player.emit(body, DAMAGE_PER_HIT)
