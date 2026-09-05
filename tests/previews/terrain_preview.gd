extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")

func run() -> void:
	root.min_size = Vector2i.ZERO
	root.content_scale_size = Vector2i(1000, 880)
	root.size = Vector2i(1000, 880)
	var game := VigilState.new(879)
	game.data.balance = 1e12
	game.expand("1,0")
	game.expand("0,1")
	game.expand("1,1")
	game.data.regions["1,0"].style = "ashen_forge"
	game.data.regions["0,1"].style = "drowned_crypt"
	game.data.regions["1,1"].style = "bloodmoon_sanctuary"
	game.refresh_paths()
	for id in game.data.regions:
		for pad in range(3):
			game.economy.build(["rapid", "splash", "heavy"][pad], id, pad)
	for kind in ["basic", "fast", "heavy"]:
		var enemy := game.combat.spawn("1,0", kind)
		enemy.pos = Vector2(192 + 25 * ["basic", "fast", "heavy"].find(kind), 0)
	var field := Battlefield.new()
	field.state = game
	field.size = Vector2(1000, 880)
	field.camera = Vector2(150, 150)
	field.zoom = 1.18
	root.add_child(field)
	await capture("minimal-tiles-four-biomes")
	# A larger mixed world exercises camera scaling and repeating terrain.
	for y in range(4):
		for x in range(4):
			var id := VigilWorld.key(Vector2i(x, y))
			if not game.data.regions.has(id):
				game.expand(id)
			game.data.regions[id].style = VigilWorld.STYLES[(x + y) % 4]
	game.refresh_paths()
	field.camera = Vector2(450, 450)
	field.zoom = 0.61
	field.queue_redraw()
	await capture("minimal-tiles-seam-matrix")
	for region in game.data.regions.values():
		region.style = "drowned_crypt"
	game.refresh_paths()
	field.queue_redraw()
	await capture("minimal-tiles-same-biome")
	# Save-independent native desktop screenshots; no player progress is touched.
	root.content_scale_size = Vector2i(540, 960)
	root.size = Vector2i(540, 960)
	field.size = Vector2(540, 960)
	field.camera = Vector2.ZERO
	field.zoom = 1.0
	field.state = VigilState.new(879)
	field.state.economy.build("rapid", "0,0", 0)
	field.queue_redraw()
	await capture("minimal-tiles-starter")
	field.free()
	print("TERRAIN RENDER: four-biome corner, 16-tile seams, matching biomes, starter captured")
	quit()
