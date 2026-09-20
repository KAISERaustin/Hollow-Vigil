extends SceneTree

const Images = preload("res://scripts/rendering/actors/actor_images.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")
const ComponentArt = preload("res://scripts/rendering/effects/tower_component_art.gd")
const STAGES = [[1, "", "tier-1"], [2, "", "tier-2"], [3, "", "tier-3"],
	[4, "needle_battery", "tier-4-bolt-battery"], [4, "siegebreaker", "tier-4-breacher"]]
const SOURCE = "res://docs/concepts/ironspike-siege-ballista-2026-09-20/sprites/"
const GROUND := Vector2(1024, 1442)
const PIVOT := Vector2(1024, 1024)
const MUZZLE := Vector2(1024, 1183)
var failures: Array[String] = []
var checks := 0

class SpriteCheck extends Node2D:
	var stage: Array = STAGES[0]
	var zoom := 1.0
	var aim := PI / 2.0
	var mode := "runtime"
	func _draw() -> void:
		var at := Vector2(192, 248)
		if mode == "direct":
			var images = Images.for_canvas(self)
			var suffix := "ironspike/%d/%s" % [stage[0], stage[1]]
			var base: Texture2D = Images.texture_for(images.entries["tower/" + suffix])
			var top: Texture2D = Images.texture_for(images.entries["bow/" + suffix])
			# Independent composition from the source artist's measured pixels.
			draw_texture_rect(base, Rect2(at - GROUND / 20.0 * zoom, base.get_size() / 20.0 * zoom), false)
			draw_set_transform(at + (PIVOT - GROUND) / 20.0 * zoom, aim - PI / 2.0, Vector2.ONE * zoom)
			draw_texture_rect(top, Rect2(-PIVOT / 20.0, top.get_size() / 20.0), false)
			draw_set_transform(Vector2.ZERO)
		elif mode == "export":
			VigilTerrainArt.sentinel_vector(self, "ironspike", at, zoom, stage[0], stage[1], aim)
		elif mode == "preview":
			VigilTerrainArt.sentinel(self, "ironspike", at, zoom, stage[0], stage[1])
		else:
			VigilTerrainArt.sentinel(self, "ironspike", at, zoom, stage[0], stage[1], aim)

