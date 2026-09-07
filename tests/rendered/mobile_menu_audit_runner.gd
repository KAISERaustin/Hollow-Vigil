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
	await frames()
	var target := button(key)
	check(target != null, "Reachable touch action: " + key)
	if target == null: return
	touch_actions += 1
	await tap_control(target, key)
	for frame in 120:
		if not app.private_backups.busy and not app.public_builds.busy: break
		await process_frame
	await frames()
	await audit_page_once()

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
	# Portrait workflows above cover creation, replacement, share/retry, pagination,
	# restoration, rules, and live sessions. Repeat every page layout in landscape.
	var portrait := root.size
	root.size = Vector2i(844, 390)
	root.content_scale_size = root.size
	await frames()
	await landscape_pages()
	root.size = portrait
	root.content_scale_size = portrait
	await frames()
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
	await press("AccountDone")
	menu.show_main_menu()

func landscape_pages() -> void:
	for type in ["campaign", "infinite"]:
		menu.show_main_menu()
		await audit_controls(menu, "landscape main")
		await press("OpenCampaign" if type == "campaign" else "OpenInfinite")
		await audit_controls(menu, type + " landscape slots")
		await press("BackButton")
		menu.show_home(type)
		await audit_controls(menu, type + " landscape home")
		await press("NewGame")
		await press("ChooseCreative")
		await press("NextPlayStyle")
		await press("ReviewNewGame")
		await choose("SaveSlotChoice", 1)
		menu.show_home(type)
		await press("MyBuilds")
		await press("BuildDetails")
		await press("SharePrivateBuild")
		await audit_controls(menu, type + " landscape save form")
		if type == "campaign":
			await choose("BuildScope", 1)
			await choose("BuildLevel", 19)
		menu.show_backups(menu.show_home)
		await audit_controls(menu, type + " landscape backups")
		await press("RestoreBackup")
		await press("RestoreIntoSlot1")
		await audit_controls(menu, type + " landscape restore comparison")
		menu.show_settings(menu.show_home)
		await press("SettingsSound")
		await audit_controls(menu, type + " landscape sound")
		await press("BackButton")
		await press("SettingsAccount")
		await audit_controls(menu, type + " landscape account")
		await press("AccountDone")
	menu.show_main_menu()
