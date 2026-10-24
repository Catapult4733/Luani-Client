extends RefCounted
## Session-local original items. There is no account, network, marketplace or economy.
const ITEMS := {
	"sword": {"name": "Moonsteel Sword", "description": "A practice sword. Click to swing at the wooden training targets.", "use": "Click to swing", "icon": "sword", "color": "c1adff"},
	"lantern": {"name": "Trail Lantern", "description": "A warm portable light. Click to switch it on or off.", "use": "Click to toggle light", "icon": "lantern", "color": "f0cd8d"},
	"spring_coil": {"name": "Spring Coil", "description": "Hold this spring to jump higher. Put it away to return to normal jumps.", "use": "Equip, then Space to jump higher", "icon": "spring_coil", "color": "b8dfcb"},
}

static func has_item(id: String) -> bool:
	return ITEMS.has(id)

static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {}).duplicate(true)

static func title(id: String) -> String:
	return str(ITEMS.get(id, {}).get("name", "Empty slot"))
