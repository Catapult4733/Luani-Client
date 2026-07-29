# client_and_studio/scenes/ui/hotbar_overlay.gd
extends CanvasLayer

## Responsive 6-Slot Hotbar UI supporting slot selection, touch controls, and item dropping

signal slot_changed(slot_index: int)
signal drop_pressed

@onready var slot_buttons: Array[Button] = [
	%Slot1Button,
	%Slot2Button,
	%Slot3Button,
	%Slot4Button,
	%Slot5Button,
	%Slot6Button
]
@onready var btn_drop: Button = %BtnDrop

var selected_index: int = 0
var slot_style_normal: StyleBoxFlat
var slot_style_selected: StyleBoxFlat

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		hide()
		return

	_setup_styles()
	_connect_slot_buttons()

	if btn_drop:
		btn_drop.pressed.connect(func(): drop_pressed.emit())

	# Connect to InventoryManager if autoloaded
	var inv := get_node_or_null("/root/InventoryManager")
	if inv:
		if inv.has_signal("inventory_changed"):
			inv.inventory_changed.connect(_on_inventory_changed)
		_on_inventory_changed(inv.slots)

	update_selected_slot(0)

func _setup_styles() -> void:
	slot_style_normal = StyleBoxFlat.new()
	slot_style_normal.bg_color = Color(0.08, 0.1, 0.16, 0.75)
	slot_style_normal.set_border_width_all(2)
	slot_style_normal.border_color = Color(1, 1, 1, 0.25)
	slot_style_normal.set_corner_radius_all(8)

	slot_style_selected = StyleBoxFlat.new()
	slot_style_selected.bg_color = Color(0.15, 0.35, 0.65, 0.9)
	slot_style_selected.set_border_width_all(3)
	slot_style_selected.border_color = Color(0.4, 0.8, 1, 1)
	slot_style_selected.set_corner_radius_all(8)

func _connect_slot_buttons() -> void:
	for i in range(slot_buttons.size()):
		var slot_idx: int = i
		var btn: Button = slot_buttons[i]
		if btn:
			btn.pressed.connect(func(): select_slot(slot_idx))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var slot_idx: int = int(event.keycode - KEY_1)
			select_slot(slot_idx)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Q:
			drop_pressed.emit()
			get_viewport().set_input_as_handled()

func select_slot(idx: int) -> void:
	if idx < 0 or idx >= slot_buttons.size():
		return
	selected_index = idx
	update_selected_slot(idx)
	slot_changed.emit(idx)

	var inv := get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("select_slot"):
		inv.select_slot(idx)

func update_selected_slot(idx: int) -> void:
	for i in range(slot_buttons.size()):
		var btn: Button = slot_buttons[i]
		if btn:
			if i == idx:
				btn.add_theme_stylebox_override("normal", slot_style_selected)
			else:
				btn.add_theme_stylebox_override("normal", slot_style_normal)

func _on_inventory_changed(slots_data: Array) -> void:
	for i in range(slot_buttons.size()):
		var btn: Button = slot_buttons[i]
		if btn and i < slots_data.size():
			var item: Dictionary = slots_data[i]
			var icon: String = item.get("icon", "❌")
			var count: int = item.get("count", 0)
			if count > 1:
				btn.text = str(i + 1) + ": " + icon + " (" + str(count) + ")"
			elif count == 1:
				btn.text = str(i + 1) + ": " + icon
			else:
				btn.text = str(i + 1) + ": empty"
