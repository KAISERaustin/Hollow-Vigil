extends RefCounted

# Reusable presentation component. Each battlefield owns its own transition.
const DURATION := 0.4
var active := false
var origin := Vector2.ZERO
var target := Vector2.ZERO
var elapsed := 0.0
var origin_zoom := 1.0
var target_zoom := 1.0
var zoom := 1.0

static func correction(content: Rect2, available: Rect2) -> Vector2:
	var offset := Vector2.ZERO
	for axis in range(2):
		if content.size[axis] > available.size[axis]:
			# A pan cannot fit an oversized subject; center it without changing zoom.
			offset[axis] = content.get_center()[axis] - available.get_center()[axis]
		elif content.position[axis] < available.position[axis]:
			offset[axis] = content.position[axis] - available.position[axis]
		elif content.end[axis] > available.end[axis]:
			offset[axis] = content.end[axis] - available.end[axis]
	return offset

func begin(current: Vector2, destination: Vector2, current_zoom: float, destination_zoom: float) -> void:
	origin = current
	target = destination
	origin_zoom = current_zoom
	target_zoom = destination_zoom
	zoom = current_zoom
	elapsed = 0.0
	active = not current.is_equal_approx(destination) or not is_equal_approx(current_zoom, destination_zoom)

func cancel() -> void:
	active = false

func advance(delta: float) -> Vector2:
	elapsed = minf(DURATION, elapsed + maxf(0.0, delta))
	active = elapsed < DURATION
	var progress := smoothstep(0.0, DURATION, elapsed)
	zoom = lerpf(origin_zoom, target_zoom, progress)
	return origin.lerp(target, progress)
