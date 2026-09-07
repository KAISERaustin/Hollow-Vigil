extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	Input.emulate_touch_from_mouse = true
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func settle() -> void:
	for frame in 10: await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func swipe(start: Vector2, distance: float) -> void:
	await touch(start, true)
	for step in range(1, 9):
		var event := InputEventScreenDrag.new()
		event.position = start + Vector2(distance * step / 8.0, 0)
		event.relative = Vector2(distance / 8.0, 0)
		Input.parse_input_event(event)
		await process_frame
	await touch(start + Vector2(distance, 0), false)
	await settle()

func exercise(host: Control, menu: Control, confirm: Button, label: String) -> void:
	var scroll := menu.find_child("TowerCards", true, false) as ScrollContainer
	var cards := scroll.get_node("Cards")
	var funds: float = host.game.data.balance
	var count: int = host.game.data.towers.size()
	check(cards.get_child_count() == Balance.TOWERS.size(), label + " includes the complete catalog")
	check(menu.size.y < 300, label + " fits a compact menu")
	check(not confirm.is_visible_in_tree(), label + " picker has no Build action before selection")
	check(scroll.get_global_rect().size.y >= 94 and scroll.scroll_vertical == 0, label + " fits compact icons without vertical scrolling")
	check(scroll.get_parent().get_parent().get_global_rect().grow(1).encloses(scroll.get_global_rect()), label + " parent viewport shows complete cards")
	var start := scroll.global_position + Vector2(scroll.size.x - 24, 45)
	var overflow := scroll.get_h_scroll_bar().max_value > scroll.get_h_scroll_bar().page
	await swipe(start, -180)
	check(scroll.scroll_horizontal > 0 if overflow else scroll.scroll_horizontal == 0, label + " swipes left when the catalog overflows")
	check(host.field.preview_kind.is_empty() and host.game.data.balance == funds, label + " swipe does not select or spend")
	var offset := scroll.scroll_horizontal
	await swipe(scroll.global_position + Vector2(24, 45), 180)
	check(scroll.scroll_horizontal < offset if overflow else scroll.scroll_horizontal == 0, label + " swipes right when the catalog overflows")
	var last := cards.get_child(-1) as Button
	last.grab_focus()
	await settle()
	check(scroll.get_global_rect().grow(1).encloses(last.get_global_rect()), label + " keyboard focus reveals last card")
	await touch(last.get_global_rect().get_center(), true)
	await touch(last.get_global_rect().get_center(), false)
	await settle()
	check(host.field.preview_kind == last.get_meta("tower_kind") and last.button_pressed, label + " tap selects last tower")
	check(host.game.data.balance == funds and host.game.data.towers.size() == count, label + " selection only previews")
	check(not scroll.visible and confirm.is_visible_in_tree(), label + " selection opens detail view with pinned Build")
	var details := menu.find_child("TowerDetails", true, false)
	var stats := Balance.stats(last.get_meta("tower_kind"), 1, host.game.tuning)
	check(details.find_child("TowerDescription", true, false).text == Balance.tower_description(stats), label + " description resolves current stats")
	for field in stats:
		if stats[field] is float or stats[field] is int:
			var value := details.find_child("Stat_" + field, true, false) as Label
			check(value != null and value.text.begins_with(VigilInterface.exact_money(stats[field])), label + " exposes resolved " + field)
	var back := menu.find_child("BackToTowers", true, false) as Button
	var vertical := scroll.get_parent().get_parent() as ScrollContainer
	if vertical == null:
		vertical = host.panels.content_scroll
	for number in details.find_children("Stat_*", "Label", true, false):
		vertical.ensure_control_visible(number)
		await settle()
		check(vertical.get_global_rect().grow(1).encloses(number.get_global_rect()), label + " detail stat is reachable: " + number.name)
	vertical.ensure_control_visible(details.get_child(-1))
	await settle()
	check(vertical.get_global_rect().grow(1).encloses(details.get_child(-1).get_global_rect()), label + " final detail is reachable")
	check(back.is_visible_in_tree() and menu.get_global_rect().encloses(back.get_global_rect()) and menu.get_global_rect().encloses(confirm.get_global_rect()), label + " navigation and Build stay pinned while scrolling")
	back.pressed.emit()
	await settle()
	check(scroll.visible and not confirm.is_visible_in_tree() and host.field.preview_kind.is_empty(), label + " Back restores picker without building")
	check(root.gui_get_focus_owner() == last, label + " Back restores selected icon focus")
	scroll.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_HOME
	key.pressed = true
	Input.parse_input_event(key)
	await settle()
	check(scroll.scroll_horizontal == 0, label + " keyboard returns to first card")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/build-icons-%s-%d.png" % [label, root.size.x])
	var first := cards.get_child(0) as Button
	await touch(first.get_global_rect().get_center(), true)
	await touch(first.get_global_rect().get_center(), false)
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/build-details-%s-%d.png" % [label, root.size.x])
	back.pressed.emit()
	await settle()
	# An additional card extends the strip without changing its height or host.
	var height := menu.size.y
	var extra := preload("res://scripts/ui/towers/tower_choice.gd").create("rapid", "Future tower", 90, func(): pass, 1, "", 150)
	cards.add_child(extra)
	await settle()
	scroll.ensure_control_visible(extra)
	await settle()
	check(is_equal_approx(menu.size.y, height) and scroll.get_global_rect().grow(1).encloses(extra.get_global_rect()), label + " extra content stays reachable at the same menu height")
	cards.remove_child(extra)
	extra.queue_free()

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://build-cards-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.field.set_process(false)
	app.game.data.balance = 100000
	app.game.expand("1,0")
	app.game.data.settings.developer_balance = {"towers": {"electric": {"damage": 7.0, "period": 0.25, "targets": 3, "range": 175.0, "cost": 250.0}}}
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		await settle()
		app.panels.selection_kind = "rapid"
		app.panels.select_pad("0,0", 1)
		await settle()
		await exercise(app, app.panels, app.panels.action_button, "infinite")
		app.panels.close_sheet()
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	campaign.start_mission(0)
	campaign.field.set_process(false)
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		await settle()
		campaign.show_socket(campaign.run.mission.sockets[1].index)
		await settle()
		await exercise(campaign, campaign.dialog_card, campaign.find_child("CampaignBuildConfirm", true, false), "campaign")
		campaign.close_dialog()
	app.free()
	print("BUILD CARDS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
