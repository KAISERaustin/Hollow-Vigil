extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func settle() -> void:
	for step in 10: await process_frame
	await RenderingServer.frame_post_draw

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func confirm(host: Control, campaign: bool) -> Button:
	return host.dialog_actions.get_node("CampaignBuildConfirm") if campaign else host.panels.action_button

func choose(host: Control, kind: String, campaign: bool) -> void:
	var prefix := "CampaignBuild_" if campaign else "Build_"
	host.panels.build_choices.get_node("Cards/" + prefix + kind).pressed.emit()

func verify_selection(host: Control, campaign: bool, kind: String, label: String, details: bool = true) -> void:
	var menu: Control = host.dialog_card if campaign else host.panels
	var cards: ScrollContainer = host.panels.build_choices
	check(host.field.preview_kind == kind, label + " previews the remembered tower")
	check(cards.visible != details and confirm(host, campaign).is_visible_in_tree() == details, label + " restores the chosen menu page")
	var pressed := 0
	for button in cards.get_node("Cards").get_children():
		if button.button_pressed:
			pressed += 1
			check(button.get_meta("tower_kind") == kind, label + " highlights the remembered icon")
	check(pressed == 1, label + " highlights exactly one icon")
	if details:
		var title: Label = host.dialog_title if campaign else menu.find_child("SheetTitle", true, false)
		check(title.text == Balance.TOWERS[kind].name and confirm(host, campaign).text.contains(Balance.TOWERS[kind].name), label + " restores the tower heading and Build action")
		var stats := Balance.stats(kind, 1, host.game.tuning)
		var damage: Label = menu.find_child("Stat_damage", true, false)
		check(damage.text == VigilInterface.exact_money(stats.damage), label + " restores the correct tower stats")
	var portrait: Node2D = host.field.build_preview.portrait
	var position := VigilWorld.pad_position(host.field.selected_region, host.field.selected_pad)
	check(portrait.is_visible_in_tree() and portrait.position.is_equal_approx(host.field.screen(position)), label + " moves the highlighted tower to the selected socket")
	check(is_equal_approx(host.field.selected_range(), Balance.stats(kind, 1, host.game.tuning).range), label + " uses the selected tower range")

func exercise(host: Control, campaign: bool, select_first: Callable, select_next: Callable, label: String) -> void:
	var field: Battlefield = host.field
	field.set_process(false)
	host.game.data.balance = 100000
	var funds: float = host.game.data.balance
	var count: int = host.game.data.towers.size()
	select_first.call()
	await settle()
	verify_selection(host, campaign, preload("res://scripts/ui/towers/tower_choice.gd").first_kind(), label + " initial", false)
	choose(host, "heavy", campaign)
	await settle()
	# Use the battlefield signals used by real slot clicks, while details are open.
	select_next.call()
	await settle()
	verify_selection(host, campaign, "heavy", label + " switched slot")
	check(host.game.data.balance == funds and host.game.data.towers.size() == count, label + " changing slots does not build or spend")
	host.game.data.balance = 0
	select_first.call()
	await settle()
	verify_selection(host, campaign, "heavy", label + " unaffordable")
	check(confirm(host, campaign).disabled, label + " restores affordability on the new slot")
	confirm(host, campaign).pressed.emit()
	check(host.game.data.towers.size() == count and host.panels.build_selection.details_open, label + " failed construction preserves the detail page")
	host.game.data.balance = funds
	if campaign: host.close_dialog()
	else: host.panels.close_sheet()
	select_next.call()
	await settle()
	verify_selection(host, campaign, "heavy", label + " reopened")
	var menu: Control = host.dialog_card if campaign else host.panels
	menu.find_child("BackToTowers", true, false).pressed.emit()
	await settle()
	check(field.preview_kind.is_empty(), label + " Back clears the visible preview")
	select_first.call()
	await settle()
	verify_selection(host, campaign, "heavy", label + " remembered picker", false)
	choose(host, "electric", campaign)
	select_next.call()
	await settle()
	verify_selection(host, campaign, "electric", label + " replacement choice")
	# Build must use the latest destination, never the previously selected slot.
	var destination_region: String = field.selected_region
	var destination_pad: int = field.selected_pad
	await preload("res://tests/rendered/visual_smoke.gd").tap(host, confirm(host, campaign).get_global_rect().get_center(), label.ends_with("survival"))
	await settle()
	var id: String = host.game.economy.tower_at(destination_region, destination_pad)
	check(not id.is_empty() and host.game.data.towers[id].kind == "electric", label + " builds the remembered kind at the latest slot")
	check(host.game.data.towers.size() == count + 1 and is_equal_approx(host.game.data.balance, funds - Balance.definition("towers", "electric", host.game.tuning).cost), label + " constructs and charges exactly once")
	check(field.preview_kind.is_empty(), label + " construction clears the temporary preview")
	if campaign:
		check(host.tower_actions.visible and not host.dialog.visible and field.selected_tower == id, label + " successful build keeps the new tower controls open")
	select_first.call()
	await settle()
	verify_selection(host, campaign, "electric", label + " after construction", not campaign)
	root.get_texture().get_image().save_png("res://artifacts/remembered-build-%s.png" % label)
	if campaign:
		for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
			root.size = viewport
			root.content_scale_size = viewport
			select_first.call()
			await settle()
			verify_selection(host, true, "electric", label + " card menu after building " + str(viewport), false)
			check(host.dialog_title.text == "Build a tower" and host.dialog_card.find_child("TowerDetails", true, false) == null, label + " next empty slot opens cards without tower details")
			check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(host.dialog_card.get_global_rect()), label + " post-build cards fit the phone")
			root.get_texture().get_image().save_png("res://artifacts/build-cards-after-construction-%s-%d.png" % [label, viewport.x])
		choose(host, "electric", true)
		await settle()
	# Inspecting an occupied slot must not overwrite the last build-menu choice.
	select_next.call()
	await settle()
	select_first.call()
	await settle()
	verify_selection(host, campaign, "electric", label + " after tower inspection")
	if campaign:
		await exercise_upgrade_reset(host, select_first, select_next, label)

