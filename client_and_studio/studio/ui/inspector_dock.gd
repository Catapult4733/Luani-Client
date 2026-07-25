# client_and_studio/studio/ui/inspector_dock.gd
extends Control

signal property_changed(target_node: Node3D, prop_name: String, value: Variant)

@onready var name_input: LineEdit = %NameInput
@onready var pos_x: SpinBox = %PosX
@onready var pos_y: SpinBox = %PosY
@onready var pos_z: SpinBox = %PosZ
@onready var rot_x: SpinBox = %RotX
@onready var rot_y: SpinBox = %RotY
@onready var rot_z: SpinBox = %RotZ
@onready var scale_x: SpinBox = %ScaleX
@onready var scale_y: SpinBox = %ScaleY
@onready var scale_z: SpinBox = %ScaleZ
@onready var color_picker: ColorPickerButton = %ColorPicker
@onready var anchored_check: CheckBox = %AnchoredCheck

var selected_node: Node3D = null
var is_updating_ui: bool = false

func _ready() -> void:
	name_input.text_submitted.connect(_on_name_submitted)
	pos_x.value_changed.connect(_on_transform_changed)
	pos_y.value_changed.connect(_on_transform_changed)
	pos_z.value_changed.connect(_on_transform_changed)
	rot_x.value_changed.connect(_on_transform_changed)
	rot_y.value_changed.connect(_on_transform_changed)
	rot_z.value_changed.connect(_on_transform_changed)
	scale_x.value_changed.connect(_on_transform_changed)
	scale_y.value_changed.connect(_on_transform_changed)
	scale_z.value_changed.connect(_on_transform_changed)
	color_picker.color_changed.connect(_on_color_changed)
	anchored_check.toggled.connect(_on_anchored_toggled)
	
	clear_inspector()

func inspect_node(node: Node3D) -> void:
	selected_node = node
	if not selected_node:
		clear_inspector()
		return
		
	is_updating_ui = true
	visible = true
	name_input.text = selected_node.name
	
	pos_x.value = selected_node.position.x
	pos_y.value = selected_node.position.y
	pos_z.value = selected_node.position.z
	
	rot_x.value = selected_node.rotation_degrees.x
	rot_y.value = selected_node.rotation_degrees.y
	rot_z.value = selected_node.rotation_degrees.z
	
	scale_x.value = selected_node.scale.x
	scale_y.value = selected_node.scale.y
	scale_z.value = selected_node.scale.z
	
	if selected_node.has_node("MeshInstance3D"):
		var mesh_inst: MeshInstance3D = selected_node.get_node("MeshInstance3D")
		if mesh_inst.material_override is StandardMaterial3D:
			color_picker.color = (mesh_inst.material_override as StandardMaterial3D).albedo_color
			
	if selected_node is RigidBody3D:
		anchored_check.button_pressed = (selected_node as RigidBody3D).freeze
		
	is_updating_ui = false

func clear_inspector() -> void:
	selected_node = null
	name_input.text = ""
	pos_x.value = 0; pos_y.value = 0; pos_z.value = 0
	rot_x.value = 0; rot_y.value = 0; rot_z.value = 0
	scale_x.value = 1; scale_y.value = 1; scale_z.value = 1

func _on_name_submitted(new_name: String) -> void:
	if selected_node and not is_updating_ui:
		selected_node.name = new_name.strip_edges()
		property_changed.emit(selected_node, "name", new_name)

func _on_transform_changed(_val: float) -> void:
	if selected_node and not is_updating_ui:
		selected_node.position = Vector3(pos_x.value, pos_y.value, pos_z.value)
		selected_node.rotation_degrees = Vector3(rot_x.value, rot_y.value, rot_z.value)
		selected_node.scale = Vector3(scale_x.value, scale_y.value, scale_z.value)
		property_changed.emit(selected_node, "transform", selected_node.transform)

func _on_color_changed(color: Color) -> void:
	if selected_node and not is_updating_ui:
		if selected_node.has_node("MeshInstance3D"):
			var mesh_inst: MeshInstance3D = selected_node.get_node("MeshInstance3D")
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mesh_inst.material_override = mat
			property_changed.emit(selected_node, "color", color)

func _on_anchored_toggled(pressed: bool) -> void:
	if selected_node and not is_updating_ui:
		if selected_node is RigidBody3D:
			(selected_node as RigidBody3D).freeze = pressed
			selected_node.set_meta("anchored", pressed)
			property_changed.emit(selected_node, "anchored", pressed)
