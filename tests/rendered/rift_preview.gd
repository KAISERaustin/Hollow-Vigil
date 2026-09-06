extends SceneTree

const Art = preload("res://scripts/rendering/terrain_art.gd")
const Rifts = preload("res://scripts/rendering/rift_art.gd")
var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1040, 560)
	root.content_scale_size = root.size
	var canvas := Control.new()
	root.add_child(canvas)
	canvas.draw.connect(func():
		for index in range(4):
			var style: String = VigilWorld.STYLES[index]
			var origin := Vector2(index * 260, 0)
			canvas.draw_rect(Rect2(origin, Vector2(260, 560)), Art.ground_color(style))
			canvas.draw_string(VigilInterface.font(), origin + Vector2(18, 40), Balance.rift_name(style), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.INK)
			Rifts.draw(canvas, style, origin + Vector2(130, 170), 2.5)
			Art.scenery(canvas, style, origin + Vector2(35, 230), 32)
			Art.sentinel(canvas, "rapid", origin + Vector2(180, 300), 1.5, 2)
			for kind_index in range(4):
				var pos := origin + Vector2(40 + kind_index * 57, 390)
				Art.enemy(canvas, Balance.ENEMIES.keys()[kind_index], pos, 1.1)
				Rifts.enemy_mark(canvas, style, pos, 1.1)
			Rifts.draw(canvas, style, origin + Vector2(130, 495), 1.0)
	)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/rift-art-preview.png")
	canvas.queue_free()
	await process_frame
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://rift-preview.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	for viewport in [Vector2i(540, 960), Vector2i(360, 640)]:
		root.size = viewport
		root.content_scale_size = viewport
		app.game.data.settings.text_scale = 1.5
		app.apply_ui_preferences()
		app.panels.show_developer_controls()
		await process_frame
		var controls = app.find_child("DeveloperControls", true, false)
		controls.show_category("rifts")
		controls.sliders.strength.value = 50.0
		if Balance.rift_strength("ashen_forge", app.game.tuning) != 50.0:
			failures += 1
		for i in range(6):
			await process_frame
		for tab in controls.tabs.values():
			if tab.get_global_rect().end.x > viewport.x:
				push_error("Rift tab overflows narrow viewport")
				failures += 1
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/rift-controls-%d.png" % viewport.x)
	print("RIFT RENDER: %d failures" % failures)
	quit(failures)
