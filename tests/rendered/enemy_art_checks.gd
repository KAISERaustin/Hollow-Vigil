extends "res://tests/test_runner.gd"


class EnemyImage extends Node2D:
	var kind := "basic"
	var zoom := 5.0
	func _draw() -> void:
		VigilTerrainArt.enemy(self, kind, Vector2(128, 145), zoom)

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

func run() -> void:
	root.size = Vector2i(540, 960)
	root.content_scale_size = root.size
	var gallery := SubViewport.new()
	gallery.size = Vector2i(1440, 1560)
	gallery.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(gallery)
	var background := ColorRect.new()
	background.color = VigilTerrainArt.ROAD
	background.size = gallery.size
	gallery.add_child(background)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art := EnemyImage.new()
	viewport.add_child(art)
	DirAccess.make_dir_recursive_absolute("res://assets/enemies")
	var seen: Array[PackedByteArray] = []
	var column := 0
	var ordered: Array = []
	for style in VigilWorld.ALL_STYLES:
		ordered.append_array(Balance.portal_kinds(style))
	for kind in ordered:
		var row := int(column / 3.0)
		var x := (column % 3) * 480
		if column % 3 == 0:
			var heading := Label.new()
			heading.text = Balance.enemy_portal_style(kind).replace("_", " ").to_upper()
			heading.position = Vector2(24, row * 260 + 12)
			heading.add_theme_color_override("font_color", Color.BLACK)
			heading.add_theme_font_size_override("font_size", 25)
			gallery.add_child(heading)
		art.kind = kind
		art.zoom = 5.0
		art.queue_redraw()
		await frame()
		var img := viewport.get_texture().get_image()
		check(not img.is_invisible(), kind + " renders")
		check(img.get_used_rect().grow(4).intersection(Rect2i(0,0,256,256)) == img.get_used_rect().grow(4), kind + " fits its portrait")
		check(img.get_pixel(0,0).a == 0, kind + " has transparent padding")
		check(not img.get_data() in seen, kind + " has a distinct silhouette")
		seen.append(img.get_data())
		check(img.save_png("res://assets/enemies/%s.png" % kind) == OK, "Portrait saved")
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.position = Vector2(108+x,130+row*260)
		sprite.scale = Vector2.ONE * 0.7
		gallery.add_child(sprite)
		var label := Label.new()
		label.text = Balance.ENEMIES[kind].name
		label.position = Vector2(208+x,80+row*260)
		label.size = Vector2(265, 75)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color",Color.BLACK)
		label.add_theme_font_size_override("font_size",22)
		gallery.add_child(label)
		for zoom in [0.42, 0.65, 1.0, 1.65]:
			art.zoom = zoom
			art.queue_redraw()
			await frame()
			var small := viewport.get_texture().get_image()
			check(not small.is_invisible(), "%s renders at zoom %.2f" % [kind,zoom])
			var sample := Sprite2D.new()
			sample.texture = ImageTexture.create_from_image(small)
			sample.position = Vector2(216+x+[0.42,0.65,1.0,1.65].find(zoom)*57,178+row*260)
			gallery.add_child(sample)
		column += 1
	await frame()
	gallery.get_texture().get_image().save_png("res://artifacts/enemy-lineup.png")
	var game := VigilState.new(879)
	game.data.balance = 10000
	game.expand("1,0")
	for pad in range(4):
		var tower := game.economy.build(Balance.TOWERS.keys()[pad], "0,0", pad)
		game.economy.upgrade(tower)
		game.economy.upgrade(tower)
	for kind in Balance.ENEMIES:
		var enemy := fixture_enemy(game, kind)
		enemy.pos = Vector2(85 + Balance.ENEMIES.keys().find(kind) * 43, 0)
		enemy.hp *= 0.6
	var field := Battlefield.new()
	field.state = game
	field.camera = Vector2(120, 0)
	root.add_child(field)
	field.set_process(false)
	for size in [Vector2i(540,960), Vector2i(360,640)]:
		root.size = size
		root.content_scale_size = size
		field.size = size
		field.zoom = 1.0
		field.queue_redraw()
		await frame()
		root.get_texture().get_image().save_png("res://artifacts/enemies-in-game-%d.png" % size.x)
	print("ENEMY_ART: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
