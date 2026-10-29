extends RefCounted
## Trusted HTTPS control snapshots only. User gameplay packets never call this.
const AvatarData = preload("res://scripts/avatar_data.gd")

static func apply_updates(peers: Dictionary, updates: Variant) -> Array[String]:
	var changed: Dictionary = {}
	var rooms: Array[String] = []
	if not updates is Array: return rooms
	for update: Variant in updates.slice(0, 16):
		if not update is Dictionary or not update.get("avatar") is Dictionary: continue
		var appearance: Dictionary = update.avatar
		var next_revision: int = AvatarData.revision(appearance)
		if next_revision < 1 or JSON.stringify(appearance).to_utf8_buffer().size() > 1200: continue
		for member: Dictionary in peers.values():
			if member.get("phase") != "admitted" or not member.get("profile") is Dictionary: continue
			var profile: Dictionary = member.profile
			if member.get("admission_id") != update.get("admission_id") or str(profile.get("public_id", "")) != str(update.get("public_id", "")): continue
			var current: Variant = profile.get("avatar", {})
			if not current is Dictionary or next_revision <= AvatarData.revision(current): continue
			profile["avatar"] = appearance.duplicate(true)
			changed[str(member.get("room", ""))] = true
	for room: String in changed: rooms.append(room)
	return rooms
