extends "res://tests/rendered/mobile_campaign_controls_runner.gd"
## Real Campaign save triggers and explicit upload taps against a fake transport.
const Cloud = preload("res://tests/support/private_cloud_fixture.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")
var network: Node

func idle_cloud() -> void:
	for seconds in [1.0, 3.0, 60.0, 300.0, 600.0]:
		if app.private_backups.has_method("_process"):
			app.private_backups.call("_process", seconds)
		await process_frame
	for frame in 5: await process_frame

func finish_cloud() -> void:
	for frame in 200:
		if not app.private_backups.busy: break
		await process_frame
	check(not app.private_backups.busy, "Explicit cloud request finishes")

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://manual-cloud-" + Cloud.Codec.uuid()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.audio.set_suspended(true)
	var previous := app.cloud
	network = Cloud.new()
	network.player_id = Cloud.Codec.uuid()
	network.refresh_token = "fixture"
	network.display_name = "Manual upload fixture"
	app.add_child(network)
	app.cloud = network
	for service in [app.public_builds, app.private_backups, app.bug_reports, app.change_log]:
		service.cloud = network
	previous.queue_free()
	var menu := app.slot_menu
	var backups := app.private_backups
	var code := Build.encode(Build.capture("campaign", null, {}, "level", 0, {"resources": true}, "Manual cloud fixture", "Private upload is a player action."))
	check(not code.is_empty() and menu.slots.save_shared(code), "Save a local build before signed-in gameplay")
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.begin_new(0)
		menu.new_game.name = "Manual cloud regression"
		menu.new_game.mode = "survival"
		menu.start_prepared(menu.prepare_new())
		campaign = app.campaign
		campaign.tutorials_enabled = false
		campaign.set_process(false)
		var before: int = network.sent.size()
		campaign.start_mission(0)
		var run_state: RefCounted = campaign.run
		run_state.game.data.balance = 10000.0
		check(run_state.build(run_state.mission.pads[0], "rapid"), "Planning edit saves locally")
		var tower_id: String = run_state.game.data.towers.keys()[0]
		for wave in run_state.mission.waves.size():
			campaign.reward_transition.dismiss()
			campaign.begin_wave()
			for tick in 2000:
				if run_state.phase != "wave": break
				run_state.tick(Balance.STEP)
				# Exercise real deaths/rewards without depending on battle balance.
				for enemy in run_state.game.combat.enemies:
					run_state.game.combat.hit(enemy, 1.0e9, tower_id)
			check(run_state.phase in ["planning", "victory"], "Real wave-clear callbacks run")
			await idle_cloud()
		check(run_state.phase == "victory" and run_state.game.data.kills > 0, "Enemy kills and final-wave victory execute")
		for tick in 30: run_state.tick(Balance.STEP)
		campaign.save_progress()
		campaign._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await idle_cloud()
		check(network.sent.size() == before, "Startup, edits, kills, wave boundaries, victory and focus changes send no backup requests")
		check(menu.campaign_slots.summary(0).completed == 1, "Victory remains saved locally")
		app.show_game_menu()
		menu.open_library(false)
		await press(named("BuildDetails"))
		await audit(menu.footer, "Manual upload footer")
		await capture("manual-cloud-build")
		network.fail_next = true
		await press(named("UploadBuild"))
		await finish_cloud()
		check(network.sent.size() == before + 1, "Only Upload build starts the private upload")
		await idle_cloud()
		check(network.sent.size() == before + 1, "Failed upload has no background retry")
		await press(named("UploadBuild"))
		await finish_cloud()
		check(network.sent.size() == before + 2 and network.sent.back().method == "put_private_build", "A second explicit tap retries only that build")
		check(network.publications.is_empty(), "Private Upload build never publishes to Community")
		await capture("manual-cloud-uploaded")
		menu.show_backups()
		before = network.sent.size()
		await idle_cloud()
		check(network.sent.size() == before, "Opening Backups does not start cloud work")
		await press(named("RecoverMyBuilds"))
		await finish_cloud()
		for request in network.sent.slice(before):
			check(not request.method.begins_with("put_"), "Recover My builds never uploads")
		await audit(menu.footer, "Manual bulk upload footer")
		await capture("manual-cloud-backups")
		menu.exit_game()
		await settle()
	app.queue_free()
	await process_frame
	print("MANUAL CLOUD: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
