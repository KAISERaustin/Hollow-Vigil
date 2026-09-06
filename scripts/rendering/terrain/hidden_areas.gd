extends Node2D

const Areas = preload("res://scripts/world/hidden_areas.gd")
const Plan = preload("res://scripts/world/castle_plan.gd")
const INK := Color.BLACK
var owned: Dictionary = {}
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
	owned = state.data.regions
	cells.clear()
	plans.clear()
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var sector := Vector2i(x, y)
			var plan := Plan.build(sector, int(state.data.seed))
			plans.append(plan)
			for cell in plan.cells:
				if not owned.has(VigilWorld.key(cell)):
					cells.append(cell)
	queue_redraw()

func _draw() -> void:
	for plan in plans:
		draw_set_transform(plan.anchor)
		# Broad, flat ground matches the other biomes. No paving grid or texture.
		for cell in plan.cells:
			if not owned.has(VigilWorld.key(cell)):
				var corner: Vector2 = Vector2(cell) * Balance.TILE - Vector2.ONE * 150.0 - plan.anchor
				draw_rect(Rect2(corner, Vector2.ONE * Balance.TILE), VigilTerrainArt.ground_color("castle_ruin"))
		for wall in plan.walls:
			if not owned.has(VigilWorld.key(wall.cell)):
				wall_piece(wall.a, wall.b, wall.outer)
		if not owned.has(plan.gate.id):
			var n := Vector2(VigilWorld.DIRS[plan.gate.side])
			var t := Vector2(-n.y, n.x)
			for sign_value in [-1, 1]:
				var p: Vector2 = plan.gate_point + t * 34.0 * sign_value
				wall_piece(p - n * 7, p + n * 7, true)

func wall_piece(a: Vector2, b: Vector2, outer: bool) -> void:
	# Chunky silhouettes, a single shaded face and one cap echo the towers.
	var width := 15.0 if outer else 11.0
	var lift := Vector2(0, -11)
	draw_line(a + Vector2(3, 4), b + Vector2(3, 4), Color("5d606d"), width + 7, true)
	draw_line(a, b, INK, width + 4, true)
	draw_line(a, b, Color("555465"), width, true)
	draw_line(a + lift, b + lift, INK, width + 4, true)
	draw_line(a + lift, b + lift, Color("b4adbd") if outer else Color("9c96aa"), width, true)
