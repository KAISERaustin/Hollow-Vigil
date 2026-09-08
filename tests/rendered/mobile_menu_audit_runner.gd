extends "res://tests/rendered/unified_menu_runner.gd"
## Reuse complete session/build/backup assertions with real touch navigation.
## Fixtures stay in unique save paths and the in-memory cloud implementation.
const UI = preload("res://scripts/ui/shared/interface.gd")
var audited_pages := {}
var touch_actions := 0
var touch_choices := 0

func _initialize() -> void:
	Input.emulate_touch_from_mouse = true
	root.gui_embed_subwindows = true
	preload("res://tests/support/timeout.gd").arm(self, 1200)
	call_deferred("run")

func input_touch(at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = down
	var started := Time.get_ticks_msec()
	Input.parse_input_event(event)
	if Time.get_ticks_msec() - started >= 100:
		print("MOBILE_INPUT_STALL: %d ms while dispatching touch %s on %s" % [Time.get_ticks_msec() - started, "down" if down else "up", menu.screen])
	await process_frame

func swipe_control(scroll: ScrollContainer, upward: bool = true, travel: float = 120, page_gutter: bool = false) -> void:
	var area := scroll.get_global_rect()
	var distance := minf(travel, area.size.y * 0.55)
	var start := area.get_center() + Vector2(0, distance * (0.5 if upward else -0.5))
	# Text fields own gestures for editing; page scrolling uses the body gutter.
	if page_gutter: start.x = area.position.x + 4
	if scroll.get_window() != root: start += Vector2(scroll.get_window().position)
	var movement := Vector2(0, -distance if upward else distance)
	await input_touch(start, true)
	for step in 8:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = start + movement * float(step + 1) / 8.0
		event.relative = movement / 8.0
		Input.parse_input_event(event)
		# A human-paced gesture avoids the artificial momentum of a 240-FPS flick.
		await create_timer(0.035).timeout
	# Pause the finger before lifting for precise movement through long cards.
	var stopped := InputEventScreenDrag.new()
	stopped.index = 0
	stopped.position = start + movement
	stopped.relative = Vector2.ZERO
	Input.parse_input_event(stopped)
	await create_timer(0.2).timeout
	if "--trace-mobile-scroll" in OS.get_cmdline_user_args(): print("MOBILE_SCROLL_DRAG_END: %d" % scroll.scroll_vertical)
	await input_touch(start + movement, false)
	# Momentum continues after release; target coordinates are valid once it ends.
	var stable := 0
	var previous: int = scroll.scroll_vertical
	for frame in 120:
		await physics_frame
		if not is_instance_valid(scroll): return
		if scroll.scroll_vertical == previous: stable += 1
		else: stable = 0
		previous = scroll.scroll_vertical
		if stable >= 6: break
	await frames()

func reveal(target: Control) -> void:
	var ancestor := target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			# Walk to the actual target using swipes, as a finger must on a phone.
			for attempt in 120:
				var visible_area: Rect2 = ancestor.get_global_rect().grow(-1)
				if visible_area.encloses(target.get_global_rect().grow(-2)): break
				var before: int = ancestor.scroll_vertical
				var delta: float = target.get_global_rect().get_center().y - visible_area.get_center().y
				# Use a full finger sweep for distant rows, then shorten near the target.
				await swipe_control(ancestor, delta > 0, clampf(absf(delta) * 0.8, 32, 400))
				if not is_instance_valid(target): return
				if "--trace-mobile-scroll" in OS.get_cmdline_user_args(): print("MOBILE_SCROLL: %s step=%d before=%d after=%d target=%s viewport=%s" % [target.name, attempt, before, ancestor.scroll_vertical, target.get_global_rect(), ancestor.get_global_rect()])
				if ancestor.scroll_vertical == before: break
		ancestor = ancestor.get_parent()
	await frames()

func run() -> void:
	if "--build-cost-only" in OS.get_cmdline_user_args():
		build_cost_probe()
		return
	if "--save-touch-cost-only" in OS.get_cmdline_user_args():
		await save_touch_cost_probe()
		return
	if "--library-touch-only" in OS.get_cmdline_user_args() or "--level-picker-only" in OS.get_cmdline_user_args():
		await library_touch_probe()
		return
	await super.run()
	print("MOBILE_MENU_AUDIT_FINAL: %d checks, %d failures; %d touch actions and %d touch picker choices across three portrait sizes" % [checks, failures.size(), touch_actions, touch_choices])

func build_cost_probe() -> void:
	var source := VigilState.new()
	var started := Time.get_ticks_msec()
	var build := Build.capture("campaign", source, {}, "all", -1, Build.all_contents("campaign"), "Mobile save timing", "")
	print("BUILD_COST: capture all Campaign rules %d ms" % [Time.get_ticks_msec() - started])
	started = Time.get_ticks_msec()
	var composed := Build.compose_campaign(build, {})
	print("BUILD_COST: compose Campaign %d ms" % [Time.get_ticks_msec() - started])
	started = Time.get_ticks_msec()
	var encoded := Build.encode(build)
	print("BUILD_COST: encode Campaign %d ms; %d bytes" % [Time.get_ticks_msec() - started, encoded.length()])
	started = Time.get_ticks_msec()
	var decoded := Build.decode(encoded)
	print("BUILD_COST: decode Campaign %d ms" % [Time.get_ticks_msec() - started])
	check(composed.get("ok", false) and not decoded.is_empty(), "Timed Campaign build round trip remains valid")
	quit(0 if failures.is_empty() else 1)

func save_touch_cost_probe() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://mobile-save-cost-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	root.size = Vector2i(360, 640) if "--compact-save" in OS.get_cmdline_user_args() else Vector2i(390, 844)
	root.content_scale_size = root.size
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	app.show_save_slots()
	menu = app.slot_menu
	menu.show_export(app.game, {"levels": {}, "index": -1}, menu.show_main_menu)
	fill("BuildName", "Timed full Campaign save")
	await frames()
	var started := Time.get_ticks_msec()
	await check_save_pending()
	print("MOBILE_SAVE_COST: full Campaign Save privately touch and feedback %d ms" % [Time.get_ticks_msec() - started])
	check(not menu.form_saved_code.is_empty() and menu.message.visible, "Timed Save touch creates a private copy with visible feedback")
	await check_save_back_cancellation()
	print("MOBILE_SAVE_PENDING: %d checks, %d failures" % [checks, failures.size()])
	app.game.suspended = true
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)

