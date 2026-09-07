extends "res://tests/test_runner.gd"

const Rifts = preload("res://scripts/rendering/actors/rift_art.gd")
const Art = preload("res://scripts/rendering/terrain/terrain_art.gd")

class PortalImage extends Node2D:
	var style := "forest"
	var level := 0
	var unlocks: Array = []
	var zoom := 1.65
	func _draw() -> void:
		if style == "core":
			Rifts.draw_core(self, Vector2(128,155), zoom)
		else:
			Rifts.draw(self, style, Vector2(128,155), zoom, level, unlocks)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	preload("res://tests/unit/portal_visual_checks.gd").run(self)
	root.size = Vector2i(720, 640)
	root.content_scale_size = root.size
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art := PortalImage.new()
	viewport.add_child(art)
	var gallery := SubViewport.new()
	gallery.size = Vector2i(1380,1320)
	gallery.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(gallery)
	var background := ColorRect.new()
	background.size = gallery.size
	background.color = Art.ROAD
	gallery.add_child(background)
	for index in range(VigilWorld.ALL_STYLES.size()):
		art.style = VigilWorld.ALL_STYLES[index]
		var portal := Balance.Content.portal(art.style)
		var costs := portal.unlock_costs().keys()
		for scale_value in [0.42, 0.65, 1.0, 1.65]:
			art.zoom = scale_value
			var silhouettes: Array[PackedByteArray] = []
			for mask in range(1 << costs.size()):
				art.unlocks = []
				for bit in range(costs.size()):
					if mask & (1 << bit): art.unlocks.append(costs[bit])
				for level in range(Balance.MAX_TRAFFIC_LEVEL + 1):
					art.level = level
					art.queue_redraw()
					await frame()
					var img := viewport.get_texture().get_image()
					var bytes := img.get_data()
					check(not img.is_invisible(), "Portal remains visible")
					check(not bytes in silhouettes, "%s level %d attunement %d zoom %.2f has distinct art" % [art.style,level,mask,scale_value])
					silhouettes.append(bytes)
					check(Rect2i(0,0,256,256).encloses(img.get_used_rect().grow(3)), "Portal retains transparent padding")
		# Five large comparisons isolate attunement changes from rate changes.
		for column in range(5):
			art.zoom = 1.65
			art.level = [0,0,0,6,12][column]
			art.unlocks = [] if column == 0 else ([costs[column-1]] if column < 3 and costs.size() >= column else costs)
			art.queue_redraw()
			await frame()
			var sprite := Sprite2D.new()
			sprite.texture = ImageTexture.create_from_image(viewport.get_texture().get_image())
			sprite.position = Vector2(140+column*275,107+index*220)
			sprite.scale = Vector2.ONE * 0.85
			gallery.add_child(sprite)
			var label := Label.new()
			label.text = ["BASE / RATE 0", "ATTUNEMENT 1", "ATTUNEMENT 2", "ALL / RATE 6", "ALL / RATE 12"][column]
			if costs.is_empty() and column < 3: label.text = "ALL ACTIVE / RATE 0"
			label.position = Vector2(24+column*275,193+index*220)
			label.add_theme_color_override("font_color",Art.INK)
			label.add_theme_font_size_override("font_size",16)
			gallery.add_child(label)
		var heading := Label.new()
		heading.text = art.style.replace("_", " ").to_upper()
		heading.position = Vector2(24,5+index*220)
		heading.add_theme_color_override("font_color",Art.INK)
		heading.add_theme_font_size_override("font_size",20)
		gallery.add_child(heading)
	await frame()
	check(gallery.get_texture().get_image().save_png("res://artifacts/portal-upgrades.png") == OK, "Gallery saved")
	art.style = "core"
	for scale_value in [0.42,0.65,1.0,1.65]:
		art.zoom = scale_value
		art.queue_redraw()
		await frame()
		var core := viewport.get_texture().get_image()
		check(not core.is_invisible() and Rect2i(0,0,256,256).encloses(core.get_used_rect().grow(3)), "Receiving core shares the new base at every zoom")
	viewport.get_texture().get_image().save_png("res://artifacts/portal-core-base.png")
	viewport.queue_free()
	gallery.queue_free()
	await battlefield_checks()
	var groups: Array = [["lantern",4,0,0,1], ["heavy",2,1,0,1], ["warden",1,0,0,1]]
	check(Rifts.wave_parts("forest",groups,0).ornaments.map(func(p): return p.kind) == ["lantern"], "Campaign uses actual lane roster across biome families")
	check(Rifts.wave_parts("forest",groups,1).ornaments.map(func(p): return p.kind) == ["heavy"], "Campaign lanes stay independent")
	check(Rifts.wave_parts("forest",groups,2).ornaments.is_empty(), "Inactive campaign lane has no false attunement")
	print("PORTAL_UPGRADE_ART: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func battlefield_checks() -> void:
	var game := VigilState.new(879)
	game.data.balance = 1.0e12
	game.expand("1,0")
	game.expand("2,0")
	game.combat.enemies.clear()
	var field := Battlefield.new()
	field.state = game
	root.add_child(field)
	field.set_process(false)
	field.camera = Vector2(450,0)
	for style in VigilWorld.ALL_STYLES:
		# Draw both entrances directly through the live battlefield entry point;
		# castle cluster placement and input tests retain their existing contracts.
		game.data.regions["1,0"].style = style
		game.data.regions["1,0"].traffic = 12
		game.data.regions["1,0"].unlocks = Balance.Content.portal(style).unlock_costs().keys()
		game.data.regions["2,0"].style = style
		var snapshot := game.snapshot(1000.0)
		for width in [360,540]:
			root.size = Vector2i(width,640)
			root.content_scale_size = root.size
			field.size = root.size
			field.zoom = 0.65
			field.queue_redraw()
			await frame()
			root.get_texture().get_image().save_png("res://artifacts/portal-upgrade-%s-%d.png" % [style,width])
			check(game.snapshot(1000.0) == snapshot, "Drawing upgraded portals leaves all game state unchanged")
			check(is_equal_approx(field.entrance_hit_radius(),32.0*field.zoom), "Portal interaction radius stays unchanged")
	field.queue_free()
