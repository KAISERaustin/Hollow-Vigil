extends SceneTree
## Physical touch events through the viewport; all saves use an isolated fixture.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Harness = preload("res://tests/rendered/visual_smoke.gd")
var app: VigilApp
var menu: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	Input.emulate_touch_from_mouse = true
	root.gui_embed_subwindows = true
	preload("res://tests/support/timeout.gd").arm(self, 240)
	call_deferred("run")

func settle() -> void:
	for frame in 8: await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func touch(at: Vector2, down: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = down
	event.index = index
	Input.parse_input_event(event)
	await process_frame

func swipe(at: Vector2, amount: Vector2 = Vector2(0, -120)) -> void:
	await touch(at, true)
	for step in 8:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = at + amount * float(step + 1) / 8.0
		event.relative = amount / 8.0
		Input.parse_input_event(event)
		await process_frame
	await touch(at + amount, false)
	await settle()

func audit_controls(owner: Control, context: String) -> void:
	await settle()
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	for node in owner.find_children("*", "BaseButton", true, false):
		if not node.is_visible_in_tree(): continue
		# Embedded windows are audited separately in their own coordinates.
		if node.get_viewport() != root: continue
		var scrollers: Array[ScrollContainer] = []
		var parent: Node = node.get_parent()
		while parent != null:
			if parent is ScrollContainer: scrollers.append(parent)
			parent = parent.get_parent()
		for scroll in scrollers: scroll.ensure_control_visible(node)
		for frame in 3: await process_frame
		var rect: Rect2 = node.get_global_rect()
		check(viewport.grow(1).encloses(rect), "%s: %s outside viewport %s" % [context, node.name, root.size])
		check(rect.size.x >= 44 and rect.size.y >= 44, "%s: %s touch target below 44 pixels" % [context, node.name])
		for scroll in scrollers:
			check(scroll.get_global_rect().grow(1).encloses(rect), "%s: %s clipped by scroll area %s" % [context, node.name, root.size])

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://mobile-navigation-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	app.show_save_slots()
	menu = app.slot_menu
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960), Vector2i(844, 390)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		for type in ["campaign", "infinite"]:
			menu.show_main_menu()
			await audit_controls(menu, "main")
			await Harness.tap(app, menu.find_child("OpenCampaign" if type == "campaign" else "OpenInfinite", true, false).get_global_rect().get_center(), true)
			check(menu.screen == "home" and menu.game_type == type, "Touch opens " + type)
			menu.show_home(type)
			await audit_controls(menu, type + " home")
			menu.show_slots()
			await audit_controls(menu, type + " slots")
			menu.begin_new()
			await audit_controls(menu, type + " play style")
			menu.show_starting_build()
			await audit_controls(menu, type + " starting build")
			menu.show_review()
			await audit_controls(menu, type + " review")
			menu.show_settings(menu.show_home)
			await audit_controls(menu, "settings")
			menu.show_sound()
			await audit_controls(menu, "sound")
			await check_sound_input()
			menu.show_account(menu.show_settings)
			await audit_controls(menu, "account")
			await check_account_keyboard()
			menu.show_backups(menu.show_home)
			await audit_controls(menu, "backups")
			menu.open_build_form()
			await audit_controls(menu, "build contents and sharing")
		menu.show_infinite_rules()
		await audit_controls(menu, "rule categories")
		for category in Balance.TUNING_FIELDS:
			menu.rules_editor.show_category(category)
			await audit_controls(menu, "rules " + category)
		menu.show_home("infinite")
		app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		check(menu.screen == "main", "Android Back returns from game home")
		await check_confirmation()
		await check_dropdown()
	menu.hide()
	app.game.suspended = false
	app.game.data.balance = 1000000
	app.game.expand("-1,0")
	app.game.economy.build("rapid", "0,0", 0)
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960), Vector2i(844, 390)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		for mode in ["settings", "sound_settings", "developer_controls", "core", "reset_confirmation"]:
			if app.panels.has_method("show_" + mode):
				app.panels.call("show_" + mode)
				await audit_controls(app.panels, mode)
		app.panels.select_pad("0,0", 1)
		await audit_controls(app.panels, "tower construction")
		app.panels.show_expansion("0,1")
		await audit_controls(app.panels, "territory claim")
		app.panels.show_entrance("-1,0")
		await audit_controls(app.panels, "portal upgrades")
		app.panels.close_sheet()
		app.field.selected_tower = "1"
		for action in ["info", "sell", "move", "target", "equipment"]:
			app.tower_dialog.open_action(action)
			await audit_controls(app.tower_dialog, "tower " + action)
			app.tower_dialog.dismiss()
	await check_map_gestures()
	await check_campaign()
	check(UI.usable_viewport(Vector2(390, 844), Vector2(1170, 2532), Rect2(0, 141, 1170, 2289), 900).is_equal_approx(Rect2(0, 47, 390, 497)), "Keyboard and safe area convert physical pixels to UI coordinates")
	check(UI.usable_viewport(Vector2(360, 640), Vector2(1080, 1920), Rect2(), 0) == Rect2(0, 0, 360, 640), "Missing safe area leaves full viewport usable")
	print("MOBILE_NAVIGATION: %d checks, %d failures; touch routes and reachable controls at four sizes" % [checks, failures.size()])
	app.game.suspended = true
	app.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)

