# client_and_studio/scripts/core/inventory_manager.gd
extends Node

## Inventory & Hotbar System Manager handling item slots, equipping, dropping, and pickup

signal slot_selected(slot_index: int, item_data: Dictionary)
signal inventory_changed(slots: Array)
signal item_dropped(item_data: Dictionary, global_pos: Vector3)

const MAX_SLOTS: int = 6

var slots: Array = []
var active_slot_index: int = 0

func _ready() -> void:
	_init_default_inventory()

func _init_default_inventory() -> void:
	slots.clear()
	slots.append({ "id": "sword", "name": "⚔️ Sword", "type": "weapon", "icon": "⚔️", "count": 1, "scene": "res://scenes/weapons/sword.tscn" })
	slots.append({ "id": "axe", "name": "🪓 Axe", "type": "tool", "icon": "🪓", "count": 1, "scene": "res://scenes/weapons/sword.tscn" })
	slots.append({ "id": "pickaxe", "name": "⛏️ Pickaxe", "type": "tool", "icon": "⛏️", "count": 1, "scene": "res://scenes/weapons/sword.tscn" })
	slots.append({ "id": "block", "name": "🧱 Block", "type": "build", "icon": "🧱", "count": 5, "scene": "" })
	slots.append({ "id": "apple", "name": "🍎 Apple", "type": "item", "icon": "🍎", "count": 3, "scene": "" })
	slots.append({ "id": "potion", "name": "🧪 Potion", "type": "item", "icon": "🧪", "count": 1, "scene": "" })
	inventory_changed.emit(slots)

func select_slot(index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	active_slot_index = index
	var active_item: Dictionary = slots[active_slot_index]
	print("[Luani Inventory] Selected Hotbar Slot ", active_slot_index + 1, ": ", active_item.get("name", "Empty"))
	slot_selected.emit(active_slot_index, active_item)

func get_active_item() -> Dictionary:
	if active_slot_index >= 0 and active_slot_index < slots.size():
		return slots[active_slot_index]
	return {}

func add_item(item_data: Dictionary) -> bool:
	# Try stacking
	var item_id: String = item_data.get("id", "")
	for i in range(slots.size()):
		if slots[i].get("id", "") == item_id and slots[i].get("id", "") != "":
			slots[i]["count"] = slots[i].get("count", 1) + item_data.get("count", 1)
			inventory_changed.emit(slots)
			if i == active_slot_index:
				slot_selected.emit(active_slot_index, slots[active_slot_index])
			return true

	# Find empty slot
	for i in range(slots.size()):
		if slots[i].get("id", "") == "" or slots[i].get("id", "") == "empty":
			slots[i] = item_data.duplicate()
			inventory_changed.emit(slots)
			if i == active_slot_index:
				slot_selected.emit(active_slot_index, slots[active_slot_index])
			return true

	return false

func drop_active_item(drop_pos: Vector3) -> Dictionary:
	var item: Dictionary = get_active_item()
	if item.is_empty() or item.get("id", "") == "":
		return {}

	var dropped := item.duplicate()
	dropped["count"] = 1

	if item.get("count", 1) > 1:
		slots[active_slot_index]["count"] -= 1
	else:
		slots[active_slot_index] = { "id": "", "name": "Empty", "type": "empty", "icon": "❌", "count": 0, "scene": "" }

	inventory_changed.emit(slots)
	slot_selected.emit(active_slot_index, slots[active_slot_index])
	item_dropped.emit(dropped, drop_pos)
	print("[Luani Inventory] Dropped item: ", dropped.get("name", ""), " at ", drop_pos)
	return dropped
