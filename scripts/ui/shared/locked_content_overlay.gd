extends Control
## Passive seal for locked illustrated content; availability belongs to its owner.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Emblem = preload("res://scripts/ui/shared/locked_emblem.gd")
var emblem: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	emblem = Emblem.new()
	emblem.name = "Padlock"
	emblem.size = Vector2(36, 40)
	add_child(emblem)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var zoom := clampf(size.y * 0.72 / 40.0, 0.65, 1.65)
	emblem.scale = Vector2.ONE * zoom
	emblem.position = (size - Vector2(36, 40) * zoom) * 0.5
	queue_redraw()

func _draw() -> void:
	# Open iron links cross the portrait, leaving the tower silhouette visible.
	for direction in [-1.0, 1.0]:
		var start := Vector2(5, size.y * (0.22 if direction > 0 else 0.78))
		var finish := Vector2(size.x - 5, size.y * (0.78 if direction > 0 else 0.22))
		var delta := finish - start
		var count := maxi(3, int(delta.length() / 10.0))
		var axis := delta.normalized()
		var normal := axis.orthogonal()
		for index in count + 1:
			var at := start.lerp(finish, float(index) / count)
			var link := PackedVector2Array()
			for point in [Vector2(-6,-1), Vector2(-4,-3), Vector2(4,-3), Vector2(6,-1), Vector2(6,1), Vector2(4,3), Vector2(-4,3), Vector2(-6,1), Vector2(-6,-1)]:
				link.append(at + axis * point.x + normal * point.y)
			draw_polyline(link, UI.BORDER, 4.0, true)
			draw_polyline(link, UI.MUTED, 2.0, true)
