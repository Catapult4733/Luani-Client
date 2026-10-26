extends RefCounted
## Body facing is distinct from camera/tool aim. Pure math, shared by prediction/server.
static func target(move: Vector2, aim: float, locked: bool, previous: float) -> float:
	if locked: return wrapf(aim, -PI, PI)
	if move.length_squared() > 0.01: return atan2(-move.x, -move.y)
	return previous

static func rate(locked: bool) -> float:
	return 16.0 if locked else 12.0
