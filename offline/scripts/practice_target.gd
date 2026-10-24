extends Node3D
## A resettable practice prop, not an online player or living NPC.
const Visual = preload("res://scripts/item_visual.gd")
const MAX_HITS := 3
var hits_remaining: int = MAX_HITS
var body: StaticBody3D
var _mesh: Node3D
var _label: Label3D
var _wood: StandardMaterial3D
var _reset_remaining: float = 0.0
var _flash: float = 0.0

func _ready() -> void:
	body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.05, 2.10, 0.65)
	collision.shape = shape
	collision.position.y = 1.05
	body.add_child(collision)
	_mesh = Node3D.new()
	add_child(_mesh)
	_wood = Visual.material("9d7955")
	Visual.cylinder(_mesh, 0.13, 1.6, Vector3(0, 0.8, 0), Visual.material("5b4437"))
	Visual.box(_mesh, Vector3(1.05, 1.15, 0.45), Vector3(0, 1.45, 0), _wood)
	Visual.box(_mesh, Vector3(0.65, 0.65, 0.04), Vector3(0, 1.45, -0.25), Visual.material("3b324e"))
	Visual.box(_mesh, Vector3(0.29, 0.29, 0.045), Vector3(0, 1.45, -0.28), Visual.material("c1adff"))
	_label = Label3D.new()
	_label.position.y = 2.35
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 32
	_label.pixel_size = 0.0035
	_label.outline_size = 8
	add_child(_label)
	_update_label()

func hit() -> bool:
	if hits_remaining <= 0:
		return false
	hits_remaining -= 1
	_flash = 0.18
	_update_label()
	if hits_remaining == 0:
		_reset_remaining = 5.0
		_mesh.hide()
		body.collision_layer = 0
	return true

func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_wood.albedo_color = Color("ead7aa") if _flash > 0 else Color("9d7955")
	if _reset_remaining > 0:
		_reset_remaining = maxf(0.0, _reset_remaining - delta)
		if _reset_remaining == 0:
			hits_remaining = MAX_HITS
			_mesh.show()
			body.collision_layer = 1
			_update_label()

func _update_label() -> void:
	_label.text = "Practice target · %d/%d" % [hits_remaining, MAX_HITS] if hits_remaining > 0 else "Target resetting…"
