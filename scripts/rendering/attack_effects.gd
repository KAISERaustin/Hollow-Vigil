extends RefCounted

# Cosmetic snapshots only: no enemy references, damage, or delayed transactions.
static func shot(kind: String, origin: Vector2, target: Vector2, stats: Dictionary) -> Dictionary:
	var muzzle := origin + Vector2(0, -25)
	var speed := 760.0
	var min_flight := 0.10
	var max_flight := 0.22
	var impact_time := 0.09
	match kind:
		"heavy":
			muzzle = origin + Vector2(0, -22)
			speed = 470.0
			min_flight = 0.18
			max_flight = 0.36
			impact_time = 0.18
		"splash":
			muzzle = origin + Vector2(0, -29)
			speed = 520.0
			min_flight = 0.17
			max_flight = 0.30
			impact_time = 0.24
	var flight := clampf(muzzle.distance_to(target) / speed, min_flight, max_flight)
	return {"kind": "shot", "tower_kind": kind, "from": muzzle, "pos": target,
		"flight": flight, "life": flight + impact_time, "max_life": flight + impact_time,
		"color": stats.color, "radius": stats.splash}

static func draw(canvas: CanvasItem, fx: Dictionary, origin: Vector2, target: Vector2, zoom: float, offset: float = 0.0) -> void:
	var age := clampf(fx.max_life - fx.life + offset, 0.0, fx.max_life)
	if age >= fx.max_life:
		return
	var color := Color(fx.color)
	var direction := origin.angle_to_point(target)
	if age < fx.flight:
		var progress: float = age / fx.flight
		canvas.draw_set_transform(origin.lerp(target, progress), direction, Vector2.ONE * zoom)
		match fx.tower_kind:
			"heavy":
				VigilTerrainArt.disk(canvas, Vector2.ZERO, 11.5, color, 2.3)
				canvas.draw_arc(Vector2.ZERO, 7.5, -1.2, 1.2, 16, VigilTerrainArt.PAPER, 2.5, true)
				canvas.draw_circle(Vector2(-2, -2), 3.0, VigilTerrainArt.PAPER)
			"splash":
				flame_wave(canvas, 13.0 + progress * 6.0, color)
			"rapid":
				# Pointed head, narrow shaft, and tail fins form a compact dart.
				VigilTerrainArt.polygon(canvas, PackedVector2Array([
					Vector2(10, 0), Vector2(1, -3.5), Vector2(1, -1.4),
					Vector2(-6, -1.4), Vector2(-10, -4), Vector2(-8, 0),
					Vector2(-10, 4), Vector2(-6, 1.4), Vector2(1, 1.4), Vector2(1, 3.5)
				]), color, 1.3)
			_:
				VigilTerrainArt.disk(canvas, Vector2.ZERO, 5.0, color, 1.5)
	else:
		var progress: float = (age - fx.flight) / (fx.max_life - fx.flight)
		canvas.draw_set_transform(target, direction, Vector2.ONE * zoom)
		match fx.tower_kind:
			"heavy":
				var radius := 11.5 + progress * 12.0
				canvas.draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.BLACK, 3.2 * (1.0 - progress), true)
				canvas.draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color, 1.8 * (1.0 - progress), true)
				canvas.draw_circle(Vector2.ZERO, 7.0 * (1.0 - progress), color)
			"splash":
				# A brief lobed flame ring shows the existing splash radius.
				var radius: float = fx.radius * (0.35 + progress * 0.65)
				var edge := PackedVector2Array()
				for i in range(65):
					var angle := TAU * i / 64.0
					edge.append(Vector2.from_angle(angle) * radius * (0.92 + 0.08 * cos(angle * 8.0)))
				canvas.draw_polyline(edge, Color.BLACK, 5.0 * (1.0 - progress), true)
				canvas.draw_polyline(edge, color, 3.0 * (1.0 - progress), true)
				canvas.draw_arc(Vector2.ZERO, radius * 0.66, 0, TAU, 32, VigilTerrainArt.GOLD, 2.0 * (1.0 - progress), true)
			_:
				var radius := 4.0 * (1.0 - progress)
				VigilTerrainArt.polygon(canvas, PackedVector2Array([
					Vector2(radius, 0), Vector2(0, -radius), Vector2(-radius, 0), Vector2(0, radius)
				]), color, 1.0)
	canvas.draw_set_transform(Vector2.ZERO)

static func flame_wave(canvas: CanvasItem, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var angle := lerpf(-1.25, 1.25, i / 24.0)
		var reach := radius + 2.5 * cos(angle * 10.0)
		points.append(Vector2.from_angle(angle) * reach - Vector2(radius * 0.55, 0))
	for i in range(24, -1, -1):
		var angle := lerpf(-1.25, 1.25, i / 24.0)
		points.append(Vector2.from_angle(angle) * (radius - 5.0) - Vector2(radius * 0.55, 0))
	VigilTerrainArt.polygon(canvas, points, color, 1.8)
	canvas.draw_arc(Vector2(-radius * 0.55, 0), radius - 2.8, -1.15, 1.15, 24, VigilTerrainArt.GOLD, 2.0, true)
