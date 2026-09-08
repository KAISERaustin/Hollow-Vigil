extends "res://tests/rendered/campaign_runner.gd"

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.progress.path = "user://victory-cards-test.save"
	campaign.start_mission(0)
	await frame()
	campaign.run.phase = "victory"
	campaign.show_result()
	for dimensions in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await frame()
		check(campaign.ground_build.palette.is_visible_in_tree(), "Victory retains tower cards at " + str(dimensions))
		for button in campaign.ground_build.palette.find_children("Build_*", "Button", true, false):
			check(button.disabled, "Completed level disables tower construction")
		campaign.ground_build.arm("arrow")
		check(campaign.ground_build.kind.is_empty(), "Victory cannot arm tower placement")
		await Harness.capture(app, "campaign-victory-cards-" + str(dimensions.x))
	print("Victory cards: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
