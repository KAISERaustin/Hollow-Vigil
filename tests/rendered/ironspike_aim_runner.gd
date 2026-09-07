extends "res://tests/tower_expansion_runner.gd"

class AimField extends Battlefield:
	var show_attack := true
	func _draw() -> void:
		var tower: Dictionary = state.data.towers["1"]
		var at := screen(VigilWorld.pad_position(tower.region, tower.pad))
		draw_set_transform(at)
		VigilTerrainArt.socket(self, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
		draw_tower(tower)
		if show_attack:
			for target in state.combat.enemies:
				draw_enemy(target)
			preload("res://scripts/rendering/effects/tower_component_art.gd").draw(self)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	for dimensions in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for stage in [[1, ""], [2, ""], [3, ""], [4, "siegebreaker"], [4, "needle_battery"]]:
			var fields: Array[AimField] = []
			for index in range(8):
				var g := setup("ironspike", stage[0], stage[1])
				var tower: Dictionary = g.data.towers["1"]
				var origin := VigilWorld.pad_position(tower.region, tower.pad)
				var direction := Vector2.from_angle(index * PI / 4.0)
				var target := enemy(g, origin + Balance.PROJECTILES.ironspike.muzzle + direction * 65.0)
				target.stun_until = 100.0
				g.combat.tick(0.001)
				check(Vector2.from_angle(tower.angle).is_equal_approx(direction), "Combat tick points tier %s at target %d" % [str(stage), index])
				for bolt in g.combat.line_projectiles:
					check(bolt.direction.is_equal_approx(direction), "Every volley bolt follows the bow")
				Lines.advance(g.combat, 0.085)
				var field := AimField.new()
				field.state = g
				field.size = Vector2(dimensions) / Vector2(2, 4)
				field.position = Vector2(index % 2, index / 2) * field.size
				field.camera = origin + Vector2(0, -20)
				root.add_child(field)
				field.set_process(false)
				fields.append(field)
			await frame()
			var capture := root.get_texture().get_image()
			capture.save_png("res://artifacts/ironspike-aim-%d-%d-%s.png" % [dimensions.x, stage[0], stage[1]])
			# Flying bolts can cross the pedestal; compare the artwork alone.
			for field in fields:
				field.show_attack = false
				field.queue_redraw()
			await frame()
			capture = root.get_texture().get_image()
			var base_pixels := PackedByteArray()
			for index in range(8):
				var field := fields[index]
				var tower: Dictionary = field.state.data.towers["1"]
				var at := field.position + field.screen(VigilWorld.pad_position(tower.region, tower.pad))
				var direction := Vector2.from_angle(index * PI / 4.0)
				var arrowhead := at + Balance.PROJECTILES.ironspike.muzzle + direction * 14.0
				var color := capture.get_pixelv(Vector2i(arrowhead))
				check(color.r > 0.8 and color.g > 0.8 and color.b > 0.65, "Rendered arrowhead faces target %d at %s" % [index, str(dimensions)])
				var pixels := capture.get_region(Rect2i(Vector2i(at) + Vector2i(-16, 7), Vector2i(32, 3))).get_data()
				if index == 0: base_pixels = pixels
				else: check(pixels == base_pixels, "Pedestal stays stationary while bow turns")
			for field in fields: field.queue_free()
			await process_frame
	print("IRONSPIKE AIM: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
