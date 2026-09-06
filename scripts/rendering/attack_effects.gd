extends RefCounted

# Combat uses this flight duration to resolve damage when the visual arrives.
# Target identities track centers without retaining pooled enemy dictionaries.
static func shot(kind: String, origin: Vector2, target: Vector2, stats: Dictionary, target_id: int = -1) -> Dictionary:
	var muzzle := origin + Vector2(0, -25)
	var speed := 760.0
	var min_flight := 0.10
	var max_flight := 0.22
	var impact_time := 0.09
	match kind:
		"electric":
			muzzle = origin + Vector2(0, -29)
			min_flight = 0.0
			max_flight = 0.0
			impact_time = 0.30
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
	return {"kind": "shot", "tower_kind": kind, "from": muzzle, "pos": target, "target_id": target_id,
		"flight": flight, "life": flight + impact_time, "max_life": flight + impact_time,
		"color": stats.color, "radius": stats.splash}

static func draw(canvas: CanvasItem, fx: Dictionary, origin: Vector2, target: Vector2, zoom: float, offset: float = 0.0) -> void:
	var age := clampf(fx.max_life - fx.life + offset, 0.0, fx.max_life)
	if age >= fx.max_life:
		return
	var color := Color(fx.color)
	if fx.tower_kind == "electric":
		lightning(canvas, origin, target, zoom, age, fx.max_life, color)
		return
	var direction := origin.angle_to_point(target)
	# Match Stormspire's colored aura / saturated body / paper-white core.
	# All extra marks are drawn inside the existing bounded cosmetic effect.
	var launch := maxf(0.0, 1.0 - age / 0.10)
	if launch > 0.0:
		canvas.draw_circle(origin, (5.0 + age * 80.0) * zoom, Color(color, launch * 0.22))
		canvas.draw_arc(origin, (3.0 + age * 60.0) * zoom, 0, TAU, 20, Color(color, launch), 1.5 * zoom, true)
	if age < fx.flight:
		var progress: float = age / fx.flight
		var center := origin.lerp(target, progress)
		if fx.get("fragment", false):
			center += (target-origin).normalized().orthogonal() * sin(progress*PI) * 22.0 * zoom * fx.get("curve", 1.0)
		canvas.draw_set_transform(center, direction, Vector2.ONE * zoom * (0.5 if fx.get("fragment", false) else 1.0))
		var travel: float = origin.distance_to(target) / maxf(zoom, 0.01) * progress
		wake(canvas, fx.tower_kind, minf(travel, 58.0 if fx.tower_kind == "heavy" else 44.0), age, color)
		match fx.tower_kind:
			"heavy":
				if fx.get("fragment", false):
					canvas.draw_circle(Vector2.ZERO, 13.0, Color(color, 0.16))
					VigilTerrainArt.polygon(canvas, PackedVector2Array([Vector2(13,0),Vector2(-3,-6),Vector2(-9,0),Vector2(-3,6)]),color,2.0)
					canvas.draw_line(Vector2(-5,0),Vector2(10,0),VigilTerrainArt.PAPER,2.0,true)
					canvas.draw_set_transform(Vector2.ZERO)
					return
				canvas.draw_circle(Vector2.ZERO, 17.0, Color(color, 0.14))
				canvas.draw_circle(Vector2.ZERO, 12.0, Color(color, 0.34))
				canvas.draw_circle(Vector2.ZERO, 8.5, color)
				canvas.draw_circle(Vector2(1, 0), 4.5, VigilTerrainArt.PAPER)
				for index in range(3):
					var angle := age * 13.0 + index * TAU / 3.0
					canvas.draw_arc(Vector2.ZERO, 12.5, angle, angle + 0.95, 12, Color(VigilTerrainArt.PAPER, 0.85), 1.3, true)
					var rune := Vector2.from_angle(angle) * 15.0
					canvas.draw_line(rune, rune + Vector2.from_angle(angle + 0.6) * 3.5, color, 2.0, true)
			"splash":
				canvas.draw_circle(Vector2.ZERO, 19.0, Color(color, 0.13))
				flame_wave(canvas, 13.0 + progress * 6.0, color)
				flame_wave(canvas, 8.0 + progress * 4.0, VigilTerrainArt.GOLD)
				canvas.draw_arc(Vector2(-5, 0), 11.0, -0.8, 0.8, 16, VigilTerrainArt.PAPER, 2.2, true)
			"rapid":
				canvas.draw_line(Vector2(-12, 0), Vector2(10, 0), Color(color, 0.22), 9.0, true)
				# Pointed head, narrow shaft, and tail fins form a compact dart.
				VigilTerrainArt.polygon(canvas, PackedVector2Array([
					Vector2(10, 0), Vector2(1, -3.5), Vector2(1, -1.4),
					Vector2(-6, -1.4), Vector2(-10, -4), Vector2(-8, 0),
					Vector2(-10, 4), Vector2(-6, 1.4), Vector2(1, 1.4), Vector2(1, 3.5)
				]), color, 1.3)
				canvas.draw_line(Vector2(-6, 0), Vector2(8, 0), VigilTerrainArt.PAPER, 1.4, true)
			_:
				VigilTerrainArt.disk(canvas, Vector2.ZERO, 5.0, color, 1.5)
	else:
		var progress: float = (age - fx.flight) / (fx.max_life - fx.flight)
		canvas.draw_set_transform(target, direction, Vector2.ONE * zoom)
		match fx.tower_kind:
			"heavy":
				var radius := 9.0 + progress * 21.0
				canvas.draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(color, 0.18 * (1.0 - progress)), 7.0, true)
				canvas.draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(color, 1.0 - progress), 2.0, true)
				canvas.draw_arc(Vector2.ZERO, radius * 0.72, -progress * 3.0, PI - progress * 3.0, 24, Color(VigilTerrainArt.PAPER, 1.0 - progress), 1.4, true)
				burst(canvas, progress, 7, 27.0, color)
				canvas.draw_circle(Vector2.ZERO, 8.0 * (1.0 - progress), Color(VigilTerrainArt.PAPER, 1.0 - progress))
			"splash":
				if fx.get("branch", "") == "rupture_pyre":
					canvas.draw_arc(Vector2.ZERO,fx.radius*progress,0,TAU,48,Color(color,1.0-progress),6.0*(1.0-progress)+1.0,true)
				# A brief lobed flame ring shows the existing splash radius.
				var radius: float = fx.radius * (0.35 + progress * 0.65)
				var edge := PackedVector2Array()
				for i in range(65):
					var angle := TAU * i / 64.0
					edge.append(Vector2.from_angle(angle) * radius * (0.92 + 0.08 * cos(angle * 8.0)))
				canvas.draw_polyline(edge, Color(color, 0.18 * (1.0 - progress)), 9.0, true)
				canvas.draw_polyline(edge, Color(color, 1.0 - progress), 3.0, true)
				canvas.draw_arc(Vector2.ZERO, radius * 0.82, 0, TAU, 40, Color(VigilTerrainArt.GOLD, 1.0 - progress), 2.0, true)
				canvas.draw_circle(Vector2.ZERO, 12.0 * (1.0 - progress), Color(VigilTerrainArt.PAPER, 0.85 * (1.0 - progress)))
				burst(canvas, progress, 10, fx.radius, VigilTerrainArt.GOLD)
			"rapid":
				burst(canvas, progress, 5, 16.0, color)
				canvas.draw_line(Vector2(-8, 0) * (1.0 - progress), Vector2(11, 0) * (1.0 - progress), Color(VigilTerrainArt.PAPER, 1.0 - progress), 2.0, true)
			_:
				var radius := 4.0 * (1.0 - progress)
				VigilTerrainArt.polygon(canvas, PackedVector2Array([
					Vector2(radius, 0), Vector2(0, -radius), Vector2(-radius, 0), Vector2(0, radius)
				]), color, 1.0)
	canvas.draw_set_transform(Vector2.ZERO)