func queue_tap(at: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = down
		Input.parse_input_event(event)

func check_save_pending() -> void:
	var action := button("SavePrivately")
	var presses := [0]
	var observed := [false]
	var painted := [false]
	menu.scroll.scroll_vertical = int(menu.scroll.get_v_scroll_bar().max_value)
	await frames()
	action.pressed.connect(func():
		presses[0] += 1
		observed[0] = menu.submitting_build and action.disabled and button("ShareToCommunity").disabled and menu.message.visible and menu.message.text == "Saving build…"
		observe_pending_frame(painted)
	)
	var center := action.get_global_rect().get_center()
	await input_touch(center, true)
	await input_touch(center, false)
	# A fast second finger tap must not start the same operation again.
	queue_tap(center)
	for frame in 20: await process_frame
	check(observed[0], "Save touch shows pending feedback and disables Save and Share before serialization")
	check(painted[0], "Saving feedback is painted and revealed from the form bottom before serialization finishes")
	check(presses[0] == 1, "A rapid second Save tap is ignored while pending")
	check(not menu.submitting_build and not action.disabled and not button("ShareToCommunity").disabled, "Save completion restores both touch actions")
	check(not menu.form_saved_code.is_empty(), "The initial Save touch completes its private copy")

func observe_pending_frame(painted: Array) -> void:
	for draw in 3:
		await RenderingServer.frame_post_draw
		if menu.submitting_build and menu.message.visible and menu.message.text == "Saving build…" and menu.scroll.get_global_rect().grow(1).encloses(menu.message.get_global_rect()):
			painted[0] = true
			root.get_texture().get_image().save_png("res://artifacts/mobile-saving-%d.png" % root.size.x)
			return

func check_save_back_cancellation() -> void:
	var saved_before: int = menu.slots.shared_configurations("all").size()
	menu.show_export(app.game, {"levels": {}, "index": -1}, menu.show_main_menu)
	fill("BuildName", "Cancelled pending Campaign save")
	await frames()
	var back_center := button("BackButton").get_global_rect().get_center()
	button("SavePrivately").pressed.connect(func(): queue_tap.call_deferred(back_center))
	var center := button("SavePrivately").get_global_rect().get_center()
	await input_touch(center, true)
	await input_touch(center, false)
	for frame in 20: await process_frame
	check(menu.screen == "main" and not menu.submitting_build, "Back touch during save preparation closes the form and releases pending state")
	check(menu.slots.shared_configurations("all").size() == saved_before, "Back touch before preparation finishes creates no private save")

func library_touch_probe() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://mobile-library-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	app.show_save_slots()
	menu = app.slot_menu
	for index in 2:
		var build := Build.capture("infinite", VigilState.new(), {}, "all", -1, {"enemies": ["basic"]}, "Long library card " + str(index), "Long readable description. ".repeat(65))
		check(menu.slots.save_shared(Build.encode(build)), "Seed isolated long library card")
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		if "--level-picker-only" in OS.get_cmdline_user_args():
			await portrait_pages()
			continue
		menu.show_home("infinite")
		await press("MyBuilds")
		await press("BuildDetails")
		check(menu.screen == "detail", "Finger reaches Details in long library card at " + str(dimensions))
		await press("BackButton")
		await press("DeleteBuild")
		await press("CancelConfirmation")
		check(menu.screen == "library", "Finger cancels library deletion at " + str(dimensions))
	print("%s: %d checks, %d failures" % ["MOBILE_LEVEL_PICKER" if "--level-picker-only" in OS.get_cmdline_user_args() else "MOBILE_LIBRARY_TOUCH", checks, failures.size()])
	app.game.suspended = true
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)

