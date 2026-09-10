extends SceneTree
## Compare every campaign entrance with its biome's native portal artwork.

const Catalog = preload("res://scripts/campaign/catalog.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Board = preload("res://scripts/campaign/board.gd")
const World = preload("res://scripts/content/catalogs/world.gd")
const Rifts = preload("res://scripts/rendering/actors/rift_art.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")
const SIZES := [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]

class PortalCanvas extends Node2D:
	var entrances: Array = []
	func _draw() -> void:
		for entry in entrances:
			Rifts.draw_wave(self, entry.style, entry.at, entry.zoom, entry.groups, entry.lane)

var checks := 0
var failures := 0
var boards_checked := 0
var lanes_checked := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 420.0)
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

func viewport_for(dimensions: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	await native_portals()
	for dimensions in SIZES:
		root.size = dimensions
		root.content_scale_size = dimensions
		await campaign_boards(dimensions)
	print("CAMPAIGN PORTALS: %d checks, %d boards, %d entrances, %d failures" % [checks, boards_checked, lanes_checked, failures])
	quit(1 if failures else 0)

func native_portals() -> void:
	var viewport := viewport_for(Vector2i(256, 256))
	var canvas := PortalCanvas.new()
	viewport.add_child(canvas)
	var fingerprints: Array[PackedByteArray] = []
	var gallery := viewport_for(Vector2i(900, 560))
	var background := ColorRect.new()
	background.size = gallery.size
	background.color = UI.PANEL
	gallery.add_child(background)
	for index in range(World.ALL_STYLES.size()):
		var style: String = World.ALL_STYLES[index]
		canvas.entrances = [{"style": style, "at": Vector2(128, 152), "zoom": 1.65, "groups": [], "lane": 0}]
		canvas.queue_redraw()
		await frame()
		var picture := viewport.get_texture().get_image()
		check(not picture.is_invisible(), style + " has native portal artwork")
		check(not picture.get_data() in fingerprints, style + " has a distinct portal silhouette and colors")
		check(Rect2i(0, 0, 256, 256).encloses(picture.get_used_rect().grow(3)), style + " artwork retains transparent padding")
		fingerprints.append(picture.get_data())
		check(picture.save_png("res://artifacts/campaign-portals-native-%s.png" % style) == OK, "Save " + style + " portal reference")
		var tile_position := Vector2((index % 3) * 300, floori(index / 3.0) * 280)
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(picture)
		sprite.position = tile_position + Vector2(150, 120)
		gallery.add_child(sprite)
		var label := Label.new()
		label.text = Balance.rift_name(style)
		label.theme = UI.theme()
		label.position = tile_position + Vector2(8, 240)
		label.size = Vector2(284, 32)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gallery.add_child(label)
	await frame()
	check(gallery.get_texture().get_image().save_png("res://artifacts/campaign-portals-gallery.png") == OK, "Save all six portal kinds for visual review")
	viewport.free()
	gallery.free()

func campaign_boards(dimensions: Vector2i) -> void:
	var reference := viewport_for(dimensions)
	var canvas := PortalCanvas.new()
	reference.add_child(canvas)
	for index in range(Catalog.COUNT):
		var board := Board.new()
		board.run = Run.new(index)
		board.size = Vector2(dimensions)
		root.add_child(board)
		board.set_process(false)
		await frame()
		var expected_style: String = World.ALL_STYLES[index / Catalog.LEVELS_PER_CHAPTER]
		check(board.run.mission.style == expected_style, "Level %d uses its chapter's biome" % (index + 1))
		canvas.entrances = []
		for lane in range(board.run.mission.routes.size()):
			var at: Vector2 = board.screen(board.run.mission.routes[lane][0])
			check(Rect2(Vector2.ZERO, Vector2(dimensions)).has_point(at), "Level %d lane %d is visible at %d" % [index + 1, lane, dimensions.x])
			canvas.entrances.append({"style": expected_style, "at": at, "zoom": board.zoom, "groups": board.run.mission.waves[0], "lane": lane})
		check(canvas.entrances.size() == Catalog.MISSIONS[index].roads.size(), "Every authored entrance receives one biome portal")
		canvas.queue_redraw()
		await frame()
		var actual := root.get_texture().get_image()
		var expected := reference.get_texture().get_image()
		check(Rect2i(Vector2i.ZERO, dimensions).encloses(expected.get_used_rect().grow(1)), "Level %d portal outlines fit the portrait viewport at %d" % [index + 1, dimensions.x])
		for entrance in canvas.entrances:
			compare_portal(actual, expected, entrance, index, dimensions)
			lanes_checked += 1
		if index % Catalog.LEVELS_PER_CHAPTER == 0:
			check(actual.save_png("res://artifacts/campaign-portals-board-%s-%d.png" % [expected_style, dimensions.x]) == OK, "Save campaign biome overview")
		boards_checked += 1
		board.free()
		await process_frame
	reference.free()

func compare_portal(actual: Image, expected: Image, entrance: Dictionary, index: int, dimensions: Vector2i) -> void:
	# Solid reference pixels prove that terrain or another portal did not cover
	# the actual entrance. Ignore antialiased edges that blend with world ground.
	var area := Rect2i(Rect2(entrance.at - Vector2(58, 65) * entrance.zoom, Vector2(116, 112) * entrance.zoom))
	area = area.intersection(Rect2i(Vector2i.ZERO, dimensions))
	var samples := 0
	var different := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var wanted := expected.get_pixel(x, y)
			if wanted.a < 0.999:
				continue
			var shown := actual.get_pixel(x, y)
			samples += 1
			if absf(shown.r - wanted.r) + absf(shown.g - wanted.g) + absf(shown.b - wanted.b) > 0.04:
				different += 1
	var label := "Level %d %s lane %d at %d" % [index + 1, entrance.style, entrance.lane, dimensions.x]
	check(samples > 200, label + " contains visible portal artwork")
	check(different == 0, label + " matches its biome's native draw_wave artwork (%d / %d pixels differ)" % [different, samples])
	if different > 0:
		actual.save_png("res://artifacts/campaign-portals-mismatch-%02d-%d.png" % [index + 1, dimensions.x])
		expected.save_png("res://artifacts/campaign-portals-expected-%02d-%d.png" % [index + 1, dimensions.x])