static func wake(canvas: CanvasItem, kind: String, length: float, age: float, color: Color) -> void:
	if length < 1.0:
		return
	var width := 6.0 if kind == "heavy" else (7.0 if kind == "splash" else 4.0)
	for strand in range(3 if kind != "rapid" else 1):
		var points := PackedVector2Array()
		for index in range(9):
			var fraction := index / 8.0
			var ripple := sin(fraction * 7.0 - age * 28.0 + strand * 2.1) * width * fraction
			points.append(Vector2(-length * fraction, ripple if kind != "rapid" else 0.0))
		canvas.draw_polyline(points, Color(color, 0.10), width + 6.0, true)
		# Segmented falloff keeps the tail soft without a shader or particle nodes.
		for index in range(8):
			var fade := 1.0 - index / 8.0
			canvas.draw_line(points[index], points[index + 1], Color(color, fade * 0.65), maxf(0.6, width * fade * 0.55), true)
			if kind == "rapid":
				canvas.draw_line(points[index], points[index + 1], Color(VigilTerrainArt.PAPER, fade * 0.7), maxf(0.5, fade), true)
		canvas.draw_line(points[0], points[2], Color(VigilTerrainArt.PAPER, 0.8), 1.2, true)
	if kind == "splash":
		for index in range(5):
			var fraction := fposmod(age * 3.0 + index * 0.21, 1.0)
			var ember := Vector2(-length * fraction, sin(index * 12.3) * (5.0 + fraction * 10.0))
			canvas.draw_circle(ember, 1.8 * (1.0 - fraction), Color(VigilTerrainArt.GOLD, 1.0 - fraction))

