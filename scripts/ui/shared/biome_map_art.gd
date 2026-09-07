extends RefCounted
## Stateless map illustration kit. Callers own chapter geometry and progression.
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")
const Landmarks = preload("res://scripts/rendering/terrain/map_landmark_art.gd")
const Nature = preload("res://scripts/rendering/terrain/map_nature_art.gd")

static func curve(from: Vector2, to: Vector2, departure: Vector2 = Vector2.INF, arrival: Vector2 = Vector2.INF) -> PackedVector2Array:
	var bend := (to.y - from.y) * 0.55
	if departure == Vector2.INF: departure = from + Vector2(0, bend)
	if arrival == Vector2.INF: arrival = to - Vector2(0, bend)
	var points := PackedVector2Array()
	for step in range(33):
		points.append(from.bezier_interpolate(departure, arrival, to, step / 32.0))
	return points

static func trail(canvas: CanvasItem, points: PackedVector2Array, completed: bool) -> void:
	canvas.draw_polyline(points, Art.INK, 10 + UI.OUTLINE * 2, true)
	canvas.draw_polyline(points, Art.GOLD if completed else Art.ROAD, 10, true)
	# Worn stepping stones follow the real curve and never change its hit areas.
	var travelled := 0.0
	for i in range(1,points.size()):
		travelled += points[i-1].distance_to(points[i])
		if travelled < 22: continue
		travelled = 0
		var across := (points[i]-points[i-1]).normalized().orthogonal()*3.2
		canvas.draw_line(points[i]-across,points[i]+across,Color("a4977d"),1.1,true)

static func between_markers(from: Vector2, to: Vector2) -> PackedVector2Array:
	# Full-height tangents make broad S bends while clearing labels at each end.
	var tangent := Vector2(0, to.y - from.y)
	return curve(from, to, from + tangent, to - tangent)

static func clear_site(rect: Rect2, bounds: Rect2, reserved: Array[Rect2], roads: Array[PackedVector2Array]) -> bool:
	if not bounds.grow(-5).encloses(rect): return false
	for occupied in reserved:
		if occupied.grow(7).intersects(rect): return false
	for road in roads:
		for point in road:
			if rect.grow(12).has_point(point): return false
	return true

static func layout(profile: Dictionary, bounds: Rect2, reserved: Array[Rect2], roads: Array[PackedVector2Array], seed_value: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if profile.is_empty(): return result
	var occupied: Array[Rect2] = reserved.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Put architecture first. The deterministic search can reflow each recipe at
	# narrow phone widths while checking the full drawn extent, not its center.
	for index in range(profile.landmarks.size()):
		var target := bounds.position+Vector2(bounds.size.x*[0.27,0.73,0.25,0.48][index%4],205+index*192)
		var best := Rect2()
		var score := INF
		for width in [126.0,108.0,90.0]:
			var extent := Vector2(width,width*0.9)
			for y in range(int(bounds.position.y)+136,int(bounds.end.y-extent.y),8):
				for x in range(8,int(bounds.end.x-extent.x),12):
					var rect := Rect2(Vector2(x,y),extent)
					var distance := rect.get_center().distance_to(target)
					if distance>=score or not clear_site(rect,bounds,occupied,roads): continue
					if distance<score:
						score=distance
						best=rect
			if best.has_area(): break
		if best.has_area():
			result.append({"kind":profile.landmarks[index],"rect":best,"major":true})
			occupied.append(best)
	for attempt in range(420):
		if result.size()>=int(bounds.size.x/10): break
		var width := rng.randf_range(48,88)
		var rect := Rect2(Vector2(rng.randf_range(5,bounds.size.x-width-5),rng.randf_range(bounds.position.y+132,bounds.end.y-width*0.9-5)),Vector2(width,width*0.9))
		if not clear_site(rect,bounds,occupied,roads): continue
		var kind: String = profile.scenery[attempt%profile.scenery.size()]
		result.append({"kind":kind,"rect":rect,"major":false})
		occupied.append(rect.grow(-2))
	result.sort_custom(func(a,b):return a.rect.end.y<b.rect.end.y)
	return result

static func landscape(canvas: CanvasItem, profile: Dictionary, sites: Array[Dictionary]) -> void:
	for site in sites:
		if site.major or site.kind=="ruins": Landmarks.draw(canvas,site.kind,site.rect,profile)
		else: Nature.draw(canvas,site.kind,site.rect,profile)
