extends "res://tests/rendered/mobile_campaign_controls_runner.gd"
## Render the complete menu families with isolated local data and audit contrast.
var pages := 0

class OfflineCloud extends "res://scripts/cloud/cloud_service.gd":
	func _request(_path: String, _body: Dictionary, _authenticated: bool) -> Dictionary:
		return {"ok": false, "code": 0, "data": null}


func luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722

func contrast(a: Color, b: Color) -> float:
	return (maxf(luminance(a), luminance(b)) + 0.05) / (minf(luminance(a), luminance(b)) + 0.05)

func audit_colors(node: Node, background: Color = UI.BG) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is Window and not node.visible: return
	if node is ColorRect: background = background.blend(node.color)
	if node.has_meta("ui_surface"): background = node.get_meta("ui_surface")
	if node is PanelContainer or node is Panel or node is PopupPanel:
		var style: StyleBox = node.get_theme_stylebox("panel")
		if style.get("bg_color") != null:
			background = background.blend(style.bg_color)
			if style.bg_color.a > 0 and style.border_width_left > 0:
				check(style.border_width_left == UI.OUTLINE and style.border_color == Color.BLACK, "Shared panel rim: " + str(node.name))
	if node is Label:
		var style: StyleBox = node.get_theme_stylebox("normal")
		if style.get("bg_color") != null: background = background.blend(style.bg_color)
		if not node.text.is_empty():
			check(contrast(node.get_theme_color("font_color"), background) >= 4.5, "Readable label: %s / %s on %s" % [node.name, node.text.left(35), background.to_html()])
	if node is LineEdit or node is TextEdit:
		background = node.get_theme_stylebox("normal").bg_color
		for role in ["font_color", "font_placeholder_color", "caret_color"]:
			check(contrast(node.get_theme_color(role), background) >= 4.5, "Readable field %s: %s" % [node.name, role])
	if node is Button:
		var states := {"normal": "font_color", "hover": "font_hover_color", "pressed": "font_pressed_color", "hover_pressed": "font_hover_pressed_color", "disabled": "font_disabled_color"}
		for state in states:
			var style: StyleBox = node.get_theme_stylebox(state)
			if style.get("bg_color") == null: continue # Native illustrated map landmarks.
			check(style.border_width_left == UI.BUTTON_OUTLINE and style.border_color == Color.BLACK, "Shared button rim: " + str(node.name))
			if not node.text.is_empty():
				check(contrast(node.get_theme_color(states[state]), style.bg_color) >= 4.5, "Readable button %s / %s" % [node.name, state])
		var state := "disabled" if node.disabled else ("pressed" if node.button_pressed else "normal")
		var style: StyleBox = node.get_theme_stylebox(state)
		if style.get("bg_color") != null: background = style.bg_color
	for child in node.get_children(): audit_colors(child, background)

func inspect(label: String, owner: Node = null) -> void:
	await settle()
	audit_colors(app if owner == null else owner)
	pages += 1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/moonlit-%dx%d-%s.png" % [root.size.x, root.size.y, label])

