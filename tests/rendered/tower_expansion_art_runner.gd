extends SceneTree

const UI = preload("res://scripts/ui/shared/interface.gd")
const Integration = preload("res://tests/unit/tower_expansion_integration_checks.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 120)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(960, 1120)
	root.content_scale_size = root.size
	var background := ColorRect.new()
	background.color = VigilTerrainArt.BACKDROP
	background.size = root.size
	root.add_child(background)
	var fixtures = preload("res://tests/tower_expansion_runner.gd").new()
	var row := 0
	for kind in fixtures.NewKinds:
		var column := 0
		for stage in [[1, ""], [4, Balance.BRANCHES[kind].keys()[0]], [4, Balance.BRANCHES[kind].keys()[1]]]:
			var f := Integration.live_fixture(fixtures, kind, stage[0], stage[1])
			f.game.combat.authored_roads = f.game.paths.values()
			var nearest := INF
			for road in f.game.combat.authored_roads:
				for segment in range(1, road.size()):
					var point := Geometry2D.get_closest_point_to_segment(f.origin, road[segment - 1], road[segment])
					if point.distance_squared_to(f.origin) < nearest:
						nearest = point.distance_squared_to(f.origin)
						f.enemy.pos = point
			var viewport := SubViewport.new()
			viewport.size = Vector2i(320, 240)
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var field := Battlefield.new()
			field.state = f.game
			field.size = viewport.size
			viewport.add_child(field)
			field.set_process(false)
			field.camera = f.origin + Vector2(0, 10)
			field.zoom = 1.2
			# Freeze a real launched projectile, mark or armed trap for inspection.
			f.game.combat.tick(Balance.STEP)
			f.tower.cooldown = 100.0
			if kind == "caltrop_keep":
				f.game.combat.enemies.clear()
				f.game.combat.simulation_time += 1.1
			elif kind == "hex_lantern":
				f.game.combat.advance_shots(1.0)
			else:
				f.game.combat.TowerComponents.advance(f.game.combat, 0.06)
			field.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var capture := viewport.get_texture().get_image()
			check(not capture.is_empty(), kind + " renders its live battlefield stage " + str(stage))
			var sprite := TextureRect.new()
			sprite.texture = ImageTexture.create_from_image(capture)
			sprite.position = Vector2(column * 320, row * 280)
			sprite.size = viewport.size
			root.add_child(sprite)
			var label := UI.label(Balance.stats(kind, stage[0], {}, stage[1]).name, 18, UI.PANEL)
			label.position = sprite.position + Vector2(10, 247)
			root.add_child(label)
			viewport.free()
			column += 1
		row += 1
	fixtures.free()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/tower-expansion-live-art.png") == OK, "Live effects review board saves")
	print("TOWER EXPANSION LIVE ART: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
