extends Node3D
var network_id: String = ""
## Non-solid pickup: selection is distance/line-of-sight based, collection is explicit E.
const Visual = preload("res://scripts/item_visual.gd")
const Catalog = preload("res://scripts/item_catalog.gd")
var item_id: String = "sword"
var claimed := false
var cooldown: float = 0.0
var _clock: float = 0.0
var _model: Node3D
var _ring: MeshInstance3D
var _label: Label3D

func _ready() -> void:
	_model = Visual.make(item_id)
	_model.position.y = 0.65
	_model.rotation.z = -0.28
	add_child(_model)
	# Ground lights belong to equipped lanterns, not every pickup on the map.
	for child in _model.find_children("LanternLight", "OmniLight3D", true, false):
		var light := child as OmniLight3D
		if light != null:
			light.visible = false
	var base_mat := Visual.material("202229")
	Visual.cylinder(self, 0.60, 0.04, Vector3(0, 0.025, 0), base_mat)
	_ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.54
	mesh.outer_radius = 0.59
	mesh.rings = 24
	mesh.ring_segments = 6
	_ring.mesh = mesh
	_ring.material_override = Visual.material(str(Catalog.item(item_id).get("color", "c1adff")), 0, true)
	_ring.position.y = 0.05
	add_child(_ring)
	_label = Label3D.new()
	_label.text = Catalog.title(item_id)
	_label.position.y = 2.35
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 32
	_label.pixel_size = 0.0035
	_label.outline_size = 8
	_label.visible = false
	add_child(_label)
	_clock = position.x * 0.13 + position.z * 0.21

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	_clock += delta
	_model.position.y = 0.65 + sin(_clock * 2.0) * 0.09
	_model.rotation.y += delta * 0.55

func highlight(active: bool) -> void:
	if is_instance_valid(_label):
		_label.visible = active