static func burst(canvas: CanvasItem, progress: float, count: int, reach: float, color: Color) -> void:
	var fade := 1.0 - progress
	for index in range(count):
		var angle := index * TAU / count + sin(index * 7.1) * 0.2
		var direction := Vector2.from_angle(angle)
		var distance := reach * (0.22 + progress * 0.68) * (0.8 + 0.2 * sin(index * 4.7))
		var start := direction * distance
		var end := direction * (distance + 6.0 * fade)
		canvas.draw_line(start, end, Color(color, fade * 0.2), 5.0, true)
		canvas.draw_line(start, end, Color(color, fade), 2.0, true)
		canvas.draw_circle(end, 1.1 * fade, Color(VigilTerrainArt.PAPER, fade))

static func lightning(canvas: CanvasItem, origin: Vector2, target: Vector2, zoom: float, age: float, duration: float, color: Color) -> void:
	# Screen-space endpoints match the battlefield's interpolated enemy centers.
	var points := PackedVector2Array([origin])
	var normal := (target - origin).normalized().orthogonal()
	var frame := floorf(age * 30.0)
	var fade := 1.0 - age / duration
	for index in range(1, 9):
		var fraction := index / 9.0
		var jitter := sin(index * 17.13 + frame * 9.7 + target.x * 0.13 + target.y * 0.21)
		points.append(origin.lerp(target, fraction) + normal * jitter * 10.0 * zoom)
	points.append(target)
	canvas.draw_polyline(points, Color(color, fade * 0.22), 9.0 * zoom, true)
	canvas.draw_polyline(points, Color(color, fade), 3.0 * zoom, true)
	canvas.draw_polyline(points, Color(VigilTerrainArt.PAPER, fade), 1.2 * zoom, true)
	for index in [3, 6]:
		var branch := PackedVector2Array([points[index], points[index] + normal * 10.0 * zoom, points[index] + normal * 15.0 * zoom + (target - origin).normalized() * 8.0 * zoom])
		canvas.draw_polyline(branch, Color(color, fade * 0.8), 1.5 * zoom, true)
	canvas.draw_circle(target, 4.0 * zoom * fade, Color(color, fade))

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
