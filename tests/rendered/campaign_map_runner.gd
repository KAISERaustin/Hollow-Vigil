extends SceneTree

const Catalog = preload("res://scripts/campaign/catalog.gd")
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
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://biome-map-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.progress.allow_all = true
	campaign.mode = "creative"
	for viewport in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960), Vector2i(844,390)]:
		root.size = viewport
		root.content_scale_size = viewport
		campaign.show_map()
		await frame()
		var map: Control = campaign.find_child("CampaignWorldMap", true, false)
		var back: Button = campaign.find_child("CampaignBack", true, false)
		var back_bounds := back.get_global_rect()
		check(not campaign.parchment.visible, "Map removes the parchment backdrop")
		check(map.size.x == viewport.x and campaign.page_scroll.position.x == 0, "Biomes fill the available width")
		check(campaign.page_scroll.get_global_rect().end.y == viewport.y, "Biomes fill to the bottom edge")
		check(map.nodes.size() == Catalog.COUNT, "Every authored level remains on the map")
		for chapter in Catalog.CHAPTERS.size():
			campaign.page_scroll.scroll_vertical = roundi(chapter * Map.CHAPTER_HEIGHT)
			await frame()
			check(back.get_global_rect() == back_bounds, "Back remains fixed while scrolling")
			var bounds: Rect2 = map.chapter_rect(chapter)
			check(bounds.encloses(map.headings[chapter].get_rect()), "Chapter title fits its biome")
			for index in range(chapter * 5, chapter * 5 + 5):
				check(bounds.encloses(map.nodes[index].get_rect()), "Level marker fits its biome")
				check(bounds.encloses(map.labels[index].get_rect()), "Level label fits its biome")
				check(not map.nodes[index].get_rect().intersects(map.labels[index].get_rect()), "Level text does not overlap its marker")
			var capture := root.get_texture().get_image()
			var color := VigilTerrainArt.ground_color(Catalog.CHAPTERS[chapter].style)
			var sample := capture.get_pixel(1, roundi(map.global_position.y + bounds.position.y + 10))
			check(sample.is_equal_approx(color), "Biome artwork reaches the screen edge")
			capture.save_png("res://artifacts/campaign-biomes-%d-%d.png" % [viewport.x, chapter + 1])
		campaign.page_scroll.scroll_vertical = 0
		await frame()
		map.nodes[0].pressed.emit()
		await frame()
		check(campaign.page == "briefing" and campaign.run.mission.index == 0, "Map opens the selected level")
		check(campaign.parchment.visible and not campaign.map_navigation.visible, "Briefing restores the shared page presentation")
		campaign.show_map()
		await frame()
	campaign.progress.allow_all = false
	campaign.progress.data.completed_levels = 4
	campaign.show_map()
	await frame()
	var survival_map: Control = campaign.find_child("CampaignWorldMap", true, false)
	check(survival_map.nodes[3].completed and survival_map.nodes[4].current and survival_map.nodes[5].disabled, "Cleared, current and locked progression remains intact")
	app.queue_free()
	await process_frame
	print("CAMPAIGN MAP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
