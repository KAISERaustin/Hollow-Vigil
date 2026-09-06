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
		campaign.find_child("CampaignLevel1",true,false).pressed.emit()
		await frame()
		check(campaign.page == "briefing", "Campaign node opens the authored mission briefing")
		await Harness.capture(app,"campaign-briefing-"+str(viewport.x))
		campaign.find_child("BeginCampaignMission",true,false).pressed.emit()
		await frame()
		var start: Button = campaign.find_child("StartCampaignWave",true,false)
		check(Rect2(Vector2.ZERO,Vector2(viewport)).encloses(start.get_global_rect()), "Start wave fits " + str(viewport))
		var socket: Dictionary = campaign.run.mission.sockets[1]
		# Exercise the same hit testing used by mouse and emulated touch.
		campaign.board.pick(campaign.board.screen(socket.position))
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
		for tick in range(100): campaign.run.tick(Balance.STEP)
		campaign.refresh()
		await frame()
		check(not campaign.run.game.combat.enemies.is_empty(), "Wave button starts visible authored enemies")
		await Harness.capture(app,"campaign-battle-"+str(viewport.x))
		campaign.show_map()
		campaign.resume_checkpoint()
		check(campaign.run.phase == "planning" and campaign.run.game.data.towers.size() == 1, "Leaving and resuming restores the preparation checkpoint")
		await frame()
	var campaign_path: String = campaign.progress.path
	campaign.close()
	await frame()
	check(app.campaign == null and app.hud.visible and not app.game.suspended, "Closing campaign restores sandbox controls")
	check(app.game.data.balance == original.balance and app.game.data.towers == original.towers and app.game.data.regions == original.regions, "Campaign transactions leave sandbox progress unchanged")
	for base in [app.game.save_path,campaign_path]:
		for suffix in ["", ".tmp", ".bak"]:
			DirAccess.remove_absolute(base+suffix)
	app.queue_free()
	await process_frame
	print("Rendered campaign: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
