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
	Input.parse_input_event(event)
	await process_frame

func swipe_control(scroll: ScrollContainer, upward: bool = true) -> void:
	var area := scroll.get_global_rect()
	var distance := minf(180, area.size.y * 0.55)
	var start := area.get_center() + Vector2(0, distance * (0.5 if upward else -0.5))
	if scroll.get_window() != root: start += Vector2(scroll.get_window().position)
	var movement := Vector2(0, -distance if upward else distance)
	await input_touch(start, true)
	for step in 8:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = start + movement * float(step + 1) / 8.0
		event.relative = movement / 8.0
		Input.parse_input_event(event)
		await process_frame
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
				await swipe_control(ancestor, target.get_global_rect().get_center().y > visible_area.get_center().y)
				if not is_instance_valid(target): return
				if ancestor.scroll_vertical == before: break
		ancestor = ancestor.get_parent()
	await frames()

func tap_control(target: Control, context: String) -> void:
	await reveal(target)
	check(is_instance_valid(target), "Touch target survives scroll: " + context)
	if not is_instance_valid(target): return
	var area := target.get_global_rect()
	var viewport_area := Rect2(Vector2.ZERO, Vector2(target.get_viewport().size))
	check(viewport_area.grow(1).encloses(area), "Touch target is on screen: " + context)
	var ancestor := target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			check(ancestor.get_global_rect().grow(1).encloses(area), "Touch target is reachable by finger: " + context)
		ancestor = ancestor.get_parent()
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

func compare_toolbar() -> void:
	for key in toolbar_rects:
		var control := button(key)
		if control != null and not control.get_global_rect().is_equal_approx(toolbar_rects[key]):
			print("MOBILE_TOOLBAR_GEOMETRY: %s Campaign=%s Infinite=%s" % [key, toolbar_rects[key], control.get_global_rect()])
	super.compare_toolbar()

func audit_page_once() -> void:
	if not menu.visible: return
	var id := "%s/%s/%s" % [menu.screen, menu.game_type, root.size]
	if audited_pages.has(id): return
	# Keep the open modal's input ownership undisturbed.
	if not root.get_embedded_subwindows().filter(func(window): return window.visible).is_empty(): return
	audited_pages[id] = true
	await audit_controls(menu, id)

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
	for type in ["campaign", "infinite"]:
		menu.show_main_menu()
		await audit_controls(menu, "portrait main")
		await press("OpenCampaign" if type == "campaign" else "OpenInfinite")
		await audit_controls(menu, type + " portrait slots")
		await press("BackButton")
		menu.show_home(type)
		await audit_controls(menu, type + " portrait home")
		await press("NewGame")
		await press("ChooseCreative")
		await press("NextPlayStyle")
		await press("ReviewNewGame")
		await choose("SaveSlotChoice", 1)
		menu.show_home(type)
		await press("MyBuilds")
		await press("BuildDetails")
		await press("SharePrivateBuild")
		await audit_controls(menu, type + " portrait save form")
		if type == "campaign":
			await choose("BuildScope", 1)
			await choose("BuildLevel", 20)
		menu.show_backups(menu.show_home)
		await audit_controls(menu, type + " portrait backups")
		await press("RestoreBackup")
		await press("RestoreIntoSlot1")
		await audit_controls(menu, type + " portrait restore comparison")
		menu.show_settings(menu.show_home)
		await press("SettingsSound")
		await audit_controls(menu, type + " portrait sound")
		await press("BackButton")
		await press("SettingsAccount")
		await audit_controls(menu, type + " portrait account")
		await press("AccountDone")
	menu.show_main_menu()
