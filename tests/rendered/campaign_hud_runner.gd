extends SceneTree
const UI = preload("res://scripts/ui/shared/interface.gd")
const Harness = preload("res://tests/rendered/visual_smoke.gd")
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
	for step in 5: await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-hud-%d.save" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.progress.allow_all = true
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		for level in [0, 3, 5, 11, 15, 20, 25]:
			campaign.speed = 1.0
			campaign.start_mission(level)
			await frame()
			var field: Control = campaign.board
			var hud: Control = campaign.floating_hud
			var bounds := Rect2(Vector2.ZERO, Vector2(viewport))
			check(field.global_position.x == 0 and field.get_global_rect().end == bounds.end, "Terrain fills the screen below the bar")
			check(field.size.y > viewport.y * 0.85, "Terrain owns over 85 percent of phone height")
			check(field.find_child("CampaignMapBorder", true, false) == null and not campaign.parchment.visible, "No frame encloses the battlefield")
			check(field.get_global_rect().encloses(hud.header.get_global_rect()), "Top information row fits inside terrain")
			check(hud.identity.get_child_count() == 1 and hud.title.text == "%d. %s" % [level + 1, campaign.run.mission.name], "Identity contains the level number and name")
			check(hud.header.get_child_count() == 3, "Level, gold and wave have three separate cards")
			var card_end: float = hud.header.global_position.x - UI.CARD_GAP
			for card in [hud.identity, hud.left_card, hud.right_card]:
				check(field.get_global_rect().encloses(card.get_global_rect()), "Floating card stays within the battlefield")
				check(is_equal_approx(card.global_position.y, hud.header.global_position.y) and is_equal_approx(card.size.y, hud.header.size.y), "All three cards share the same top edge and height")
				check(card.global_position.x >= card_end + UI.CARD_GAP, "Cards stay in one row with clear gaps")
				card_end = card.get_global_rect().end.x
				check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Card surface passes gestures to terrain")
				check(card.get_theme_stylebox("panel").border_width_left == UI.OUTLINE, "Floating cards use the shared ink border")
			check(is_equal_approx(card_end, hud.header.get_global_rect().end.x), "Three cards fill the entire row")
			var next_x := 0.0
			for control in campaign.game_toolbar.get_children():
				check(bounds.encloses(control.get_global_rect()) and control.size.x >= UI.TARGET and control.size.y >= UI.TARGET, "Every toolbar action fits and retains its touch target")
				check(control.global_position.x >= next_x and control.get_global_rect().end.y < field.global_position.y, "Controls stay in one row above terrain")
				next_x = control.get_global_rect().end.x + UI.CARD_GAP
				for state in ["normal", "hover", "pressed", "disabled"]:
					check(control.get_theme_stylebox(state).border_width_left == UI.OUTLINE, "Toolbar button borders remain uniform in every state")
			for caption in [hud.title, hud.left_value, hud.right_value]:
				check(caption.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Floating text passes gestures to terrain")
				check(caption.get_parent().get_global_rect().encloses(caption.get_global_rect()) and caption.get_visible_line_count() == caption.get_line_count(), "Card text wraps without clipping")
			if level in [0, 3, 11] or viewport.x == 390:
				await Harness.capture(app, "campaign-hud-%02d-%d" % [level + 1, viewport.x])
			var bar_size: Vector2 = campaign.battle_bar.size
			await Harness.tap(app, campaign.wave_button.get_global_rect().get_center(), true)
			check(campaign.run.phase == "wave" and campaign.wave_button.disabled, "Top wave action starts combat through touch input")
			await Harness.tap(app, campaign.pause_button.get_global_rect().get_center(), true)
			var before: float = campaign.run.wave_time
			campaign._process(0.1)
			check(campaign.paused and campaign.run.wave_time == before, "Top pause action stops combat")
			await Harness.tap(app, campaign.speed_button.get_global_rect().get_center(), true)
			check(campaign.speed_button.text == "%d×" % int(campaign.speed), "Speed stays readable while paused")
			await frame()
			check(campaign.battle_bar.size == bar_size, "Toolbar height and width stay stable during combat")
			if level in [3, 11]:
				await Harness.capture(app, "campaign-hud-active-%d" % viewport.x)
			await Harness.tap(app, campaign.find_child("CampaignWaves", true, false).get_global_rect().get_center(), true)
			check(campaign.dialog.visible and campaign.waves_dialog, "Top Waves action opens details")
			campaign.close_dialog()
			await frame()
			# A gesture beginning on a floating label must still pan the map.
			var at: Vector2 = hud.title.get_global_rect().get_center()
			var press := InputEventScreenTouch.new()
			press.index = 0
			press.position = at
			press.pressed = true
			Input.parse_input_event(press)
			await process_frame
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = at + Vector2(32, 0)
			drag.relative = Vector2(32, 0)
			Input.parse_input_event(drag)
			await process_frame
			press.pressed = false
			press.position = drag.position
			Input.parse_input_event(press)
			await frame()
			check(field.dragged and field.touches.is_empty(), "Touch drag crosses floating identity without interception")
			if level == 11:
				var checkpoint: Dictionary = campaign.run.checkpoint()
				campaign.run = campaign.Run.from_checkpoint(checkpoint)
				campaign.connect_run()
				campaign.show_battle(true)
				await frame()
				check(campaign.paused and campaign.wave_button.disabled, "Restored wave retains paused playback and numbered level identity")
				campaign._process(0.1)
				check(campaign.run.wave_time == 0.0, "Restored wave waits without advancing")
				await Harness.tap(app, campaign.pause_button.get_global_rect().get_center(), true)
				campaign._process(0.1)
				check(not campaign.paused and campaign.run.wave_time > 0.0, "Restored wave resumes through its top playback action")
			await Harness.tap(app, campaign.game_toolbar.menu_button.get_global_rect().get_center(), true)
			check(campaign.page == "map", "Top back action returns to the campaign map")
		campaign.start_mission(3)
		await frame()
		var expanded_hud: Control = campaign.floating_hud
		expanded_hud.title.text = "The Old Watch at the Forgotten Crossing"
		expanded_hud.left_value.text = "%s gold" % Balance.money(999999999)
		expanded_hud.right_value.text = "Wave 100 / 100"
		expanded_hud.notice.text = "Progress saved on this device."
		expanded_hud.notice.show()
		expanded_hud.fit()
		await frame()
		for card in [expanded_hud.identity, expanded_hud.left_card, expanded_hud.right_card, expanded_hud.notice_card]:
			check(campaign.board.get_global_rect().encloses(card.get_global_rect()), "Long HUD content remains inside the phone")
		check(not expanded_hud.left_card.get_global_rect().intersects(expanded_hud.right_card.get_global_rect()), "Large values do not overlap")
		check(expanded_hud.identity.get_global_rect().encloses(expanded_hud.title.get_global_rect()), "Long title wraps inside its card")
		for caption in [expanded_hud.title, expanded_hud.left_value, expanded_hud.right_value]:
			check(caption.get_visible_line_count() == caption.get_line_count(), "Long HUD text remains completely visible")
		await Harness.capture(app, "campaign-hud-long-%d" % viewport.x)
	app.queue_free()
	await process_frame
	print("CAMPAIGN HUD: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
