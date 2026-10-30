extends RefCounted
## Data-only Studio v1 schema. No ClassDB, ResourceLoader or creator code.
const REGISTRY_PATH := "res://studio/instances.json"

static func registry() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	return value if value is Dictionary else {}

static func make_instance(kind: String, id: String, parent: Variant = null) -> Dictionary:
	var spec: Dictionary = registry().get("classes", {})
	if not spec.has(kind): return {}
	var properties: Dictionary = {}
	for key: String in spec[kind]:
		var field: Array = spec[kind][key]
		var value: Variant = field.back()
		properties[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {"id":id,"class":kind,"name":kind,"parent":parent,"properties":properties}

static func new_world() -> Dictionary:
	var floor_object: Dictionary = make_instance("Part", "baseplate")
	floor_object.name = "Baseplate"
	floor_object.properties.position = [0, -0.5, 0]
	floor_object.properties.size = [120, 1, 120]
	floor_object.properties.color = "656b79"
	return {"schema":1,"objects":[floor_object,make_instance("SpawnPoint","spawn"),make_instance("DirectionalLight","sun")]}

static func _exact(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key: Variant in keys:
		if not value.has(key): return false
	return true

static func _identifier(value: Variant) -> bool:
	if not value is String or value.length() < 1 or value.length() > 64: return false
	for c: String in value:
		if not (c >= "a" and c <= "z" or c >= "A" and c <= "Z" or c >= "0" and c <= "9" or c in ["_", "-"]): return false
	return true

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func validate(document: Variant) -> String:
	if not _exact(document,["schema","objects"]) or document.schema != 1 or not document.objects is Array: return "Invalid Studio world"
	if document.objects.size() > 256 or JSON.stringify(document).to_utf8_buffer().size() > 262144: return "World is too large"
	var classes: Dictionary = registry().get("classes",{})
	var ids: Dictionary = {}
	var lights: int = 0
	var movable: int = 0
	for item: Variant in document.objects:
		if not _exact(item,["id","class","name","parent","properties"]) or not _identifier(item.id) or ids.has(item.id): return "Invalid or duplicate instance ID"
		if not item.name is String or item.name.strip_edges().is_empty() or item.name.length() > 80: return "Invalid instance name"
		for c: String in item.name:
			if c.unicode_at(0) < 32 or c.unicode_at(0) == 127: return "Invalid instance name"
		if not item.get("class") is String or not classes.has(item["class"]) or item.parent != null and not item.parent is String: return "Unsupported instance"
		var definitions: Dictionary = classes[item["class"]]
		if not _exact(item.properties,definitions.keys()): return "Invalid instance properties"
		for key: String in definitions:
			var spec: Array = definitions[key]
			var value: Variant = item.properties[key]
			match str(spec[0]):
				"vector":
					if not value is Array or value.size() != 3: return "Invalid " + key
					for n: Variant in value:
						if not _number(n,float(spec[1]),float(spec[2])): return "Invalid " + key
				"number":
					if not _number(value,float(spec[1]),float(spec[2])): return "Invalid " + key
				"boolean":
					if not value is bool: return "Invalid " + key
				"color":
					if not value is String or value.length() != 6: return "Invalid colour"
					for c: String in value:
						if not (c >= "0" and c <= "9" or c >= "a" and c <= "f"): return "Invalid colour"
				"enum":
					if not value in spec[1]: return "Invalid " + key
				"reference":
					if value != null and not _identifier(value): return "Invalid reference"
		if str(item["class"]).ends_with("Light"): lights += 1
		if item["class"] == "Part" and item.properties.anchored == false: movable += 1
		ids[item.id] = item
	if lights > 16: return "Too many lights"
	if movable > 64: return "Too many movable parts"
	for item: Dictionary in document.objects:
		var visited: Dictionary = {str(item.id):true}
		var ancestor: Variant = item.parent
		while ancestor != null:
			if not ids.has(ancestor) or not ids[ancestor]["class"] in ["Model","Folder"] or visited.has(ancestor) or visited.size() >= 32: return "Invalid instance hierarchy"
			visited[ancestor] = true
			ancestor = ids[ancestor].parent
		if item["class"] == "Weld":
			var p: Dictionary = item.properties
			if p.enabled and (p.part0 == null or p.part1 == null or p.part0 == p.part1): return "Select two different parts for the weld"
			for id: Variant in [p.part0,p.part1]:
				if id != null and (not ids.has(id) or not ids[id]["class"] in ["Part","SpawnPoint"]): return "Invalid weld target"
	return ""

static func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

static func equivalent(first: Dictionary, second: Dictionary) -> bool:
	# Godot's deep Variant equality distinguishes int/float containers even
	# though both represent the same JSON number on disk and over HTTPS.
	return JSON.parse_string(JSON.stringify(first)) == JSON.parse_string(JSON.stringify(second))

static func by_id(document: Dictionary, id: String) -> Dictionary:
	for item: Dictionary in document.objects:
		if item.id == id: return item
	return {}