func inspect_picker(key: String, label: String) -> void:
	var picker = app.find_child(key, true, false)
	check(picker != null, "Picker exists: " + key)
	if picker == null: return
	picker.show_popup()
	await inspect(label, picker.popup)
	picker.popup.hide()
	await settle()

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://moonlit-theme-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.private_backups.enabled = false
	app.audio.set_suspended(true)
	var original_cloud := app.cloud
	app.cloud = OfflineCloud.new()
	app.cloud.enabled = false
	app.cloud.game = app.game
	app.add_child(app.cloud)
	for service in [app.public_builds, app.private_backups, app.bug_reports, app.change_log]: service.cloud = app.cloud
	original_cloud.queue_free()
	app.change_log.busy = true
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var menu = app.slot_menu
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.campaign_slots.base_path = app.game.save_path + str(dimensions.x)
		menu.slots.base_path = app.game.save_path + str(dimensions.x)
		var saved: Dictionary = menu.campaign_slots.create(0, "creative", "Pickard's long campaign name")
		menu.begin_new(1)
		for route in ["show_main_menu", "show_home", "show_slots", "show_play_style"]:
			menu.call(route)
			await inspect(route)
		menu.new_game.mode = "creative"
		for route in ["show_play_style", "show_starting_build", "show_review"]:
			menu.call(route)
			await inspect(route + "-selected")
		await inspect_picker("SaveSlotChoice", "save-slot-picker")
		menu.show_settings(menu.show_main_menu)
		await inspect("settings")
		for palette in UI.BUTTON_PALETTES:
			app.set_button_colors(palette)
			menu.show_button_colors()
			await inspect("button-colors-" + palette)
		app.set_button_colors("moonlit_iron")
		menu.show_sound()
		await inspect("sound")
		menu.scroll.scroll_vertical = 100000
		await inspect("sound-bottom")
		menu.show_account(menu.show_settings)
		await inspect("account-sign-in")
		app.cloud.player_id = "theme-fixture"
		app.cloud.refresh_token = "local-fixture"
		app.cloud.display_name = "Pickard"
		app.cloud.email = "knight@example.invalid"
		menu.show_account()
		await inspect("account-profile")
		app.cloud.player_id = ""
		app.cloud.refresh_token = ""
		menu.show_bug_report()
		await inspect("bug-report")
		app.change_log.entries = [{"change_date": "2026-09-16", "summary": "Moonlit iron menus with warm text and clear actions."}]
		menu.show_change_log()
		await inspect("change-log")
		menu.open_library(false)
		await inspect("my-builds-empty")
		menu.open_build_form()
		menu.form.name = "Moonlit Campaign"
		menu.form.description = "A locally generated review fixture."
		menu.show_build_form()
		await inspect("save-build")
		await inspect_picker("BuildScope", "build-scope-picker")
		menu.form.scope = "level"
		menu.form.level = 0
		menu.show_build_form()
		await inspect_picker("BuildLevel", "build-level-picker")
		var build: Dictionary = menu.prepared_form()
		var code: String = menu.Build.encode(build)
		menu.slots.save_shared(code)
		menu.open_library(false)
		await inspect("my-builds")
		menu.read_detail(menu.library_entries[0])
		await inspect("build-details")
		menu.open_library(true)
		await inspect("community-offline")
		menu.library_entries = [menu.detail_entry]
		menu.show_library_entries()
		await inspect("community-entry")
		menu.read_detail(menu.detail_entry)
		await inspect("community-details")
		menu.show_backups(menu.show_home)
		await inspect("backups")
		menu.scroll.scroll_vertical = 100000
		await inspect("backups-bottom")
		menu.restore_choice = {"game_type": "campaign", "snapshot": saved, "source": "cloud", "destination": -1, "revision": 0, "slot_number": 0}
		menu.show_restore_destination()
		await inspect("restore-destination")
		menu.restore_choice.destination = 0
		menu.review_restore()
		await inspect("restore-conflict")
		menu.confirm_slot_deletion("campaign", 0)
		await inspect("delete-confirmation")
		var popup := menu.get_child(menu.get_child_count() - 1) as PopupPanel
		popup.hide()
		await settle()
		app.open_campaign_slot(0, saved)
		campaign = app.campaign
		campaign.set_process(false)
		await inspect("campaign-map")
		for chapter in 6:
			campaign.page_scroll.scroll_vertical = chapter * 960
			await inspect("map-chapter-%d" % (chapter + 1))
		campaign.show_briefing(0)
		await inspect("briefing")
		campaign.start_mission(0)
		await inspect("battle-build-strip")
		campaign.show_waves()
		await inspect("waves")
		campaign.show_wave_balance(0)
		await inspect("wave-balance")
		campaign.show_level_balance(0, 0)
		await inspect("wave-editor")
		menu.hide()
		campaign.close_dialog()
		campaign.show_waves()
		campaign.show_enemy_quantity(0, "basic")
		await inspect("enemy-quantity")
		campaign.show_add_wave_enemy(0)
		await inspect("add-wave-enemy")
		for route in ["confirm_reset_waves", "confirm_new_wave"]:
			campaign.call(route)
			await inspect(route)
		campaign.confirm_remove_wave(0)
		await inspect("remove-wave")
		campaign.close_dialog()
		menu.open_game_menu()
		await inspect("game-menu")
		menu.show_campaign_content_rules()
		await inspect("rules-categories")
		for category in ["enemies", "bosses", "towers"]:
			var browser = menu.rules_editor
			browser.show_category(category)
			await inspect("rules-" + category)
			var definitions: Dictionary = Balance.TOWERS if category == "towers" else Balance.definitions(category)
			for kind in definitions:
				browser.open_item(category, kind)
				await inspect(category + "-" + kind)
				browser.open_group("Stats")
				await inspect(category + "-" + kind + "-stats")
				if category == "towers":
					for tier in browser.tier_selector.item_count:
						browser.tier_selector.select(tier)
						browser.tier_selector.item_selected.emit(tier)
						await inspect("tower-%s-tier-%d" % [kind, tier])
					await inspect_picker("BalanceTier", "tower-%s-tier-picker" % kind)
					browser.stats_editor.choosing = true
					browser.stats_editor.rebuild()
					await inspect(category + "-" + kind + "-add-stat")
				browser.cancel_item()
		menu.rules_editor.hide()
		menu.level_rules.show_levels()
		await inspect("rules-levels")
		for index in 30:
			menu.level_rules.show_level(index)
			await inspect("level-%d-rules" % (index + 1))
			menu.level_rules.open_group("Stats")
			await inspect("level-%d-stats" % (index + 1))
			menu.level_rules.cancel_item()
		menu.hide()
		campaign.game.data.balance = 1000000
		var socket: Dictionary = campaign.run.mission.sockets[0]
		campaign.run.build(socket.index, "rapid")
		campaign.board.selected_tower = campaign.run.tower_at(socket.index)
		for action in ["info", "upgrade", "target", "sell", "move"]:
			campaign.tower_dialog.open_action(action)
			await inspect("tower-" + action)
		campaign.tower_dialog.hide()
		campaign.confirm_level_exit()
		await inspect("exit-level")
		campaign.close_dialog()
		for result in ["victory", "defeat"]:
			campaign.run.phase = result
			campaign.show_result()
			await inspect(result)
		campaign.close(false)
		await settle()
	print("MOONLIT THEME: %d checks, %d failures, %d rendered page states across three portrait sizes" % [checks, failures.size(), pages])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