func tap_control(target: Control, context: String) -> void:
	await reveal(target)
	check(is_instance_valid(target), "Touch target survives scroll: " + context)
	if not is_instance_valid(target): return
	var area := target.get_global_rect()
	var viewport_area := Rect2(Vector2.ZERO, Vector2(target.get_viewport().size))
	check(area.size.x >= UI.TARGET and area.size.y >= UI.TARGET, "Touch action is at least 48 units: " + context)
	check(viewport_area.grow(1).encloses(area), "Touch target is on screen: " + context)
	var reachable := viewport_area.grow(1).encloses(area)
	var ancestor := target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			check(ancestor.get_global_rect().grow(1).encloses(area), "Touch target is reachable by finger: " + context)
			reachable = reachable and ancestor.get_global_rect().grow(1).encloses(area)
		ancestor = ancestor.get_parent()
	if not reachable:
		quit(1)
		await process_frame
		return
	var center := area.get_center()
	if target.get_window() != root: center += Vector2(target.get_window().position)
	await input_touch(center, true)
	await input_touch(center, false)
	await frames()

func press(key: String) -> void:
	if "--trace-mobile" in OS.get_cmdline_user_args(): print("MOBILE_TOUCH: %s %s %s" % [root.size, menu.screen, key])
	await frames()
	var target := button(key)
	check(target != null, "Reachable touch action: " + key)
	if target == null:
		# A missing route invalidates the remaining workflow; avoid cascade noise.
		quit(1)
		await process_frame
		return
	touch_actions += 1
	await tap_control(target, key)
	for frame in 120:
		if not app.private_backups.busy and not app.public_builds.busy: break
		await process_frame
	await frames()
	await audit_page_once()
	if key == "CreativeTools" and menu.screen == "creative_tools":
		for toggle_name in ["UnrestrictedCamera", "ShowHealthNumbers"]:
			var toggle := button(toggle_name)
			var previous: bool = toggle.button_pressed
			await tap_control(toggle, toggle_name)
			check(toggle.button_pressed != previous, "Creative tool toggles exactly once by touch: " + toggle_name)
			await tap_control(toggle, toggle_name)
		var gold_before: float = app.game.data.balance
		await tap_control(button("AddMillionGold"), "AddMillionGold")
		check(app.game.data.balance == gold_before + 1000000, "Creative gold action executes once per touch")

