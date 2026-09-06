extends SceneTree
var app: VigilApp
var failures: Array[String] = []
func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 60)
	call_deferred("run")
func settle() -> void:
	for i in range(8): await process_frame
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	app = VigilApp.new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	check(is_instance_valid(app.slot_menu) and not app.slot_active, "Startup opens menu without activating a slot")
	for viewport in [Vector2i(360,640),Vector2i(390,844),Vector2i(540,960)]:
		root.size = viewport
		root.content_scale_size = viewport
		await settle()
		var menu: Control = app.slot_menu
		check(menu.find_child("ScreenTitle",true,false).text == "Hollow Vigil", "Startup title")
		var title: Label = menu.find_child("ScreenTitle",true,false)
		check(absf(title.get_global_rect().get_center().x - viewport.x * 0.5) < 2, "Title centered")
		var campaign: Button = menu.find_child("OpenCampaign",true,false)
		var infinite: Button = menu.find_child("OpenInfinite",true,false)
		var mode_center := (campaign.get_global_rect().position.y + infinite.get_global_rect().end.y) * 0.5
		check(absf(mode_center - viewport.y * 0.5) < 3, "Modes vertically centered")
		for id in ["OpenCampaign", "OpenInfinite"]:
			var button: Button = menu.find_child(id,true,false)
			check(menu.scroll.get_global_rect().encloses(button.get_global_rect()), id + " fits " + str(viewport))
			check(absf(button.get_global_rect().get_center().x - viewport.x * 0.5) < 2, id + " horizontally centered")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/main-menu-" + str(viewport.x) + ".png")
		menu.find_child("OpenCampaign",true,false).pressed.emit()
		await settle()
		check(is_instance_valid(app.campaign) and app.campaign.page == "map", "Campaign opens map")
		app.campaign.close()
		await settle()
		check(menu.visible and app.game.suspended, "Campaign returns to main menu")
		menu.find_child("OpenInfinite",true,false).pressed.emit()
		await settle()
		check(menu.find_child("ScreenTitle",true,false).text == "Saved games", "Infinite opens slots")
		for slot in range(1,4): check(menu.find_child("SaveSlot%d" % slot,true,false) != null,"Slot exists")
		check(menu.find_child("OpenCampaign",true,false) == null, "Campaign removed from slots")
		menu.find_child("BackButton",true,false).pressed.emit()
		await settle()
		check(menu.find_child("OpenInfinite",true,false) != null,"Back returns to main")
	print("MAIN_MENU: %d failures" % failures.size())
	for failure in failures: push_error(failure)
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