class Board extends Battlefield:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("293633"))
		for tower in state.data.towers.values():
			var at := screen(VigilWorld.pad_position(tower.region, tower.pad))
			draw_line(at + Vector2(-36, 1), at + Vector2(36, 1), Color("758f9e"), 1)
			draw_tower(tower)
		ComponentArt.draw(self)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func attack_checks(stage: Array) -> void:
	var game := VigilState.new(912)
	game.data.towers.clear()
	var location := VigilWorld.ground_location(Vector2.ZERO)
	var tower := Balance.Content.tower("ironspike").make_record({"id": "iron", "kind": "ironspike",
		"region": location.region, "pad": location.pad, "level": stage[0], "branch": stage[1]})
	game.data.towers[tower.id] = tower
	var stats := game.combat.tower_stats(tower)
	var pivot := (PIVOT - GROUND) / 20.0
	var muzzle_distance := (MUZZLE - PIVOT).length() / 20.0
	for index in range(8):
		game.combat.line_projectiles.clear()
		game.combat.enemies.clear()
		var direction := Vector2.from_angle(index * PI / 4.0)
		var victims := []
		for distance in [85, 130]:
			var point: Vector2 = pivot + direction * distance
			var route: Array[Vector2] = [point, point + direction * 80]
			var enemy := game.combat.spawn_on_path("basic", route)
			enemy.hp = 10000.0
			enemy.stun_until = 1000.0
			victims.append(enemy)
		game.combat.launch_line_attack(tower, Vector2.ZERO, victims[0], stats, false)
		var count := int(stats.get("volley_count", 1))
		check(game.combat.line_projectiles.size() == count, stage[2] + " preserves volley count")
		check(Vector2.from_angle(tower.angle).is_equal_approx(direction), stage[2] + " weapon points at target in all eight directions")
		for shot_index in count:
			var bolt: Dictionary = game.combat.line_projectiles[shot_index]
			var outlet := pivot + direction * muzzle_distance
			var spacing: float = (shot_index - (count - 1) / 2.0) * stats.get("volley_spacing", 20.0)
			check(bolt.start.is_equal_approx(outlet + direction.orthogonal() * spacing), stage[2] + " shot starts at the rotated outlet")
			check(bolt.direction.is_equal_approx(direction) and bolt.shot.fx.from.is_equal_approx(bolt.start), stage[2] + " shot record, flight and weapon share bearing/origin")
			check(is_equal_approx(bolt.end.length(), stats.range), stage[2] + " keeps the tower's range boundary")
		game.combat.LineProjectiles.advance(game.combat, 1.0)
		check(victims.all(func(e): return e.hp < 10000.0), stage[2] + " bolt pierces aligned enemies")
		check(victims.all(func(e): return e.hp >= 10000.0 - stats.damage - 0.01), stage[2] + " volley cannot multiply hits on one enemy")
	# A moving target is led; the visible bearing follows the real line, not
	# merely the enemy's current position. A second instance keeps its own aim.
	game.combat.line_projectiles.clear()
	game.combat.enemies.clear()
	var route: Array[Vector2] = [pivot + Vector2(100, 0), pivot + Vector2(100, 180)]
	var moving := game.combat.spawn_on_path("basic", route)
	moving.hp = 10000.0
	var other := tower.duplicate(true)
	other.id = "other"
	other.angle = -2.0
	game.data.towers[other.id] = other
	game.combat.launch_line_attack(tower, Vector2.ZERO, moving, stats, false)
	var first: Dictionary = game.combat.line_projectiles[game.combat.line_projectiles.size() / 2]
	check(first.direction.y > 0.01 and Vector2.from_angle(tower.angle).is_equal_approx(first.direction), stage[2] + " rotating top uses moving-target lead")
	check(other.angle == -2.0, "Aiming one instance leaves another instance unchanged")
	for step in range(80):
		moving.pos.y += game.combat.enemy_speed(moving) * 0.005
		game.combat.LineProjectiles.advance(game.combat, 0.005)
	check(moving.hp < 10000.0, stage[2] + " led shot hits moving target")