func exercise_upgrade_reset(host: Control, select_empty: Callable, select_tower: Callable, label: String) -> void:
	const Harness = preload("res://tests/rendered/visual_smoke.gd")
	# Neither inspection nor an unsuccessful purchase should reset build history.
	select_tower.call()
	host.tower_actions.buttons.upgrade.pressed.emit()
	var tower: Dictionary = host.game.data.towers[host.field.selected_tower]
	var funds: float = host.game.data.balance
	host.game.data.balance = 0.0
	host.tower_dialog.refresh()
	host.tower_dialog.confirm.pressed.emit()
	check(tower.level == 1 and host.build_selection.details_open, label + " failed upgrade preserves build details")
	host.game.data.balance = funds
	host.tower_dialog.dismiss()
	select_empty.call()
	await settle()
	verify_selection(host, true, "electric", label + " cancelled upgrade")
	# Exercise both normal tiers and specialization, with phone-size captures.
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		select_tower.call()
		host.tower_actions.buttons.upgrade.pressed.emit()
		if tower.level == 3:
			host.tower_dialog.find_child("Preview_thunderseal", true, false).pressed.emit()
		await settle()
		var level: int = tower.level
		var quote: float = host.tower_dialog.cost
		funds = host.game.data.balance
		await Harness.tap(host, host.tower_dialog.confirm.get_global_rect().get_center(), label.ends_with("survival"))
		await settle()
		check(tower.level == level + 1 and host.game.data.balance == funds - quote, label + " upgrade completes at " + str(viewport))
		check(not host.build_selection.details_open and host.build_selection.kind == "electric", label + " successful upgrade returns to cards without losing tower choice")
		select_empty.call()
		await settle()
		verify_selection(host, true, "electric", label + " after upgrade " + str(viewport), false)
		check(host.dialog_title.text == "Build a tower" and host.dialog_card.find_child("TowerDetails", true, false) == null, label + " empty slot shows the card catalog without tower stats")
		check(host.build_choices.get_node("Cards").get_child_count() == Balance.TOWERS.size(), label + " card catalog includes every available tower")
		check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(host.dialog_card.get_global_rect()), label + " post-upgrade catalog fits the phone")
		root.get_texture().get_image().save_png("res://artifacts/build-cards-after-upgrade-%s-%d.png" % [label, viewport.x])
		choose(host, "electric", true)
		await settle()
		verify_selection(host, true, "electric", label + " new build choice restores normal memory")

func run() -> void:
	Input.emulate_mouse_from_touch = true
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	for mode in ["creative", "survival"]:
		var app := VigilApp.new()
		app.load_saved_progress = false
		app.game.save_path = "user://build-selection-%s.save" % mode
		root.add_child(app)
		app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app.set_process(false)
		app.game.data.mode = mode
		app.game.data.balance = 100000
		app.game.expand("1,0")
		await settle()
		await exercise(app, false, func(): app.field.picked.emit("0,0", 1), func(): app.field.picked.emit("1,0", 2), "infinite-" + mode)
		app.show_campaign()
		var campaign: Control = app.campaign
		campaign.set_process(false)
		campaign.mode = mode
		campaign.start_mission(0)
		await settle()
		await exercise(campaign, true, func(): campaign.board.socket_picked.emit(campaign.run.mission.sockets[1].index), func(): campaign.board.socket_picked.emit(campaign.run.mission.sockets[2].index), "campaign-" + mode)
		campaign.start_mission(0)
		campaign.field.set_process(false)
		campaign.show_socket(campaign.run.mission.sockets[1].index)
		await settle()
		verify_selection(campaign, true, preload("res://scripts/ui/towers/tower_choice.gd").first_kind(), "new mission " + mode, false)
		app.free()
	print("BUILD SELECTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
