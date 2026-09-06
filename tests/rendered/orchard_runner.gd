extends "res://tests/test_runner.gd"

const Harness = preload("res://tests/rendered/visual_smoke.gd")

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game = VigilState.new(879)
	app.game.save_path = "user://orchard-rendered.save"
	clean_test_save(app.game.save_path)
	var gate := preload("res://tests/support/orchard_fixture.gd").populate(app.game)
	gate = VigilWorld.key(VigilWorld.Orchard.cluster(879)[1])
	app.game.data.balance = 100000.0
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.field.set_process(false)
	app.field.set_unrestricted_camera(true)
	for pad in range(4):
		app.game.economy.build(Balance.TOWERS.keys()[pad], gate, pad)
	for kind in Balance.ORCHARD_KINDS:
		var enemy := app.game.combat.spawn(gate,kind)
		enemy.pos = enemy.path[7 + Balance.ORCHARD_KINDS.find(kind) * 4]
	for viewport in [Vector2i(360,640),Vector2i(390,844),Vector2i(540,960)]:
		root.size = viewport
		root.content_scale_size = viewport
		app.panels.close_sheet()
		app.field.camera = VigilWorld.center(gate)
		app.field.zoom = 1.0
		app.field.queue_redraw()
		await frame()
		await Harness.capture(app,"orchard-world-" + str(viewport.x))
		await Harness.tap(app,app.field.global_position + app.field.screen(VigilWorld.center(gate)), viewport.x == 390)
		await frame()
		check(app.panels.mode == "rift" and app.panels.selection_region == gate,"Orchard portal opens via mouse/touch at " + str(viewport.x))
		var content := ""
		for label in app.panels.find_children("*","Label",true,false):
			content += label.text
		check(content.contains("Briarling") and content.contains("Veil Widow") and content.contains("Coffinbound"),"Portal explains every exclusive enemy")
		check(not content.contains("Attune"),"Orchard offers no misleading ordinary attunements")
		await Harness.capture(app,"orchard-portal-" + str(viewport.x))
		app.panels.show_developer_controls()
		await frame()
		var controls := app.panels.find_child("DeveloperControls",true,false)
		controls.show_category("enemies")
		for kind in Balance.ORCHARD_KINDS:
			var index := -1
			for item in range(controls.selector.item_count):
				if controls.selector.get_item_metadata(item) == kind: index = item
			check(index >= 0,"Developer selector includes " + kind)
			controls.selector.select(index)
			controls.selector.item_selected.emit(index)
			await frame()
			app.panels.content_scroll.scroll_vertical = 0
			await Harness.capture(app,"orchard-developer-" + kind + "-" + str(viewport.x))
			var number: SpinBox = controls.inputs.hp
			app.panels.content_scroll.ensure_control_visible(number.get_parent())
			await frame()
			var value: float = 450.0 + viewport.x
			number.get_line_edit().text = str(value)
			# Closing the panel must commit a typed field even without Enter.
			controls.commit_fields()
			check(app.game.tuning.enemies[kind].hp == value,"Typed Orchard health commits from developer controls")
		app.panels.close_sheet()
		app.persist()
		var restored := VigilSaveStore.new().read_candidate(app.game.save_path)
		check(not restored.is_empty() and restored.settings.developer_balance == app.game.tuning,"Developer edits persist from the actual app")
	# Reuse the existing input harness to exercise all stats and reset behavior.
	await preload("res://tests/rendered/developer_controls_checks.gd").run(app,Harness,failures)
	clean_test_save(app.game.save_path)
	app.queue_free()
	await process_frame
	print("ORCHARD UI: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
