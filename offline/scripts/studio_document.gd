extends RefCounted
signal changed
signal selection_changed
const Data = preload("res://scripts/studio_data.gd")
var world: Dictionary = Data.new_world()
var selected: String = ""
var serial: int = 0
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

func replace(document: Dictionary) -> String:
	var error: String = Data.validate(document)
	if not error.is_empty(): return error
	world = document.duplicate(true); selected = ""; serial += 1; _undo.clear(); _redo.clear(); changed.emit()
	return ""

func commit(document: Dictionary) -> String:
	var error: String = Data.validate(document)
	if not error.is_empty(): return error
	if document == world: return ""
	_undo.append(world.duplicate(true))
	if _undo.size() > 64: _undo.pop_front()
	_redo.clear(); world = document.duplicate(true); serial += 1
	if Data.by_id(world,selected).is_empty(): selected = ""
	changed.emit(); return ""

func select(id: String) -> void:
	selected = id if not Data.by_id(world,id).is_empty() else ""
	selection_changed.emit()

func undo() -> void:
	if _undo.is_empty(): return
	_redo.append(world.duplicate(true)); world = _undo.pop_back(); serial += 1
	if Data.by_id(world,selected).is_empty(): selected = ""
	changed.emit()

func redo() -> void:
	if _redo.is_empty(): return
	_undo.append(world.duplicate(true)); world = _redo.pop_back(); serial += 1; changed.emit()

func identifier() -> String:
	return Crypto.new().generate_random_bytes(12).hex_encode()

func insert(kind: String) -> String:
	var id: String = identifier()
	var parent: Variant = null
	var selection: Dictionary = Data.by_id(world,selected)
	if not selection.is_empty(): parent = selected if selection["class"] in ["Model","Folder"] else selection.parent
	var item: Dictionary = Data.make_instance(kind,id,parent)
	if item.is_empty(): return "Unsupported instance"
	if kind == "Weld":
		var parts: Array = world.objects.filter(func(x: Dictionary) -> bool: return x["class"] in ["Part","SpawnPoint"])
		if parts.size() < 2: return "Create two parts before inserting a Weld"
		item.properties.part0 = parts[0].id; item.properties.part1 = parts[1].id
	var candidate: Dictionary = world.duplicate(true); candidate.objects.append(item)
	var error: String = commit(candidate)
	if error.is_empty(): select(id)
	return error

func edit(id: String, key: String, value: Variant, property: bool = true) -> String:
	var candidate: Dictionary = world.duplicate(true); var item: Dictionary = Data.by_id(candidate,id)
	if item.is_empty(): return "Select an instance"
	if property: item.properties[key] = value
	else: item[key] = value
	return commit(candidate)

func remove_selected() -> void:
	if selected.is_empty(): return
	var removed: Dictionary = {selected:true}; var progress: bool = true
	while progress:
		progress = false
		for item: Dictionary in world.objects:
			if removed.has(item.parent) and not removed.has(item.id): removed[item.id] = true; progress = true
	var candidate: Dictionary = world.duplicate(true)
	candidate.objects = candidate.objects.filter(func(x: Dictionary) -> bool: return not removed.has(x.id) and not (x["class"] == "Weld" and (removed.has(x.properties.part0) or removed.has(x.properties.part1))))
	commit(candidate)

func duplicate_selected() -> String:
	if selected.is_empty(): return "Select an instance"
	var included: Dictionary = {selected:identifier()}; var progress: bool = true
	while progress:
		progress = false
		for item: Dictionary in world.objects:
			if included.has(item.parent) and not included.has(item.id): included[item.id] = identifier(); progress = true
	var candidate: Dictionary = world.duplicate(true)
	for source: Dictionary in world.objects:
		if not included.has(source.id): continue
		var item: Dictionary = source.duplicate(true); item.id = included[source.id]
		if source.id == selected: item.name = str(item.name).left(74) + " Copy"
		if included.has(item.parent): item.parent = included[item.parent]
		if item["class"] == "Weld":
			for key: String in ["part0","part1"]:
				if included.has(item.properties[key]): item.properties[key] = included[item.properties[key]]
		candidate.objects.append(item)
	var error: String = commit(candidate)
	if error.is_empty(): select(str(included[selected]))
	return error