func run() -> void:
	var images := Images.new()
	var profile := Balance.Content.projectile("ironspike")
	check(profile.attribute("aim_pivot").is_equal_approx((PIVOT - GROUND) / 20.0), "Projectile pivot matches the new mounting socket")
	check(profile.attribute("muzzle").is_equal_approx((MUZZLE - GROUND) / 20.0), "Projectile outlet matches the loaded bolt tip")
	var fixed := Balance.Content.projectile("moonwheel")
	var fixed_attributes := fixed.attributes()
	var derived = fixed.derive("projectile/rotating-fixture", {"aim_pivot": Vector2(0, -10), "aim_forward": PI / 2.0, "muzzle": Vector2(0, -4)})
	check(derived.aimed_launch(Vector2.ZERO, Vector2(90, -10)).muzzle.is_equal_approx(Vector2(6, -10)), "Rotating outlets can be assigned to another projectile definition")
	check(fixed.attributes() == fixed_attributes and fixed.aimed_launch(Vector2.ZERO, Vector2.RIGHT * 90).muzzle == Balance.PROJECTILES.moonwheel.muzzle, "Unassigned projectile definitions stay fixed and unchanged")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384, 384)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art := SpriteCheck.new()
	viewport.add_child(art)
	var gallery := Image.create(1280, 800, false, Image.FORMAT_RGBA8)
	for row in STAGES.size():
		var stage: Array = STAGES[row]
		attack_checks(stage)
		for family in ["tower", "bow"]:
			var key := "%s/ironspike/%d/%s" % [family, stage[0], stage[1]]
			var entry: Dictionary = images.entries[key]
			var source: String = SOURCE + stage[2] + ("/base.png" if family == "tower" else "/top.png")
			check(FileAccess.get_sha256(entry.image) == FileAccess.get_sha256(source), key + " is an unchanged source copy")
			check(entry.authored and not entry.has("native_fallback_above_zoom"), key + " remains authored at high zoom and survives rebaking")
			check(Images.texture_for(entry).get_size() == Vector2(2048, 2048), key + " retains complete canvas")
		art.stage = stage
		for zoom in [1.0, 3.0]:
			art.zoom = zoom
			for column in range(8):
				art.aim = column * PI / 4.0
				art.mode = "direct"
				art.queue_redraw()
				await frame()
				var expected := viewport.get_texture().get_image().get_data()
				for mode in ["runtime", "export"]:
					art.mode = mode
					art.queue_redraw()
					await frame()
					var rendered := viewport.get_texture().get_image()
					check(rendered.get_data() == expected, "%s %s zoom %.0f bearing %d: fixed base and correctly mounted top" % [stage[2], mode, zoom, column])
					check(Rect2i(0, 0, 384, 384).encloses(rendered.get_used_rect().grow(3)), stage[2] + " no rotation clipping")
					if zoom == 3.0 and mode == "runtime":
						rendered.resize(160, 160, Image.INTERPOLATE_LANCZOS)
						gallery.blit_rect(rendered, Rect2i(0, 0, 160, 160), Vector2i(column * 160, row * 160))
		art.aim = PI / 2.0
		art.mode = "direct"
		art.queue_redraw()
		await frame()
		var resting := viewport.get_texture().get_image().get_data()
		art.mode = "preview"
		art.queue_redraw()
		await frame()
		check(viewport.get_texture().get_image().get_data() == resting, stage[2] + " build preview uses the authored front-facing rest pose")
	gallery.save_png("res://artifacts/ironspike-rotation-gallery.png")
	art.free()
	for stage in STAGES:
		for dimension in [32, 42, 48, 64, 80]:
			viewport.size = Vector2i(dimension, dimension)
			var portrait := Portrait.preview("towers", "ironspike", stage[0], stage[1])
			portrait.custom_minimum_size = Vector2.ZERO
			portrait.size = Vector2.ONE * dimension
			viewport.add_child(portrait)
			await frame()
			var used := viewport.get_texture().get_image().get_used_rect()
			check(used.has_area() and Rect2i(1, 1, dimension - 2, dimension - 2).encloses(used), "%s full two-piece portrait fits %dpx" % [stage[2], dimension])
			portrait.free()
	viewport.free()
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var board := Board.new()
		board.state = VigilState.new(913)
		board.state.data.towers.clear()
		board.size = dimensions
		board.zoom = 1.3
		board.unrestricted_camera = true
		root.add_child(board)
		board.set_process(false)
		for index in STAGES.size():
			var stage: Array = STAGES[index]
			var at := Vector2(dimensions.x * 0.27, 115 + index * 110)
			var location := VigilWorld.ground_location(board.world(at))
			var tower := Balance.Content.tower("ironspike").make_record({"id": str(index), "kind": "ironspike", "level": stage[0],
				"branch": stage[1], "region": location.region, "pad": location.pad, "angle": PI / 2.0 + index * PI / 4.0})
			board.state.data.towers[tower.id] = tower
			var portrait := Portrait.preview("towers", "ironspike", stage[0], stage[1])
			portrait.position = Vector2(dimensions.x * 0.7 - 40, at.y - 90)
			portrait.size = Vector2(80, 80)
			board.add_child(portrait)
		board.queue_redraw()
		await frame()
		check(root.get_texture().get_image().save_png("res://artifacts/ironspike-%dx%d.png" % [dimensions.x, dimensions.y]) == OK, "Saved portrait-phone battlefield/portrait capture")
		board.free()
	print("IRONSPIKE ART: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
