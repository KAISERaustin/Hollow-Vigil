extends SceneTree

const UI = preload("res://scripts/ui/shared/interface.gd")
var failures: Array[String] = []
var checks := 0

# Real cloud UI with an offline fixture: button tests must never upload a save.
const Service = preload("res://scripts/cloud/cloud_service.gd")
class CloudFixture extends Service:
	var sync_count := 0
	func configured() -> bool: return true
	func signed_in() -> bool: return true
	func linked() -> bool: return true
	func sync_now() -> void: sync_count += 1
	func start_backup() -> void: sync_count += 1
	func refresh_worlds() -> void: pass
	func sign_out() -> void: pass
	func restore_world(_id: String) -> void: pass

func _initialize() -> void:
	# Enable the engine's touchscreen scrolling path on desktop test hosts.
	Input.emulate_touch_from_mouse = true
	root.gui_embed_subwindows = true
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func settle() -> void:
	for i in range(6): await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func tap(position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.position = position
	press.index = 0
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await settle()

func swipe(position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.position = position
	press.index = 0
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	for i in range(8):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = position - Vector2(0, (i + 1) * 12)
		drag.relative = Vector2(0, -12)
		Input.parse_input_event(drag)
		await process_frame
	press.position = position - Vector2(0, 96)
	press.pressed = false
	Input.parse_input_event(press)
	await settle()

func run() -> void:
	RenderingServer.set_default_clear_color(UI.PANEL)
	var app := VigilApp.new()
	var service := CloudFixture.new()
	app.load_saved_progress = false
	app.game.save_path = "user://mobile-backup-fixture.save"
	app.cloud = service
	service.game = app.game
	service.player_id = "10000000-0000-4000-8000-000000000001"
	app.campaign_progress.path = "user://mobile-campaign-fixture.save"
	app.campaign_backup = preload("res://scripts/cloud/campaign_backup.gd").new()
	app.campaign_backup.cloud = service
	app.campaign_backup.progress = app.campaign_progress
	root.add_child(app.campaign_backup)
	root.add_child(service)
	for i in range(10):
		service.worlds.append({"world_id": str(i), "seed": 4200 + i, "updated_at": "2026-09-06T12:00:00Z"})
	var frame := MarginContainer.new()
	frame.theme = UI.theme()
	root.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: frame.add_theme_constant_override("margin_" + side, 20)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.keyboard_scroll(scroll, "Cloud saves")
	frame.add_child(scroll)
	var panel := preload("res://scripts/cloud/cloud_panel.gd").new()
	panel.app = app
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		panel.rebuild()
		scroll.scroll_vertical = 0
		await settle()
		var sync_row: Control
		for row in panel.get_children():
			if not row.has_meta("scroll_action_row"): continue
			var button: BaseButton = row.get_child(1)
			check(button.size.x >= 48 and button.size.y >= 48, "Action touch target too small")
			check(button.size.x <= row.size.x * 0.4, "Action leaves too little scrolling space")
			check(row.get_global_rect().end.x <= viewport.x, "Action row overflows viewport")
			if button.name == "UploadInfinite1": sync_row = row
		check(sync_row != null, "Sync row missing")
		if sync_row == null: continue
		scroll.ensure_control_visible(sync_row)
		await settle()
		var sync_button: Button = sync_row.get_child(1)
		var before: int = service.sync_count
		await tap(sync_row.get_child(0).get_global_rect().get_center())
		check(service.sync_count == before, "Tapping row text triggered sync")
		await swipe(sync_row.get_child(0).get_global_rect().get_center())
		check(scroll.scroll_vertical > 30, "Touch drag on row text did not scroll at " + str(viewport))
		check(service.sync_count == before, "Scrolling triggered sync")
		scroll.ensure_control_visible(sync_row)
		await settle()
		await tap(sync_button.get_global_rect().get_center())
		check(service.sync_count == before + 1, "Trailing Sync button did not activate exactly once")
		service.busy = true
		panel.rebuild()
		await settle()
		for row in panel.get_children():
			if row.has_meta("scroll_action_row"):
				check(row.get_child(1).disabled, "Busy action is still enabled")
		service.busy = false
		panel.rebuild()
		await settle()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/mobile-cloud-rows-%d.png" % viewport.x)
	frame.queue_free()
	service.queue_free()
	app.campaign_backup.queue_free()
	app.free()
	await settle()
	await check_number_rows()
	await check_menu_pages()
	for failure in failures: push_error(failure)
	print("MOBILE_SCROLL: %d checks, %d failures; touch scrolling, safe actions and numeric controls; full-screen menus at 3 upright portrait sizes" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func check_menu_pages() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://menu-scroll-placeholder.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_save_slots()
	var menu: Control = app.slot_menu
	menu.slots.base_path = "user://menu-scroll-empty-" + str(Time.get_ticks_usec())
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		menu.show_main_menu()
		await settle()
		check(menu.welcome_paper.get_global_rect().is_equal_approx(app.get_global_rect()), "Main parchment does not fill " + str(viewport))
		if viewport.y < 500:
			await swipe(menu.scroll.get_global_rect().get_center())
			check(menu.scroll.scroll_vertical > 30, "Short main menu does not scroll")
			check(menu.find_child("OpenInfinite", true, false) != null, "Main menu swipe activated an option")
		menu.show_slots()
		await settle()
		check(menu.welcome_paper.visible, "Saved games lost the full-screen paper")
		var first: Button = menu.find_child("NewGameSlot1", true, false)
		menu.scroll.ensure_control_visible(first)
		await settle()
		var before: int = menu.scroll.scroll_vertical
		var remaining: float = menu.scroll.get_v_scroll_bar().max_value - menu.scroll.get_v_scroll_bar().page - before
		await swipe(first.get_global_rect().get_center())
		if remaining > 30:
			check(menu.scroll.scroll_vertical > before + 30, "Saved game button blocks swipe at " + str(viewport))
		check(menu.find_child("NewGameSlot1", true, false) == first, "Saved game swipe activated New game")
		menu.scroll.ensure_control_visible(menu.content.get_child(-1))
		await settle()
		check(menu.scroll.get_global_rect().grow(1).encloses(menu.content.get_child(-1).get_global_rect()), "Last saved-games action unreachable")
		menu.show_creation(0)
		menu.new_game.mode = "creative"
		menu.show_review()
		await settle()
		var create := menu.find_child("StartGame", true, false)
		await settle()
		check(menu.get_global_rect().grow(1).encloses(create.get_global_rect()), "Fixed Start game action unreachable at " + str(viewport))
		app.show_campaign()
		var campaign: Control = app.campaign
		campaign.set_process(false)
		campaign.show_map()
		await settle()
		check(campaign.find_child("FullscreenParchment", true, false).get_global_rect().is_equal_approx(app.get_global_rect()), "Campaign parchment does not fill screen")
		await swipe(campaign.page_scroll.get_global_rect().get_center())
		check(campaign.page_scroll.scroll_vertical > 30, "Campaign map blocks swipe at " + str(viewport))
		check(campaign.page == "map", "Map swipe activated a level")
		campaign.page_scroll.ensure_control_visible(campaign.find_child("CampaignBackups", true, false))
		await settle()
		check(campaign.page_scroll.get_global_rect().grow(1).encloses(campaign.find_child("CampaignBackups", true, false).get_global_rect()), "Campaign bottom action unreachable")
		campaign.show_briefing(0)
		await settle()
		if viewport.y < 500:
			await swipe(campaign.page_scroll.get_global_rect().get_center())
			check(campaign.page_scroll.scroll_vertical > 30, "Short briefing blocks swipe over preview")
		var begin := campaign.find_child("BeginCampaignMission", true, false)
		campaign.page_scroll.ensure_control_visible(begin)
		await settle()
		check(campaign.page_scroll.get_global_rect().grow(1).encloses(begin.get_global_rect()), "Begin mission unreachable at " + str(viewport))
		campaign.close()
		await settle()
	app.queue_free()
	await settle()

func check_number_rows() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://mobile-number-rows.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		for screen in ["sound", "developer"]:
			if screen == "sound": app.panels.show_sound_settings()
			else:
				app.panels.show_developer_controls()
				app.panels.find_child("EnemiesCategory", true, false).pressed.emit()
			await settle()
			check(app.panels.find_children("*", "Slider", true, false).is_empty(), screen + " still contains a slider")
			var number: SpinBox = app.panels.find_child("Audio_master" if screen == "sound" else "hpValue", true, false)
			check(number != null, screen + " numeric control is missing")
			if number == null: continue
			var row := number.get_parent().get_parent()
			app.panels.content_scroll.ensure_control_visible(row)
			await settle()
			var before := number.value
			var scroll_before := app.panels.content_scroll.scroll_vertical
			await swipe(row.get_child(0).get_child(0).get_global_rect().get_center())
			check(app.panels.content_scroll.scroll_vertical > scroll_before + 30, screen + " label drag did not scroll at " + str(viewport))
			check(number.value == before, screen + " scroll changed a value")
			app.panels.content_scroll.ensure_control_visible(row)
			await settle()
			var buttons := number.get_parent().get_child(1)
			number.value = 37
			await tap(buttons.get_child(1).get_global_rect().get_center())
			check(number.value == 37 + number.step, screen + " plus button did not apply one step")
			await tap(buttons.get_child(0).get_global_rect().get_center())
			check(number.value == 37, screen + " minus button did not apply one step")
			var entry := number.get_line_edit()
			entry.grab_focus()
			entry.text = "42"
			entry.text_submitted.emit(entry.text)
			await settle()
			check(number.value == 42, screen + " typed value was not applied")
			check(is_equal_approx(app.audio.volume("master"), .42) if screen == "sound" else app.game.tuning.enemies.basic.hp == 42, screen + " exact input did not update the model")
			number.value = number.min_value
			check(buttons.get_child(0).disabled, screen + " minus was enabled at minimum")
			number.value = number.max_value
			check(buttons.get_child(1).disabled, screen + " plus was enabled at maximum")
			number.value = 42
			entry.release_focus()
			if screen == "developer": app.panels.content_scroll.ensure_control_visible(row)
			else: app.panels.content_scroll.scroll_vertical = 0
			await settle()
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/mobile-%s-numbers-%d.png" % [screen, viewport.x])
	app.queue_free()
	await settle()