func check_confirmation() -> void:
	var popup := preload("res://scripts/ui/shared/confirmation_popup.gd").new()
	menu.add_child(popup)
	popup.configure("Replace saved game?", "A long saved game name ".repeat(20), "Replace and start", func(): check(false, "Scrolling activated destructive confirmation"))
	await settle()
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(Rect2(popup.position, popup.size)), "Confirmation fits " + str(root.size))
	popup.show_error("A recoverable error with details. ".repeat(20))
	await settle()
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(Rect2(popup.position, popup.size)), "Confirmation error fits " + str(root.size))
	await swipe(Vector2(popup.position) + popup.scroll.get_global_rect().get_center(), Vector2(0, -48))
	if popup.scroll.get_v_scroll_bar().max_value > popup.scroll.size.y + 20:
		check(popup.scroll.scroll_vertical > 0, "Overflowing confirmation details scroll at " + str(root.size))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/mobile-confirmation-%d.png" % root.size.x)
	var cancel: Button = popup.find_child("CancelConfirmation", true, false)
	check(Rect2(Vector2.ZERO, Vector2(popup.size)).encloses(cancel.get_global_rect()), "Cancel remains reachable with long error")
	await Harness.tap(app, Vector2(popup.position) + cancel.get_global_rect().get_center(), true)
	await settle()
	check(not is_instance_valid(popup), "Touch cancels confirmation")
	menu.confirm("Back test", "Back should only dismiss this dialog.", "Confirm", func(): check(false, "Back confirmed an action"))
	await settle()
	var screen: String = menu.screen
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()
	check(menu.screen == screen and root.get_embedded_subwindows().filter(func(window): return window.visible).is_empty(), "Android Back dismisses only the top popup")
	await settle()

func check_dropdown() -> void:
	menu.begin_new()
	menu.show_review()
	await settle()
	var picker: OptionButton = menu.find_child("SaveSlotChoice", true, false)
	menu.scroll.ensure_control_visible(picker)
	await settle()
	await swipe(picker.get_global_rect().get_center(), Vector2(0, -48))
	check(not picker.get_popup().visible, "Swiping dropdown must not open it at " + str(root.size))
	picker.get_popup().hide()
	await settle()

func check_map_gestures() -> void:
	menu.hide()
	app.panels.close_sheet()
	app.field.set_unrestricted_camera(true)
	app.field.camera = Vector2.ZERO
	app.field.zoom = 1.0
	await settle()
	var at := app.field.get_global_rect().get_center()
	var before := app.field.camera
	await swipe(at, Vector2(60, 0))
	check(app.field.camera != before, "Physical touch pans battlefield")
	check(app.field.touches.is_empty(), "Pan releases every touch")
	var zoom_before := app.field.zoom
	await touch(at - Vector2(30, 0), true, 0)
	await touch(at + Vector2(30, 0), true, 1)
	var pinch := InputEventScreenDrag.new()
	pinch.index = 1
	pinch.position = at + Vector2(60, 0)
	pinch.relative = Vector2(30, 0)
	Input.parse_input_event(pinch)
	await process_frame
	await touch(at - Vector2(30, 0), false, 0)
	await touch(at + Vector2(60, 0), false, 1)
	await settle()
	check(app.field.zoom > zoom_before and app.field.touches.is_empty(), "Physical two-finger pinch zooms and releases")
	# A GUI overlay inside the map can consume the release before gui_input.
	var blocker := ColorRect.new()
	blocker.position = at - Vector2(25, 25)
	blocker.size = Vector2(50, 50)
	app.add_child(blocker)
	blocker.hide()
	await touch(at, true)
	blocker.show()
	await touch(at, false)
	await settle()
	check(app.field.touches.is_empty(), "Release intercepted by overlay must clear map touch")
	blocker.queue_free()
	await settle()

