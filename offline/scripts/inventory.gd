extends RefCounted
## Session state, independent of scene nodes. Runtime contracts live in tests/test_inventory.gd.
signal changed
signal equipped_changed(item_id: String)
const Catalog = preload("res://scripts/item_catalog.gd")
const CAPACITY := 18
const HOTBAR_SIZE := 9
var _slots: Array[Dictionary] = []
var equipped_slot: int = -1

func _init() -> void:
	for index in range(CAPACITY):
		_slots.append({})

func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= CAPACITY:
		return {}
	return _slots[index].duplicate(true)

func occupied_count() -> int:
	var count := 0
	for slot in _slots:
		if not slot.is_empty():
			count += 1
	return count

func add_item(id: String, quantity: int = 1) -> bool:
	if not Catalog.has_item(id) or quantity < 1 or quantity > CAPACITY - occupied_count():
		return false
	# Durable tools each occupy one slot. Capacity is checked before any mutation.
	var remaining := quantity
	for index in range(CAPACITY):
		if _slots[index].is_empty():
			_slots[index] = {"id": id, "count": 1}
			remaining -= 1
			if remaining == 0:
				break
	changed.emit()
	return true

func equip(index: int) -> bool:
	if get_slot(index).is_empty():
		return false
	equipped_slot = -1 if equipped_slot == index else index
	equipped_changed.emit(equipped_id())
	changed.emit()
	return true

func unequip() -> void:
	if equipped_slot == -1:
		return
	equipped_slot = -1
	equipped_changed.emit("")
	changed.emit()

func equipped_id() -> String:
	return str(get_slot(equipped_slot).get("id", ""))

func remove_slot(index: int) -> Dictionary:
	var result := get_slot(index)
	if result.is_empty():
		return {}
	_slots[index] = {}
	if equipped_slot == index:
		equipped_slot = -1
		equipped_changed.emit("")
	changed.emit()
	return result