func choose(key: String, index: int) -> void:
	await press(key)
	var picker: Button = menu.find_child(key, true, false)
	check(picker != null and picker.get_popup().visible, "Touch opens choice popup: " + key)
	if picker == null or not picker.get_popup().visible: return
	var option: Button = picker.rows.find_child("Choice_" + str(index), true, false)
	check(option != null and not option.disabled, "Requested choice is available: " + key)
	if option == null or option.disabled: return
	touch_choices += 1
	await tap_control(option, key + " option " + str(index))
	await frames()
	check(not is_instance_valid(picker) or not picker.get_popup().visible, "Touch selection closes choice popup: " + key)
	await audit_page_once()

func capture(key: String) -> void:
	await super.capture("touch-" + key)
	await audit_page_once()

func audit_page_once() -> void:
	if not menu.visible: return
	var id := "%s/%s/%s" % [menu.screen, menu.game_type, root.size]
	if audited_pages.has(id): return
	# Keep the open modal's input ownership undisturbed.
	if not root.get_embedded_subwindows().filter(func(window): return window.visible).is_empty(): return
	audited_pages[id] = true
	await audit_page_swipes(id)
	await audit_controls(menu, id)

func audit_page_swipes(context: String) -> void:
	# Bounds checks alone can pass when a child eats the finger gesture.
	# Exercise both ends of every overflowing page through actual touch input.
	var scroll: ScrollContainer = menu.scroll
	await frames()
	var bar := scroll.get_v_scroll_bar()
	var limit := int(bar.max_value - bar.page)
	if limit <= 2: return # A page that fits needs no scrolling.
	var screen_before: String = menu.screen
	scroll.scroll_vertical = 0
	await frames()
	await swipe_control(scroll, true, minf(80, limit), true)
	check(scroll.scroll_vertical > 0, context + ": finger swipe moves down page")
	check(menu.screen == screen_before, context + ": scrolling does not activate a menu action")
	scroll.scroll_vertical = limit
	await frames()
	await swipe_control(scroll, false, minf(80, limit), true)
	check(scroll.scroll_vertical < limit, context + ": finger swipe moves back up from bottom (limit=%d, after=%d, current_limit=%d)" % [limit, scroll.scroll_vertical, int(bar.max_value - bar.page)])
	check(menu.screen == screen_before, context + ": reverse scrolling preserves the page")
	scroll.scroll_vertical = 0
	await frames()

func audit_controls(owner: Control, context: String) -> void:
	await frames()
	var targets := owner.find_children("*", "BaseButton", true, false)
	targets.append_array(owner.find_children("*", "LineEdit", true, false))
	targets.append_array(owner.find_children("*", "TextEdit", true, false))
	for target in targets:
		if not target.is_visible_in_tree() or target.get_viewport() != root: continue
		var scrollers: Array[ScrollContainer] = []
		var ancestor: Node = target.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer: scrollers.append(ancestor)
			ancestor = ancestor.get_parent()
		for scroll in scrollers: scroll.ensure_control_visible(target)
		await frames()
		var rect: Rect2 = target.get_global_rect()
		check(rect.size.x >= UI.TARGET and rect.size.y >= UI.TARGET, "%s: %s needs a 48-unit touch target (%s)" % [context, target.name, rect.size])
		check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1).encloses(rect), "%s: %s outside phone viewport" % [context, target.name])
		for scroll in scrollers:
			check(scroll.get_global_rect().grow(1).encloses(rect), "%s: %s remains clipped at scroll limit" % [context, target.name])
	menu.scroll.scroll_vertical = 0
	await frames()

