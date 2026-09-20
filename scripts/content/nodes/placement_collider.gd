@tool
extends Resource
## Immutable placement configuration, relative to a tower's ground anchor.
## Each tower owns a separate resource and a separate Shape2D subresource.
@export var shape: Shape2D
@export var offset := Vector2.ZERO
@export_range(-180.0, 180.0, 0.1) var rotation_degrees := 0.0

func valid() -> bool:
	if not offset.is_finite() or not is_finite(rotation_degrees): return false
	if shape is CircleShape2D:
		return is_finite(shape.radius) and shape.radius > 0.0
	if shape is RectangleShape2D:
		return shape.size.is_finite() and shape.size.x > 0.0 and shape.size.y > 0.0
	if shape is CapsuleShape2D:
		return is_finite(shape.radius) and is_finite(shape.height) and shape.radius > 0.0 and shape.height >= shape.radius * 2.0
	return false

func transform_at(point: Vector2) -> Transform2D:
	return Transform2D(deg_to_rad(rotation_degrees), point + offset)

func overlaps(point: Vector2, other: Resource, other_point: Vector2) -> bool:
	return shape.collide(transform_at(point), other.shape, other.transform_at(other_point))

func overlaps_shape(point: Vector2, other: Shape2D, other_transform: Transform2D) -> bool:
	return shape.collide(transform_at(point), other, other_transform)

func fits_bounds(point: Vector2, bounds: Rect2) -> bool:
	# Exact support extents for the supported shapes, including rotated capsules.
	var angle := deg_to_rad(rotation_degrees)
	var extent: Vector2
	if shape is CircleShape2D:
		extent = Vector2.ONE * shape.radius
	elif shape is CapsuleShape2D:
		extent = Vector2(absf(sin(angle)), absf(cos(angle))) * (shape.height * 0.5 - shape.radius) + Vector2.ONE * shape.radius
	else:
		var half: Vector2 = shape.size * 0.5
		extent = Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y, absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)
	var center := point + offset
	return center.x - extent.x >= bounds.position.x and center.y - extent.y >= bounds.position.y and center.x + extent.x < bounds.end.x and center.y + extent.y < bounds.end.y
