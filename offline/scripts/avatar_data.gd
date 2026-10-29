class_name LuaniAvatarData
extends RefCounted
## Rendering-only normalization. Ownership and saves are enforced by SQL.
const DEFINITION_PATH := "res://assets/avatar/definition.json"
static var _definition: Dictionary = {}

static func definition() -> Dictionary:
	if not _definition.is_empty(): return _definition
	var file := FileAccess.open(DEFINITION_PATH, FileAccess.READ)
	if file == null:
		push_error("Luani avatar definition is missing from this build.")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("parts") is Array or parsed.parts.size() != 6 or not parsed.get("catalog") is Array:
		push_error("Luani avatar definition is invalid.")
		return {}
	_definition = parsed
	return _definition

static func _colour(value: Variant, fallback: String) -> String:
	if not value is String or value.length() != 6: return fallback
	for character: String in value.to_lower():
		if not character in "0123456789abcdef": return fallback
	return value.to_lower()

static func vector_valid(value: Variant, limit: float) -> bool:
	if not value is Array or value.size() != 3: return false
	for component: Variant in value:
		if not (component is int or component is float) or not is_finite(float(component)) or absf(float(component)) > limit: return false
	return true

static func rounded_vector(value: Array) -> Array:
	var result: Array = []
	for component: Variant in value: result.append(snappedf(float(component), 0.001))
	return result

static func revision(value: Dictionary) -> int:
	var number: Variant = value.get("revision", 0)
	if not (number is int or number is float) or not is_finite(float(number)) or float(number) < 0.0 or float(number) > 9007199254740991.0 or floorf(float(number)) != float(number): return 0
	return int(number)

static func catalog_item(id: String) -> Dictionary:
	for item: Dictionary in definition().get("catalog", []):
		if item.id == id: return item
	return {}

static func normalize(value: Dictionary) -> Dictionary:
	var spec: Dictionary = definition()
	var input_colours: Variant = value.get("colors", {})
	if not input_colours is Dictionary: input_colours = {}
	var colours: Dictionary = {}
	for part: Dictionary in spec.get("parts", []):
		colours[part.id] = _colour(input_colours.get(part.id), _colour(value.get(part.legacy), str(part.color)))
	var accessories: Array = []
	var seen: Dictionary = {}
	var input_items: Variant = value.get("accessories", [])
	if input_items is Array:
		for raw: Variant in input_items.slice(0, int(spec.get("maxAccessories", 6))):
			if not raw is Dictionary or not raw.get("id") is String: continue
			var id: String = raw.id
			if seen.has(id) or catalog_item(id).is_empty() or not vector_valid(raw.get("position"), float(spec.get("positionLimit", 2))) or not vector_valid(raw.get("rotation"), float(spec.get("rotationLimit", 180))): continue
			seen[id] = true
			accessories.append({"id":id, "position":rounded_vector(raw.position), "rotation":rounded_vector(raw.rotation)})
	return {"schema":2, "revision":revision(value), "colors":colours, "accent":_colour(value.get("accent"), str(spec.get("defaultAccent", "c1adff"))), "accessories":accessories}
