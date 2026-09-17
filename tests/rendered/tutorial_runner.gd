extends SceneTree
const History = preload("res://scripts/campaign/tutorial_history.gd")
const Lessons = preload("res://scripts/campaign/tutorial_catalog.gd")
const Run = preload("res://scripts/campaign/run.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	root.gui_embed_subwindows = true
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 12: await process_frame

func run() -> void:
	var history := History.new()
	history.path = "user://tutorial-test.cfg"
	check(history.acknowledge(["construction", "waves"]), "History saves")
	var restored := History.new()
	restored.path = history.path
	restored.load_history()
	check(not restored.allows("construction") and restored.allows("management"), "History survives a fresh instance")
	for index in 25:
		var mission := Run.new(index)
		var tip := Lessons.milestone(mission, restored)
		check(not tip.is_empty(), "Every tower and tier milestone has an introduction")
		if index < 24:
			check(tip.rows[0].tier == int(index / 8.0) + 1, "Tier matches progression")
	check(restored.acknowledge([], true), "Skip all saves")
	var skipped := History.new()
	skipped.path = history.path
	skipped.load_history()
	check(not skipped.allows("future-tip"), "Skip all survives restart and suppresses future tips")
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://tutorial-fixture.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.private_backups.enabled = false
	app.audio.set_suspended(true)
	app.slot_menu.show_slots()
	var saved: Dictionary = app.slot_menu.campaign_slots.create(0, "survival", "Tutorial test")
	app.open_campaign_slot(0, saved)
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.tutorials_enabled = true
	campaign.tutorial_history.path = "user://tutorial-campaign-test.cfg"
	campaign.start_mission(0)
	await settle()
	check(campaign.tutorial_active(), "First battle introduces construction")
	var popup: PopupPanel = campaign.tutorial_popup
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		popup.fit_content()
		await settle()
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(Rect2(Vector2(popup.position), Vector2(popup.size))), "Popup fits portrait viewport")
		check(popup.confirm.size.y >= 48, "Acknowledgment has a touch-sized target")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/tutorial-%d.png" % dimensions.x)
	var before: float = campaign.accumulator
	campaign._process(1.0)
	check(campaign.accumulator == before, "Tutorial freezes simulation")
	campaign.paused = true
	campaign.go_back()
	check(not campaign.tutorial_active() and campaign.paused, "Back dismisses and preserves prior pause state")
	campaign.introduce_battle()
	await settle()
	# First tower's own milestone may now appear; construction must not repeat.
	check(not campaign.tutorial_history.allows("construction"), "Construction stays acknowledged")
	if campaign.tutorial_active(): campaign.go_back()
	var socket: Dictionary = campaign.run.mission.sockets[0]
	check(campaign.run.build(socket.index, "rapid"), "Build fixture succeeds")
	campaign.tutorial_delay = 0
	campaign._process(0)
	check(campaign.tutorial_active(), "First placed tower introduces waves")
	campaign.go_back()
	campaign.begin_wave()
	check(campaign.tutorial_active() and campaign.run.phase == "planning", "New enemies appear before combat begins")
	campaign.go_back()
	check(campaign.run.phase == "planning" and not campaign.tutorial_active(), "Back from encounter does not start combat")
	# Reintroduce an unseen encounter to exercise the explicit continuation.
	campaign.tutorial_history.seen.erase("enemy/basic")
	campaign.begin_wave()
	campaign.tutorial_popup.confirm.pressed.emit()
	check(campaign.run.phase == "wave" and not campaign.tutorial_active(), "Encounter acknowledgment starts requested wave once")
	check(Lessons.encounters(campaign.run, campaign.tutorial_history).is_empty(), "Seen enemies do not repeat")
	var rows: Array = []
	for kind in Balance.ENEMIES:
		rows.append({"category": "enemies", "kind": kind, "name": Balance.ENEMIES[kind].name, "text": Balance.ENEMIES[kind].description})
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		campaign.show_tutorial({"ids": ["long-fixture"], "title": "New enemies ahead", "body": "Prepare your defenses before the next wave.", "rows": rows})
		await settle()
		popup = campaign.tutorial_popup
		check(popup.size.y <= dimensions.y - 24, "Long encounter roster stays inside safe area")
		popup.scroll.scroll_vertical = 100000
		await settle()
		check(popup.scroll.scroll_vertical > 0, "Long roster scrolls")
		var last: Control = popup.details.get_child(popup.details.get_child_count() - 1)
		check(last.get_global_rect().end.y <= popup.scroll.get_global_rect().end.y + 1, "Last enemy is reachable")
		check(popup.confirm.get_global_rect().end.y <= popup.size.y, "Fixed action stays reachable")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/tutorial-roster-%d.png" % dimensions.x)
		campaign.go_back()
	app.queue_free()
	await settle()
	print("TUTORIAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