func extended_workflows() -> void:
	await super.extended_workflows()
	await extra_routes()
	await portrait_pages()
	print("MOBILE_MENU_AUDIT: %d touch actions, %d touch choices, %d distinct phone page audits" % [touch_actions, touch_choices, audited_pages.size()])

func extra_routes() -> void:
	menu.open_build_form()
	fill("BuildName", "")
	menu.scroll.scroll_vertical = int(menu.scroll.get_v_scroll_bar().max_value)
	await frames()
	await press("SavePrivately")
	check(menu.message.visible and menu.scroll.get_global_rect().grow(1).encloses(menu.message.get_global_rect()), "Touch Save at bottom reveals the missing-name error")
	fill("BuildName", "Pending touch regression " + str(root.size.x))
	await check_save_pending()
	await check_save_back_cancellation()
	menu.show_home("infinite")
	await press("Continue")
	await press("DeleteGameSlot1")
	await press("CancelConfirmation")
	check(menu.slots.occupied(0), "Touch cancel preserves saved game")
	menu.show_home("infinite")
	await press("MyBuilds")
	await press("DeleteBuild")
	await press("CancelConfirmation")
	check(not menu.library_entries.is_empty(), "Touch cancel preserves private build")
	menu.show_backups(menu.show_home)
	await press("DeleteCloudBackup")
	await press("CancelConfirmation")
	await press("RestoreRecoveryCopy")
	await press("RestoreIntoSlot3")
	await press("ConfirmRestoreBackup")
	await press("CancelConfirmation")
	await press("CancelRestore")
	await press("DeleteRecoveryCopy")
	await press("CancelConfirmation")
	await press("RecoverMyBuilds")
	await press("BackupAccount")
	await audit_controls(menu, "signed in account")
	fill("PlayerName", "")
	await press("SavePlayerName")
	check(menu.message.visible, "Touch Save name reports validation feedback")
	var prior_account: String = network.player_id
	var prior_name: String = network.display_name
	network.session_store.path = app.game.save_path + ".mobile-account"
	await press("SignOut")
	check(not network.signed_in() and menu.find_child("AccountEmail", true, false) != null, "Touch signs out and opens sign-in form")
	await audit_controls(menu, "signed out account")
	await tap_control(menu.find_child("AccountEmail", true, false), "AccountEmail")
	check(menu.find_child("AccountEmail", true, false).has_focus(), "Touch focuses email field")
	await press("SendSignInCode")
	check(menu.message.visible, "Touch email-code action reports offline configuration")
	network.email = "fixture@example.invalid"
	fill("AccountCode", "invalid")
	await press("SignIn")
	check(menu.message.visible and not network.signed_in(), "Touch invalid sign-in shows recoverable feedback")
	network.player_id = prior_account
	network.display_name = prior_name
	network.refresh_token = "fixture"
	await press("AccountDone")
	menu.show_main_menu()

func portrait_pages() -> void:
	# All page routes run above at each supported portrait size. Exercise the
	# long explicit level picker without repeating an entire session workflow.
	menu.show_export(app.game, {"levels": {}, "index": -1}, menu.show_main_menu)
	await audit_controls(menu, "Campaign save scope")
	await choose("BuildScope", 1)
	await choose("BuildLevel", 20)
	check(menu.form.scope == "level" and menu.form.level == 19, "Finger reaches and selects the final Campaign level")
	menu.show_main_menu()
