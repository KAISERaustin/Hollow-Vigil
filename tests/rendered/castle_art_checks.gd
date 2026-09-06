extends SceneTree

const Checks = preload("res://tests/unit/castle_checks.gd")
const Areas = preload("res://scripts/world/hidden_areas.gd")
const Plan = preload("res://scripts/world/castle_plan.gd")
var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(1100, 900)
	root.content_scale_size = root.size
	var covered := {}
	for y in range(-2,3):
		for x in range(-2,3):
			var sector := Vector2i(x,y)
			var plan := Plan.build(sector, 879)
			if covered.has(plan.variant):
				continue
			covered[plan.variant] = true
			var game := Checks.fixture(sector)
			var field := Battlefield.new()
			field.state = game
			field.size = Vector2(root.size)
			root.add_child(field)
			field.set_process(false)
			for z in [0.42, 1.0, 1.65]:
				field.zoom = z
				field.camera = plan.anchor + plan.bounds.get_center() if z < 1.65 else VigilWorld.center(plan.gate.id) + Vector2(VigilWorld.DIRS[plan.gate.side])*150
				field.queue_redraw()
				await frame()
				var img := root.get_texture().get_image()
				if img.is_empty() or img.save_png("res://artifacts/castle-%d-%.2f.png" % [plan.variant,z]) != OK:
					failures += 1
				# Toggling the world grid must not alter any shared castle seam.
				field.terrain_layer.grid.hide()
				await frame()
				var gridless := root.get_texture().get_image()
				for cell in plan.cells:
					for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
						if not plan.cells.has(cell + direction):
							continue
						var tangent := Vector2(-direction.y, direction.x)
						for offset in [-120, -60, 0, 60, 120]:
							var point := Vector2i(field.screen(Vector2(cell)*300 + Vector2(direction)*150 + tangent*offset))
							if Rect2i(Vector2i.ZERO, root.size).has_point(point) and img.get_pixelv(point) != gridless.get_pixelv(point):
								failures += 1
				field.terrain_layer.grid.show()
				await frame()
				for border in field.terrain_layer.cloud_edges.borders:
					if VigilWorld.key(border.cell) == plan.gate.neighbor and border.directions.has(-Vector2(VigilWorld.DIRS[plan.gate.side])):
						failures += 1 # Fog must never cross the gate-to-path threshold.
				# Redraw after culling away and returning must be pixel-identical.
				var camera := field.camera
				field.camera += Vector2(12000,12000)
				field.queue_redraw()
				await frame()
				field.camera = camera
				field.queue_redraw()
				await frame()
				if img.get_data() != root.get_texture().get_image().get_data():
					failures += 1
			field.free()
	print("CASTLE_ART: four plans, three zooms, offscreen return; %d failures" % failures)
	quit(0 if failures == 0 else 1)
