# client_and_studio/scenes/ui/hotbar_overlay.gd
extends CanvasLayer

## Hotbar Inventory UI displaying equipped tools (Slot 1: Sword)

@onready var slot1_panel: PanelContainer = %Slot1Panel
@onready var slot1_label: Label = %Slot1Label

var is_sword_equipped: bool = false

signal sword_equip_toggled(equipped: bool)

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		hide()
		return

	_update_slot_style()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_1:
			toggle_sword_equip()
			get_viewport().set_input_as_handled()

func toggle_sword_equip() -> void:
	is_sword_equipped = not is_sword_equipped
	_update_slot_style()
	sword_equip_toggled.emit(is_sword_equipped)

func _update_slot_style() -> void:
	if is_sword_equipped:
		slot1_panel.modulate = Color(1.2, 1.2, 1.2)
		slot1_label.text = "[ 1: ⚔️ Sword (Equipped) ]"
	else:
		slot1_panel.modulate = Color(0.8, 0.8, 0.8, 0.8)
		slot1_label.text = "[ 1: ⚔️ Sword ]"
