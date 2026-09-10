extends "res://tests/test_runner.gd"
func run() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 60)
	root.gui_embed_subwindows = true
	var app = load("res://scripts/app/main.gd").new()
	app.load_saved_progress = false
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	for dimensions in [Vector2i(360,640),Vector2i(390,844),Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		app.slot_menu.new_game = {"mode":"creative","slot":0,"name":"", "entry":{},"choices":{}}
		app.slot_menu.show_review()
		for frame in 8: await process_frame
		var picker = app.slot_menu.find_child("SaveSlotChoice",true,false)
		picker.show_popup()
		for frame in 30: await process_frame
		check(picker.popup.size.y < 300, "Save-slot picker fits its three choices after form layout")
		check(picker.rows.get_child_count() == 3, "Only three save slots appear")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/actual-slot-%d.png" % dimensions.x)
		picker.choose(2)
		check(app.slot_menu.new_game.slot == 2 and not picker.popup.visible, "Third slot selects and dismisses")
	app.queue_free()
	for frame in 3: await process_frame
	print("SAVE SLOT PICKER: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)



