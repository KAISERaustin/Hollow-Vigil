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

static func waterway(bounds: Rect2) -> PackedVector2Array:
	var top := bounds.position.y
	return curve(Vector2(0,top+382),Vector2(bounds.end.x,top+464),Vector2(bounds.size.x*0.38,top+426),Vector2(bounds.size.x*0.64,top+401))

static func water(canvas: CanvasItem, points: PackedVector2Array, profile: Dictionary) -> void:
	if profile.is_empty(): return
	var fill := Color(profile.water)
	canvas.draw_polyline(points,Color(profile.stone).darkened(0.18),29,true)
	canvas.draw_polyline(points,Art.INK,22,true)
	canvas.draw_polyline(points,fill,18,true)
	for index in range(2,points.size()-2,4):
		var along := (points[index+1]-points[index-1]).normalized()
		canvas.draw_line(points[index]-along*7+Vector2(0,-3),points[index]+along*7+Vector2(0,-3),fill.lightened(0.28),1.3,true)

static func bridges(canvas: CanvasItem, roads: Array[PackedVector2Array], river: PackedVector2Array) -> void:
	for road in roads:
		for i in range(1,road.size()):
			for j in range(1,river.size()):
				var crossing = Geometry2D.segment_intersects_segment(road[i-1],road[i],river[j-1],river[j])
				if crossing==null: continue
				var along := (road[i]-road[i-1]).normalized()
				canvas.draw_set_transform(crossing,along.angle(),Vector2.ONE)
				Landmarks.block(canvas,Rect2(-25,-11,50,22),Art.ROAD)
				for x in range(-20,25,7): Landmarks.line(canvas,Vector2(x,-9),Vector2(x,9),1.2)
				for side in [-1,1]:
					Landmarks.block(canvas,Rect2(-28,side*12-2,56,4),Landmarks.WOOD)
					for x in [-24,24]: Art.disk(canvas,Vector2(x,side*12),3,Art.PAPER,1.5)
				canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

static func clear_site(rect: Rect2, bounds: Rect2, reserved: Array[Rect2], roads: Array[PackedVector2Array]) -> bool:
	if bounds.size.x <= 10 or bounds.size.y <= 10: return false
	if not bounds.grow(-5).encloses(rect): return false
	for occupied in reserved:
		if occupied.grow(7).intersects(rect): return false
	for road in roads:
		for point in road:
			if rect.grow(12).has_point(point): return false
	return true

static func layout(profile: Dictionary, bounds: Rect2, reserved: Array[Rect2], roads: Array[PackedVector2Array], seed_value: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if profile.is_empty() or bounds.size.x<280 or bounds.size.y<180: return result
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
	var natural_index := 0
	for attempt in range(420):
		if result.size()>=int(bounds.size.x/10): break
		var width := rng.randf_range(48,88)
		var rect := Rect2(Vector2(rng.randf_range(5,bounds.size.x-width-5),rng.randf_range(bounds.position.y+132,bounds.end.y-width*0.9-5)),Vector2(width,width*0.9))
		if not clear_site(rect,bounds,occupied,roads): continue
		var kind: String = profile.scenery[natural_index%profile.scenery.size()]
		natural_index+=1
		result.append({"kind":kind,"rect":rect,"major":false})
		occupied.append(rect.grow(-2))
	# Fine environmental marks occupy remaining clearings without competing with
	# buildings. Their whole bounds are reserved just like the larger scenery.
	for attempt in range(260):
		var at := Vector2(rng.randf_range(12,bounds.end.x-12),rng.randf_range(bounds.position.y+140,bounds.end.y-18))
		var rect := Rect2(at-Vector2(10,8),Vector2(20,16))
		if not clear_site(rect,bounds,occupied,roads): continue
		result.append({"kind":"ground_marks","rect":rect,"major":false})
		occupied.append(rect.grow(3))
	result.sort_custom(func(a,b):return a.rect.end.y<b.rect.end.y)
	return result

static func landscape(canvas: CanvasItem, profile: Dictionary, sites: Array[Dictionary]) -> void:
	for site in sites:
		if site.major or site.kind=="ruins": Landmarks.draw(canvas,site.kind,site.rect,profile)
		else: Nature.draw(canvas,site.kind,site.rect,profile)