func check_campaign() -> void:
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.mode = "creative"
	campaign.progress.allow_all = true
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960), Vector2i(844, 390)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		campaign.show_setup()
		await audit_controls(campaign, "campaign setup")
		campaign.show_map()
		await audit_controls(campaign, "campaign world map")
		campaign.page_scroll.scroll_vertical = 0
		await settle()
		await swipe(campaign.page_scroll.get_global_rect().get_center())
		check(campaign.page_scroll.scroll_vertical > 30 and campaign.page == "map", "Campaign map swipe scrolls without selecting a level")
		campaign.show_briefing(0)
		await audit_controls(campaign, "mission briefing")
		campaign.start_mission(0)
		await audit_controls(campaign, "battle controls")
		campaign.show_socket(0)
		await audit_controls(campaign.dialog, "campaign construction")
		campaign.close_dialog()
		campaign.show_waves()
		await audit_controls(campaign.dialog, "wave list")
		campaign.show_wave_balance(0)
		await audit_controls(campaign.dialog, "wave report")
		campaign.show_level_balance(0, 0)
		await audit_controls(campaign.dialog, "wave editor")
		campaign.close_dialog()
		await settle()
		var point: Vector2 = campaign.board.get_global_rect().get_center()
		campaign.board.set_unrestricted_camera(true)
		var before: Vector2 = campaign.board.camera
		await swipe(point, Vector2(50, 0))
		check(campaign.board.camera != before and campaign.board.touches.is_empty(), "Campaign battlefield touch pans and releases")
		campaign.run.phase = "defeat"
		campaign.show_result()
		await audit_controls(campaign.dialog, "defeat actions")
		campaign.run.phase = "victory"
		campaign.show_result()
		await audit_controls(campaign.dialog, "victory actions")
	campaign.close()
	await settle()

func check_account_keyboard() -> void:
	var entry: LineEdit = menu.find_child("AccountCode", true, false)
	if entry == null: return
	var saved_clipboard := DisplayServer.clipboard_get()
	entry.text = "old code"
	DisplayServer.clipboard_set("123456")
	menu.find_child("PasteSignInCode", true, false).pressed.emit()
	await settle()
	check(entry.text == "123456", "Paste replaces the previous sign-in code")
	DisplayServer.clipboard_set(saved_clipboard)
	var original_size: Vector2 = menu.card.size
	entry.grab_focus()
	for height in [350, 300, 350]:
		menu.card.size.y = height
		var observer := menu.get_node("MobileLayout")
		observer.layout_revision += 1
		observer.reveal_after_layout(observer.layout_revision)
		await settle()
		check(menu.scroll.get_global_rect().grow(1).encloses(entry.get_global_rect()), "Code stays visible after keyboard layout settles")
		check(menu.find_children("SignIn", "Button", true, false).size() == 1, "Keyboard layout retains one sign-in action")
		check(entry.text == "123456", "Keyboard layout preserves the code draft")
	entry.release_focus()
	menu.card.size = original_size
	await settle()

func check_sound_input() -> void:
	var number: SpinBox = menu.find_child("Audio_master", true, false)
	check(number != null, "Master volume control exists")
	if number == null: return
	menu.scroll.scroll_vertical = 0
	await settle()
	var before := number.value
	var row: Control = number.get_parent().get_parent()
	menu.scroll.ensure_control_visible(row)
	await settle()
	await swipe(row.get_child(0).get_global_rect().get_center(), Vector2(0, -60))
	check(number.value == before, "Scrolling a number row does not change its value")
	menu.scroll.ensure_control_visible(number)
	await settle()
	number.value = 37
	var buttons := number.get_parent().get_child(1)
	await Harness.tap(app, buttons.get_child(1).get_global_rect().get_center(), true)
	check(number.value == 37 + number.step, "Touch increments volume exactly once")
	await Harness.tap(app, buttons.get_child(0).get_global_rect().get_center(), true)
	check(number.value == 37, "Touch decrements volume exactly once")
	var entry := number.get_line_edit()
	await Harness.tap(app, entry.get_global_rect().get_center(), true)
	check(entry.has_focus(), "Touch focuses numeric entry for mobile keyboard")
	entry.text = "42"
	entry.text_submitted.emit(entry.text)
	await settle()
	check(number.value == 42 and is_equal_approx(app.audio.volume("master"), .42), "Submitted numeric entry updates sound settings")
	entry.release_focus()
