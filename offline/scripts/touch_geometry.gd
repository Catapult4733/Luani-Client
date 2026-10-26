extends RefCounted
## Logical touch units; the floating thumb can stretch while input stays speed-bounded.
const RADIUS := 80.0
static func stick_offset(point: Vector2, origin: Vector2, floating: bool) -> Vector2:
	var offset := point - origin
	return offset if floating else offset.limit_length(RADIUS)
static func movement(offset: Vector2) -> Vector2:
	return (offset / RADIUS).limit_length(1.0) if offset.length() > 8.0 else Vector2.ZERO
static func can_start(point: Vector2, screen: Vector2, floating: bool, fixed_origin: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, screen).has_point(point): return false
	return point.x < screen.x * 0.5 if floating else point.distance_to(fixed_origin) < 108.0
