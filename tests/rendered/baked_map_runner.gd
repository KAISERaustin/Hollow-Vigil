extends SceneTree

const Map = preload("res://scripts/campaign/world_map.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(540,960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var progress := preload("res://scripts/campaign/progress.gd").new()
	var map := Map.new()
	map.progress = progress
	viewport.add_child(map)
	map.size.x = 540
	await frame()
	# Hide live controls to compare actual composited backgrounds with the
	# stored atlas. This catches bad source rectangles and progress boundaries.
	for child in map.get_children(): child.hide()
	for chapter in Map.Catalog.CHAPTERS.size():
		var atlas: Image = map.backgrounds[chapter].get_image()
		map.position.y = -chapter * Map.CHAPTER_HEIGHT
		for completed in range(maxi(0,chapter*Map.Catalog.LEVELS_PER_CHAPTER-1),mini(Map.Catalog.COUNT,(chapter+1)*Map.Catalog.LEVELS_PER_CHAPTER)+1):
			progress.data.completed_levels = completed
			map.queue_redraw()
			await frame()
			var rendered := viewport.get_texture().get_image()
			var within := completed - chapter * Map.Catalog.LEVELS_PER_CHAPTER
			var cutoff := 0 if within < 0 else (Map.CHAPTER_HEIGHT if within >= Map.Catalog.LEVELS_PER_CHAPTER else 176 + within * 164)
			var matches := true
			for y in range(4,956,7):
				for x in range(4,536,11):
					var expected := atlas.get_pixel(x,y + (int(Map.CHAPTER_HEIGHT) if y < cutoff else 0))
					var actual := rendered.get_pixel(x,y)
					if absf(expected.r-actual.r)>0.015 or absf(expected.g-actual.g)>0.015 or absf(expected.b-actual.b)>0.015:
						matches = false
			check(matches,"Baked progress pixels match chapter %d, completed %d" % [chapter+1,completed])
			if chapter > 0:
				check(rendered.get_pixel(270, 0) == UI.BORDER, "Chapter separator uses the shared black rim")
				var below := atlas.get_pixel(270, UI.OUTLINE + (int(Map.CHAPTER_HEIGHT) if UI.OUTLINE < cutoff else 0))
				check(rendered.get_pixel(270, UI.OUTLINE).is_equal_approx(below), "Chapter separator is exactly one shared rim wide")
	var second := Map.new()
	second.progress = progress
	viewport.add_child(second)
	for chapter in map.backgrounds.size():
		check(second.backgrounds[chapter] == map.backgrounds[chapter],"New map instances reuse the imported texture resource")
	viewport.queue_free()
	await process_frame
	print("BAKED MAP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
