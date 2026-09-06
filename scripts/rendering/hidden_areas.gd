extends Node2D

const Areas = preload("res://scripts/world/hidden_areas.gd")
const Plan = preload("res://scripts/world/castle_plan.gd")
const INK := Color("191c22")
var cells: Array[Vector2i] = []
var plans: Array[Dictionary] = []
var signature: Array = []

func synchronize(state: VigilState, view: Rect2) -> void:
	# Include entire footprints when any piece can enter the viewport, including
	# walls raised above the ground and clusters anchored offscreen.
	var first := Areas.sector_for(Vector2i((view.grow(350).position / Balance.TILE).floor()))
	var last := Areas.sector_for(Vector2i((view.grow(350).end / Balance.TILE).ceil()))
	var next_signature := [state, state.data.seed, state.terrain_revision, first, last]
	if signature == next_signature:
		return
	signature = next_signature
	cells.clear()
	plans.clear()
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var sector := Vector2i(x, y)
			if Areas.preserved(sector, int(state.data.seed), state.data.regions):
				continue
			var plan := Plan.build(sector, int(state.data.seed))
			plans.append(plan)
			cells.append_array(plan.cells)
	queue_redraw()

func _draw() -> void:
	for plan in plans:
		draw_set_transform(plan.anchor)
		for floor_piece in plan.floors:
			var rect: Rect2 = floor_piece.rect
			var shade: float = floor_piece.shade
			draw_rect(rect, Color("363b37") if floor_piece.garden else Color(0.28 + shade, 0.29 + shade, 0.30 + shade))
			# Staggered paving reads at room scale, with no tile-size seams.
			for row in range(2):
				for col in range(2):
					var p := rect.position + Vector2(col * 29 + 3, row * 28 + 4)
					if floor_piece.garden:
						draw_line(p, p + Vector2(6, -6), Color("626847"), 2.0)
					else:
						draw_line(p, p + Vector2(23, 0), Color("656660"), 1.0)
			if floor_piece.crack:
				var p := rect.position + Vector2(13, 17)
				draw_polyline(PackedVector2Array([p, p + Vector2(16, 12), p + Vector2(11, 24), p + Vector2(29, 35)]), Color("292d2d"), 1.7, true)
		# Broken threshold uses the exact collision-free emergence centerline.
		var gate: Vector2 = plan.gate_point
		var n := Vector2(VigilWorld.DIRS[plan.gate.side])
		var t := Vector2(-n.y, n.x)
		for i in range(5):
			var p := gate - n * (12.0 + i * 12.0)
			draw_colored_polygon(PackedVector2Array([p-t*18, p+t*18, p+t*16+n*9, p-t*17+n*9]), Color("8a8373"))
		# Draw every foundation before any raised top so T-junctions, concave
		# corners and straight joins have one consistent thickness/perspective.
		for wall in plan.walls:
			wall_base(wall.a, wall.b, 18.0 if wall.outer else 12.0)
		for wall in plan.walls:
			wall_top(wall.a, wall.b, 18.0 if wall.outer else 12.0, wall.outer)
		for p in plan.towers:
			draw_rect(Rect2(p-Vector2(24, 24), Vector2(48,48)), INK)
			draw_rect(Rect2(p-Vector2(21, 29), Vector2(42,42)), Color("77776e"))
			draw_rect(Rect2(p-Vector2(12, 20), Vector2(24,24)), Color("303334"))
			rubble(p + Vector2(17, 17))
		for p in plan.rubble:
			rubble(p)
		for beam in plan.beams:
			var axis := Vector2.from_angle(beam.angle) * 27.0
			draw_line(beam.pos-axis+Vector2(3,4),beam.pos+axis+Vector2(3,4),INK,10,true)
			draw_line(beam.pos-axis,beam.pos+axis,Color("5b5041"),8,true)
			draw_line(beam.pos-axis+Vector2(0,-2),beam.pos+axis+Vector2(0,-2),Color("968168"),2,true)
		# Two gate piers leave a 48-unit clear opening for the boss centerline.
		for sign_value in [-1, 1]:
			var p: Vector2 = gate + t * 32.0 * sign_value
			wall_base(p-n*8, p+n*8, 15)
			wall_top(p-n*8, p+n*8, 15, true)
			draw_line(p+Vector2(-5,-20), p+Vector2(-3,-34), Color("8a8980"), 5.0)

func wall_base(a: Vector2, b: Vector2, width: float) -> void:
	draw_line(a + Vector2(4,6), b + Vector2(4,6), Color(0.03,0.04,0.05,0.5), width+9, true)
	draw_line(a, b, INK, width+4, true)
	for elevation in range(0,19,3):
		draw_line(a-Vector2(0,elevation),b-Vector2(0,elevation),Color("41464a"),width,true)

func wall_top(a: Vector2, b: Vector2, width: float, outer: bool) -> void:
	var lift := Vector2(0,-18)
	draw_line(a+lift,b+lift,INK,width+3,true)
	draw_line(a+lift,b+lift,Color("7c7d76") if outer else Color("696c67"),width,true)
	draw_line(a+lift+Vector2(0,-width*0.3),b+lift+Vector2(0,-width*0.3),Color("a09b89"),2,true)
	var count := maxi(1, floori(a.distance_to(b)/20))
	for i in range(count):
		var p := a.lerp(b, (i+0.5)/count)+lift
		draw_line(p+Vector2(-2,-width/2),p+Vector2(1,width/2),Color("42494a"),1.5,true)

func rubble(p: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(("fallen-masonry:" + str(p)).hash())
	for i in range(7):
		var q := p + Vector2(rng.randf_range(-24,24), rng.randf_range(-14,14))
		var shape := PackedVector2Array([q+Vector2(-6,3),q+Vector2(-4,-5),q+Vector2(4,-7),q+Vector2(8,2),q+Vector2(2,6)])
		draw_colored_polygon(shape, Color("696d65") if rng.randf() < 0.5 else Color("555b57"))
		draw_line(shape[1],shape[2],Color("a09b89"),1.5,true)
	for i in range(3):
		var q := p+Vector2(i*8-14,12)
		draw_polyline(PackedVector2Array([q,q+Vector2(-3,-10),q+Vector2(5,-17)]),Color("6c7450"),2,true)
