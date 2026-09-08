extends SceneTree
## Offline only: run with a rendering driver, never --headless.
const Map = preload("res://scripts/campaign/world_map.gd")
const WIDTH := 540
const HEIGHT := 960

class BakeMap extends Map:
	var landscapes: Array[Dictionary] = []
	var completed_roads := false
	func _draw() -> void:
		for chapter in landscapes.size():
			var bounds := chapter_rect(chapter)
			var style: String = Catalog.CHAPTERS[chapter].style
			draw_rect(bounds, Art.ground_color(style))
			MapArt.Nature.ground(self, bounds, style)
			var roads := chapter_roads(chapter)
			var river := MapArt.waterway(bounds)
			MapArt.water(self, river, landscapes[chapter].profile)
			MapArt.landscape(self, landscapes[chapter].profile, landscapes[chapter].sites)
			for road in roads: MapArt.trail(self, road, completed_roads)
			MapArt.bridges(self, roads, river)
			if chapter > 0: draw_rect(Rect2(0, bounds.position.y, size.x, UI.OUTLINE), UI.BORDER)

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	for step in 4: await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(WIDTH, HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var map := BakeMap.new()
	map.progress = preload("res://scripts/campaign/progress.gd").new()
	map.progress.allow_all = true
	viewport.add_child(map)
	# Reserve the union of live text and fixed-size touch targets after mapping
	# supported portrait widths into the image's coordinate system.
	var reserved: Array = []
	for chapter in Map.Catalog.CHAPTERS.size(): reserved.append([])
	for width in [280, 320, 360, 390, 430, 540, 768]:
		map.size.x = width
		for index in map.labels.size():
			map.labels[index].get_child(1).text = "Cleared · Lit · Boss" if index % 5 == 4 else "Cleared · Lit"
		await frame()
		for chapter in reserved.size():
			for rect in map.chapter_reserved(chapter):
				reserved[chapter].append(Rect2(Vector2(rect.position.x * WIDTH / width, rect.position.y), Vector2(rect.size.x * WIDTH / width, rect.size.y)).grow(2))
	map.size.x = WIDTH
	await frame()
	var metadata: Array = []
	for chapter in reserved.size():
		var profile := map.chapter_presentation(chapter)
		profile.erase("background")
		var obstacles := map.chapter_roads(chapter)
		obstacles.append(Map.MapArt.waterway(map.chapter_rect(chapter)))
		var exclusions: Array[Rect2] = []
		exclusions.assign(reserved[chapter])
		var sites := Map.MapArt.layout(profile, map.chapter_rect(chapter), exclusions, obstacles, chapter + 71)
		map.landscapes.append({"profile": profile, "sites": sites})
		metadata.append(sites)
		print("BAKE chapter %d: %d scenery sites" % [chapter + 1, sites.size()])
	for child in map.get_children(): child.hide()
	DirAccess.make_dir_recursive_absolute("res://assets/campaign/baked")
	for chapter in reserved.size():
		map.position.y = -chapter * HEIGHT
		var atlas := Image.create(WIDTH, HEIGHT * 2, false, Image.FORMAT_RGBA8)
		for variant in 2:
			map.completed_roads = variant == 1
			map.queue_redraw()
			await frame()
			atlas.blit_rect(viewport.get_texture().get_image(), Rect2i(0, 0, WIDTH, HEIGHT), Vector2i(0, variant * HEIGHT))
		var path := "res://assets/campaign/baked/%s.png" % Map.Catalog.CHAPTERS[chapter].style
		if atlas.save_png(path) != OK:
			push_error("Could not save " + path)
			quit(1)
			return
	var file := FileAccess.open("res://assets/campaign/baked/layout.cfg", FileAccess.WRITE)
	file.store_string(var_to_str(metadata))
	print("BAKED CAMPAIGN MAPS: six 540x1920 atlases saved")
	quit()
