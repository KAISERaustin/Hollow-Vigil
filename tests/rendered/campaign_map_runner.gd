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
	app.game.save_path = "user://biome-map-%d.save" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.open_campaign_slot(0, app.slot_menu.campaign_slots.create(0, "creative", "Map test"))
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.progress.allow_all = true
	campaign.mode = "creative"
	campaign.progress.data.completed_levels = 1
	campaign.progress.data.beaten_levels = [0, 4, 7]
	campaign.progress.data.current_level = 2
	for viewport in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = viewport
		root.content_scale_size = viewport
		campaign.show_map()
		await frame()
		var focus := root.gui_get_focus_owner()
		if focus != null: focus.release_focus()
		await frame()
		var map: Control = campaign.find_child("CampaignWorldMap", true, false)
		var back: Button = campaign.find_child("CampaignBack", true, false)
		var back_bounds := back.get_global_rect()
		check(not campaign.parchment.visible, "Map removes the parchment backdrop")
		check(map.size.x == viewport.x and campaign.page_scroll.position.x == 0, "Biomes fill the available width")
		check(campaign.page_scroll.get_global_rect().end.y == viewport.y, "Biomes fill to the bottom edge")
		check(map.nodes.size() == Catalog.COUNT, "Every authored level remains on the map")
		check(map.nodes[0].completed and map.nodes[4].completed and map.nodes[7].completed and not map.nodes[1].completed, "Creative defeated art follows individual victories, including skipped bosses")
		check(map.nodes[2].current and not map.nodes[1].current, "Creative highlights the active level")
		for chapter in Catalog.CHAPTERS.size():
			campaign.page_scroll.scroll_vertical = roundi(chapter * Map.CHAPTER_HEIGHT)
			await frame()
			check(back.get_global_rect() == back_bounds, "Back remains fixed while scrolling")
			var bounds: Rect2 = map.chapter_rect(chapter)
			check(bounds.encloses(map.headings[chapter].get_rect()), "Chapter title fits its biome")
			check(map.backgrounds[chapter] != null and map.backgrounds[chapter].get_size() == Vector2(540,1920), "Chapter has a baked background and completed-road variant")
			var scenery: Array = preload("res://tests/support/baked_map_fixture.gd").sites(chapter, map.size.x)
			var architecture_count := scenery.filter(func(site):return site.major).size()
			var scenery_count := scenery.filter(func(site):return site.kind!="ground_marks").size()
			check(architecture_count==4,"Four scenery landmarks at %d / chapter %d (found %d)"%[viewport.x,chapter+1,architecture_count])
			check(scenery_count>=9,"Populated landscape at %d / chapter %d (found %d)"%[viewport.x,chapter+1,scenery_count])
			for site in scenery:
				check(preload("res://tests/support/baked_map_fixture.gd").clear_site(site.rect,map,chapter),"Scenery clears labels, destinations, trails and water at %d / chapter %d"%[viewport.x,chapter+1])
			for index in range(chapter * 5, chapter * 5 + 5):
				check(bounds.encloses(map.nodes[index].get_rect()), "Level marker fits its biome")
				check(bounds.encloses(map.labels[index].get_rect()), "Level label fits its biome")
				check(not map.nodes[index].get_rect().intersects(map.labels[index].get_rect()), "Level text does not overlap its marker")
				check(map.nodes[index].size.x>=48 and map.nodes[index].size.y>=48,"Illustrated destinations retain large touch targets")
				var clear_text := true
				for road in map.chapter_roads(chapter):
					for point in road:
						for label: Label in map.labels[index].get_children():
							var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
							var rect := Rect2(map.labels[index].position + label.position, Vector2(minf(width, label.size.x), label.size.y))
							if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT: rect.position.x += label.size.x - rect.size.x
							if rect.grow(4).has_point(point): clear_text = false
				check(clear_text, "Winding trail stays clear of level %d text at %d" % [index+1, viewport.x])
			var capture := root.get_texture().get_image()
			var color := VigilTerrainArt.ground_color(Catalog.CHAPTERS[chapter].style)
			var sample := capture.get_pixel(1, roundi(map.global_position.y + bounds.position.y + 10))
			check(sample.is_equal_approx(color), "Biome artwork reaches the screen edge")
			capture.save_png("res://artifacts/campaign-biomes-%d-%d.png" % [viewport.x, chapter + 1])
			# Inspect the bottom of each chapter as well as the top on short screens.
			campaign.page_scroll.scroll_vertical=roundi((chapter+1)*Map.CHAPTER_HEIGHT-campaign.page_scroll.size.y)
			await frame()
			root.get_texture().get_image().save_png("res://artifacts/campaign-biomes-%d-%d-lower.png"%[viewport.x,chapter+1])
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
	campaign.close()
	await frame()
	app.show_game_menu()
	app.slot_menu.game_type = "campaign"
	app.slot_menu.campaign_slots.base_path = "user://biome-map-slot-" + str(Time.get_ticks_usec())
	var saved: Dictionary = app.slot_menu.campaign_slots.create(0, "creative", "Test")
	saved.beaten_levels = [4, 7]
	saved.current_level = 2
	check(app.slot_menu.campaign_slots.save_slot(0, saved), "Save Creative map state in its campaign slot")
	saved = app.slot_menu.campaign_slots.summary(0)
	app.open_campaign_slot(0, saved)
	campaign = app.campaign
	campaign.set_process(false)
	for viewport in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = viewport
		root.content_scale_size = viewport
		campaign.show_map()
		await frame()
		check(campaign.map_heading.get_child(0).get_child(1).text == "Test", "Saved campaign keeps its own title")
		check(campaign.find_child("CampaignSavedGames", true, false) != null, "Saved map keeps Back to saved games")
		check(campaign.layout.get_child_count() == 1, "Saved map contains only the full-width biomes")
		root.get_texture().get_image().save_png("res://artifacts/campaign-biomes-saved-%d.png" % viewport.x)
		campaign.page_scroll.scroll_vertical = roundi(campaign.page_scroll.get_v_scroll_bar().max_value)
		await frame()
		var saved_map: Control = campaign.find_child("CampaignWorldMap", true, false)
		check(saved_map.nodes[4].completed and saved_map.nodes[7].completed and saved_map.nodes[2].current and not saved_map.nodes[0].completed, "Saved Creative slot restores skipped victories and active marker")
		check(saved_map.nodes[-1].get_global_rect().end.y <= viewport.y, "Final level remains reachable at the bottom of a saved map")
		check(is_equal_approx(saved_map.get_global_rect().end.y, viewport.y), "Last biome fills the bottom with no parchment footer")
	app.queue_free()
	await process_frame
	print("CAMPAIGN MAP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
