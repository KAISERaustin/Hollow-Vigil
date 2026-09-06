extends SceneTree

const Harness = preload("res://tests/rendered/visual_smoke.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func tap(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await frame()

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-ui-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	var original: Dictionary = app.game.snapshot().duplicate(true)
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	check(app.game.suspended and not app.hud.visible, "Campaign suspends and covers the sandbox")
	check(campaign.find_child("CampaignLevel20",true,false).disabled, "Later campaign nodes start locked")
	for viewport in [Vector2i(360,640),Vector2i(390,844),Vector2i(540,960)]:
		root.size = viewport
		root.content_scale_size = viewport
		campaign.show_map()
		await frame()
		check(Rect2(Vector2.ZERO,Vector2(viewport)).encloses(campaign.layout.get_global_rect()), "World map fits " + str(viewport))
		await Harness.capture(app,"campaign-map-"+str(viewport.x))
		for chapter in range(4):
			var gate: Button = campaign.find_child("CampaignLevel%d" % (chapter * 5 + 5), true, false)
			check(gate.gate != null and gate.size == Vector2(80,120), "Chapter destination uses its building artwork")
			check(gate.position.x > gate.get_parent().size.x * 0.5, "Chapter destination sits at the right end of the road")
			check(gate.position.y + gate.size.y <= chapter * 450 + 435, "Building destination fits its chapter")
		campaign.find_child("CampaignLevel1",true,false).pressed.emit()
		await frame()
		check(campaign.page == "briefing", "Campaign node opens the authored mission briefing")
		await Harness.capture(app,"campaign-briefing-"+str(viewport.x))
		campaign.find_child("BeginCampaignMission",true,false).pressed.emit()
		await frame()
		var start: Button = campaign.find_child("StartCampaignWave",true,false)
		check(Rect2(Vector2.ZERO,Vector2(viewport)).encloses(start.get_global_rect()), "Start wave fits " + str(viewport))
		var socket: Dictionary = campaign.run.mission.sockets[1]
		await tap(campaign.board.global_position + campaign.board.screen(socket.position))
		await frame()
		check(campaign.dialog.visible, "Battlefield socket opens construction")
		var build: Button = campaign.find_child("CampaignBuild_rapid",true,false)
		check(build != null and not build.disabled, "Mission opening affords an Ashneedle")
		build.pressed.emit()
		await frame()
		check(not campaign.run.tower_at(socket.index).is_empty(), "Build action creates a real combat tower")
		campaign.board.pick(campaign.board.screen(socket.position))
		await frame()
		campaign.find_child("CampaignUpgrade_",true,false).pressed.emit()
		await frame()
		check(campaign.run.game.data.towers[campaign.run.tower_at(socket.index)].level == 2, "Upgrade uses actual campaign gold")
		await Harness.capture(app,"campaign-tower-"+str(viewport.x))
		check(Rect2(Vector2.ZERO,Vector2(viewport)).encloses(campaign.dialog_card.get_global_rect()), "Tower dialog fits " + str(viewport))
		campaign.dialog.hide()
		start.pressed.emit()
		campaign.find_child("CampaignPause",true,false).pressed.emit()
		var time_before: float = campaign.run.game.data.active_seconds
		campaign._process(0.1)
		check(campaign.run.game.data.active_seconds == time_before, "Pause stops the campaign clock")
		campaign.find_child("CampaignPause",true,false).pressed.emit()
		for tick in range(100): campaign.run.tick(Balance.STEP)
		campaign.refresh()
		await frame()
		check(not campaign.run.game.combat.enemies.is_empty(), "Wave button starts visible authored enemies")
		await Harness.capture(app,"campaign-battle-"+str(viewport.x))
		campaign.show_map()
		campaign.start_mission(0)
		check(campaign.run.phase == "planning" and campaign.run.game.data.towers.is_empty(), "Leaving an unfinished level restarts it without saved towers")
		await frame()
	# Mission tuning must reach both menu quotes and the shared transactions.
	campaign.start_mission(0)
	campaign.run.game.data.settings.developer_balance = {"towers": {"rapid": {"cost": 70.0, "damage": 12.0}, "rapid:2": {"cost": 35.0}}}
	campaign.show_socket(6)
	await frame()
	var tuned_build: Button = campaign.find_child("CampaignBuild_rapid", true, false)
	check(tuned_build.text.contains("70 gold"), "Campaign build quote reflects mission tuning")
	tuned_build.pressed.emit()
	campaign.show_socket(6)
	await frame()
	var tuned_upgrade: Button = campaign.find_child("CampaignUpgrade_", true, false)
	check(tuned_upgrade.text.contains("35 gold"), "Campaign upgrade quote reflects mission tuning")
	var gold: float = campaign.run.game.data.balance
	tuned_upgrade.pressed.emit()
	await frame()
	check(campaign.run.game.data.balance == gold - 35.0, "Campaign upgrade charge matches the displayed tuned price")
	var tuned_tower: Dictionary = campaign.run.game.data.towers[campaign.run.tower_at(6)]
	check(Balance.tower_stats(tuned_tower, campaign.run.game.tuning).damage == 20.0, "Campaign combat resolves tuned tier damage")
	# Inspect a later-region briefing and the final completion UI independently
	# of the full legal-combat playthrough covered by campaign_balance_runner.
	campaign.progress.data.completed_levels = 19
	campaign.show_briefing(19)
	await frame()
	await Harness.capture(app,"campaign-final-briefing")
	campaign.start_mission(19)
	campaign.run.phase = "victory"
	campaign.run.health = 20
	campaign.show_result()
	await frame()
	check(campaign.progress.data.completed_levels == 20 and campaign.dialog.visible, "Final victory saves completion and presents the ending")
	check(campaign.find_child("NextCampaignLevel",true,false) == null, "Final victory cannot open a nonexistent level 21")
	await Harness.capture(app,"campaign-complete")
	var campaign_path: String = campaign.progress.path
	campaign.close()
	await frame()
	check(app.campaign == null and app.hud.visible and not app.game.suspended, "Closing campaign restores sandbox controls")
	check(app.game.data.balance == original.balance and app.game.data.towers == original.towers and app.game.data.regions == original.regions, "Campaign transactions leave sandbox progress unchanged")
	for base in [app.game.save_path,campaign_path]:
		for suffix in ["", ".tmp", ".bak"]:
			DirAccess.remove_absolute(base+suffix)
	app.audio.set_suspended(true)
	app.audio.music.stop()
	app.audio.music.stream = null
	for pool in app.audio.voices.values():
		for voice in pool:
			voice.stop()
			voice.stream = null
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	print("Rendered campaign: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
