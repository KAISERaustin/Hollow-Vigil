class_name VigilPanels
extends PanelContainer

const UI = preload("res://scripts/ui/shared/interface.gd")
const DeveloperControls = preload("res://scripts/ui/developer/developer_controls.gd")
var app: VigilApp
var game: VigilState:
	get: return app.game
var field: Battlefield:
	get: return app.field
var sheet_content: VBoxContainer
var mode := ""
var selection_region := "0,0"
var selection_pad := -1
var selection_tower := ""
var selection_kind := "rapid"
var action_button: Button
var action_cost := 0.0
var build_choices: ScrollContainer
var build_selection := preload("res://scripts/ui/towers/build_selection.gd").new()
var build_back: Button
var sheet_revision := 0
var prices: Array[Dictionary] = []
var content_scroll: ScrollContainer
var header_content: VBoxContainer
var header_divider: ColorRect
var action_footer: VBoxContainer
var opener: Control
var settings_sheet_height := 520.0

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)
	header_content = UI.margin(layout, UI.SCREEN_PADDING)
	header_divider = ColorRect.new()
	header_divider.name = "SettingsHeaderDivider"
	header_divider.color = UI.BORDER
	header_divider.custom_minimum_size.y = UI.OUTLINE
	header_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_divider.hide()
	layout.add_child(header_divider)
	action_footer = UI.margin(layout, 16)
	header_content.get_parent().add_theme_constant_override("margin_top", UI.SCREEN_PADDING)
	header_content.get_parent().add_theme_constant_override("margin_bottom", 0)
	action_footer.get_parent().add_theme_constant_override("margin_top", 0)
	action_footer.get_parent().add_theme_constant_override("margin_bottom", 12)
	content_scroll = ScrollContainer.new()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.follow_focus = true
	UI.keyboard_scroll(content_scroll, "Menu contents")
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content_scroll)
	layout.move_child(action_footer.get_parent(), -1)
	sheet_content = UI.margin(content_scroll, 16)
	sheet_content.get_parent().add_theme_constant_override("margin_top", 0)
	sheet_content.get_parent().add_theme_constant_override("margin_bottom", 0)
	sheet_content.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Wrapped titles and footer buttons can change minimum height after their
	# containers assign a width. Refit all sections, including empty-body sheets.
	for section in [header_content, sheet_content, action_footer]:
		section.minimum_size_changed.connect(func():
			if visible:
				call_deferred("fit_sheet")
		)
	app.resized.connect(fit_sheet)
	# Draw the rim after scrolling children so partially visible controls cannot cover it.
	clip_contents = true
	var frame := UI.rounded_viewport_frame()
	frame.name = "SheetFrame"
	add_child(frame)
	hide()

func clear_sheet(title: String, subtitle: String = "") -> void:
	field.build_preview.clear(field)
	commit_developer_fields()
	app.tower_move.cancel()
	# Opening another panel leaves tower management and restores the gold badges.
	field.selected_tower = ""
	if mode != "build":
		field.selected_pad = -1
	app.tower_actions.blocked = true
	app.tower_actions.refresh()
	sheet_content.add_theme_constant_override("separation", 12)
	header_content.get_parent().show()
	header_divider.visible = mode == "settings"
	action_footer.get_parent().hide()
	if not visible:
		opener = get_viewport().gui_get_focus_owner()
	for container in [header_content, action_footer]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	content_scroll.show()
	content_scroll.scroll_vertical = 0
	sheet_content.add_theme_constant_override("separation", 12)
	sheet_revision += 1
	prices.clear()
	for node in sheet_content.get_children():
		sheet_content.remove_child(node)
		node.queue_free()
	action_button = null
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.GAP)
	header_content.add_child(row)
	var heading := UI.fitted_heading(title) if mode == "developer" else UI.heading(title, 30 if mode == "settings" else 24)
	heading.name = "SheetTitle"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var close := UI.close_button(close_sheet, 48)
	close.name = "CloseSheet"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size.x = 48
	close.accessibility_name = "Close " + title
	row.add_child(close)
	if subtitle != "":
		sheet_content.add_child(UI.paragraph(subtitle))
	self.show()
	app.reset_scrim.visible = mode == "reset"
	close.grab_focus()
	# Bound overlays independently of wrapped text; long content scrolls on smaller phones.
	call_deferred("fit_sheet")

func fit_sheet() -> void:
	if not self.visible:
		return
	# Empty scroll containers still reserve margins and spacing in the sheet.
	content_scroll.visible = sheet_content.get_child_count() > 0
	sheet_content.get_parent().add_theme_constant_override("margin_bottom", 0 if action_footer.get_parent().visible else 12)
	# Account management is a full-screen view from every entry point.
	# Inset only the contents for notches and home indicators, not the background.
	var safe := UI.safe_rect(app) if mode == "cloud" else Rect2(Vector2.ZERO, app.size)
	for section in [header_content, sheet_content, action_footer]:
		var padding: int = UI.SCREEN_PADDING if section == header_content else UI.PADDING
		section.get_parent().add_theme_constant_override("margin_left", padding + int(safe.position.x))
		section.get_parent().add_theme_constant_override("margin_right", padding + int(app.size.x - safe.end.x))
	header_content.get_parent().add_theme_constant_override("margin_top", UI.SCREEN_PADDING + int(safe.position.y))
	if mode == "cloud":
		sheet_content.get_parent().add_theme_constant_override("margin_bottom", 12 + int(app.size.y - safe.end.y))
		self.position = Vector2.ZERO
		self.size = app.size
		UI.trap_focus(self)
		return
	if mode == "reset":
		self.size.x = minf(460.0, UI.safe_rect(app).size.x - 32.0)
		var content_height := sheet_height()
		self.size.y = minf(content_height, app.size.y - 32.0)
		self.position = (app.size - self.size) * 0.5
		UI.trap_focus(self)
		return
	self.size.x = minf(460.0, UI.safe_rect(app).size.x - 24.0)
	self.position.x = UI.safe_rect(app).position.x + (UI.safe_rect(app).size.x - self.size.x) * 0.5
	var heights := {"build": 500.0, "expand": 290.0, "rift": 470.0, "core": 310.0, "settings": 520.0, "developer": 660.0}
	var desired_height: float = heights.get(mode, 340.0)
	if mode in ["build", "expand", "rift", "settings"]:
		# Keep gameplay panels as small as their controls allow.
		desired_height = sheet_height()
		# sheet_height already includes the visible layout gaps and panel border.
	if mode == "settings":
		settings_sheet_height = desired_height
	elif mode == "sound":
		# Keep the Settings frame when entering or rebuilding its submenus.
		desired_height = settings_sheet_height
	if mode == "core":
		# Include the shared inner margins and panel padding, without unused space.
		desired_height = sheet_height()
	var bottom := minf(field.get_global_rect().end.y, UI.safe_rect(app).end.y) - 12.0
	var top := maxf(field.global_position.y, UI.safe_rect(app).position.y) + 12.0
	if app.size.y >= 700.0:
		top = maxf(140.0, top)
	self.size.y = minf(desired_height, bottom - top)
	self.position.y = bottom - self.size.y
	UI.trap_focus(self)

func sheet_height() -> float:
	var layout := header_content.get_parent().get_parent() as VBoxContainer
	var height := get_theme_stylebox("panel").get_minimum_size().y
	var sections := 0
	for section in [header_content.get_parent(), header_divider, content_scroll, action_footer.get_parent()]:
		if section.visible:
			sections += 1
			height += sheet_content.get_parent().get_combined_minimum_size().y if section == content_scroll else section.get_combined_minimum_size().y
	return height + maxi(0, sections - 1) * layout.get_theme_constant("separation")

func commit_developer_fields() -> void:
	for child in sheet_content.get_children():
		if child is DeveloperControls:
			child.commit_fields()

func close_sheet() -> void:
	field.build_preview.clear(field)
	commit_developer_fields()
	if is_instance_valid(app.tower_move):
		app.tower_move.cancel()
	if mode == "developer":
		app.persist()
	sheet_revision += 1
	action_button = null
	prices.clear()
	if is_instance_valid(app.tower_dialog):
		app.tower_dialog.dismiss(false)
	self.hide()
	if is_instance_valid(app.reset_scrim):
		app.reset_scrim.hide()
	if is_instance_valid(opener) and opener.is_visible_in_tree():
		opener.grab_focus()
	mode = ""
	field.selected_tower = ""
	field.selected_pad = -1
	field.show_expansion = false
	app.tower_actions.refresh()

func select_pad(region: String, pad: int) -> void:
	selection_region = region
	selection_pad = pad
	selection_tower = game.economy.tower_at(region, pad)
	field.selected_region = region
	field.selected_pad = pad
	field.selected_tower = selection_tower
	if selection_tower != "":
		# Selection collects once; rebuilding the upgrade panel never collects.
		app.collect_one(selection_tower, true)
		show_tower()
		app.tower_dialog.open_action("preview")
	else:
		show_build()

func show_build() -> void:
	app.ground_build.open()

func select_build_kind(kind: String, choices: ScrollContainer) -> void:
	build_selection.select(kind)
	selection_kind = kind
	field.preview_kind = kind
	preload("res://scripts/ui/towers/tower_choice.gd").show_details(choices, game.tuning, kind)
	var definition := Balance.definition("towers", kind, game.tuning)
	action_cost = definition.cost
	action_button.text = "Build " + definition.name + "  ·  " + UI.exact_money(definition.cost) + " gold"
	(header_content.find_child("SheetTitle", true, false) as Label).text = definition.name
	build_back.show()
	action_footer.get_parent().show()
	content_scroll.scroll_vertical = 0
	build_back.grab_focus()
	field.build_preview.open(field, self)
	fit_sheet.call_deferred()
	app.update_hud()

func show_build_choices() -> void:
	build_selection.show_choices()
	preload("res://scripts/ui/towers/tower_choice.gd").clear_details(build_choices)
	build_back.hide()
	action_footer.get_parent().hide()
	(header_content.find_child("SheetTitle", true, false) as Label).text = "Build"
	field.build_preview.clear(field)
	content_scroll.scroll_vertical = 0
	build_choices.get_node("Cards/Build_" + selection_kind).grab_focus()
	fit_sheet.call_deferred()

func show_tower() -> void:
	if not game.data.towers.has(selection_tower):
		return
	field.build_preview.clear(field)
	hide()
	sheet_revision += 1
	action_button = null
	prices.clear()
	mode = "tower"
	app.tower_actions.blocked = false
	app.tower_actions.reset_framing()
	app.tower_actions.refresh()
	app.update_hud()

func show_expansion(id: String) -> void:
	if not VigilWorld.frontier(game.data.regions, int(game.data.seed)).has(id):
		return
	mode = "expand"
	field.show_expansion = true
	clear_sheet("Claim Castle Ruin" if VigilWorld.is_ruin(id, int(game.data.seed)) else "Expand")
	var biome := Balance.Content.region(VigilWorld.region_style(id, int(game.data.seed)))
	var cluster := preload("res://scripts/world/biome_clusters.gd").at(id, int(game.data.seed))
	var boss_text: String = "Cluster boss: " + Balance.BOSSES[biome.boss_kind()].name + ". One encounter for this biome cluster."
	if cluster.boss_tile == "":
		boss_text = "Starting forest: normal portal spawns, no boss encounter."
	if cluster.boss_tile == id:
		boss_text += " This is its encounter tile."
	sheet_content.add_child(UI.paragraph(boss_text, 14))
	if VigilWorld.is_ruin(id, int(game.data.seed)):
		var description := "Open dungeon ground with connecting paths and four tower sockets. This territory has no portal; the other ruin territories remain available to claim."
		if VigilWorld.is_dungeon_portal(id, int(game.data.seed)):
			description = "Four tower sockets surround this dungeon’s only portal. Other ruin territories remain available to claim. " + Balance.rift_description("castle_ruin", game.tuning)
		sheet_content.add_child(UI.paragraph(description, 14))
	if VigilWorld.region_style(id, int(game.data.seed)) == "mourning_orchard":
		sheet_content.add_child(UI.paragraph("Mourning Orchard · Pale thorn trees grow around a single root-bound portal. " + Balance.rift_description("mourning_orchard", game.tuning), 14))
	action_cost = Balance.expansion_cost(game.data.regions.size())
	var revision := sheet_revision
	action_button = UI.gold_button("Claim territory  ·  " + UI.exact_money(action_cost) + " gold", func():
		if revision == sheet_revision and game.expand(id):
			field.camera = VigilWorld.center(id) * 0.65 + field.camera * 0.35
			selection_region = id
			app.persist()
			close_sheet()
	)
	action_footer.add_child(action_button)
	action_footer.get_parent().show()
	app.update_hud()

func show_entrance(id: String) -> void:
	if not VigilWorld.has_rift(id, game.data.regions, int(game.data.seed)) or not game.data.regions.has(id):
		show_core()
		return
	selection_region = id
	mode = "rift"
	var r: Dictionary = game.data.regions[id]
	var style: String = r.get("style", "forest")
	var traffic_maxed: bool = r.traffic >= Balance.MAX_TRAFFIC_LEVEL
	var rift_maxed := traffic_maxed
	var unlock_costs := Balance.portal_unlock_costs(style)
	for kind in unlock_costs:
		if kind not in r.unlocks:
			rift_maxed = false
	clear_sheet(Balance.rift_name(style))
	if rift_maxed:
		var status := UI.paragraph("MAX · Rift maxed out", 16)
		status.add_theme_color_override("font_color", UI.GOLD)
		sheet_content.add_child(status)
	sheet_content.add_child(UI.paragraph(Balance.rift_description(style, game.tuning), 14))
	for kind in Balance.portal_kinds(style):
		var enemy: Dictionary = Balance.ENEMIES[kind]
		var row := HBoxContainer.new()
		row.name = "PortalEnemy_" + kind
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.enemy_preview(kind))
		var available: bool = kind in Balance.portal_available_kinds(style, r.unlocks)
		row.add_child(UI.paragraph(enemy.name + (" · Active" if available else " · Attunement required"), 14))
		sheet_content.add_child(row)
	var revision := sheet_revision
	var traffic := UI.button("Spawn rate · MAX" if traffic_maxed else "Increased spawn rate  ·  " + UI.exact_money(game.economy.traffic_cost(id)) + " gold", func():
		if revision == sheet_revision and game.economy.buy_traffic(id, int(r.traffic)):
			app.persist()
			show_entrance(id)
	)
	price_button(traffic, game.economy.traffic_cost(id), traffic_maxed)
	traffic.name = "PortalTraffic"
	sheet_content.add_child(UI.action_row(traffic.text, traffic, "MAX" if traffic_maxed else "Increase"))
	for kind in unlock_costs:
		var s: Dictionary = Balance.ENEMIES[kind]
		var unlocked: bool = kind in r.unlocks
		var price: float = unlock_costs[kind]
		var b := UI.button(s.name + ("" if unlocked else " · " + UI.exact_money(price) + " gold"), func():
			if revision == sheet_revision and game.economy.unlock(id, kind):
				app.persist()
				show_entrance(id)
		, 58)
		b.add_theme_font_size_override("font_size", UI.type_size(14))
		b.name = "Attune_" + kind
		price_button(b, price, unlocked)
		sheet_content.add_child(UI.action_row(b.text, b, "Attuned" if unlocked else "Attune", UI.enemy_preview(kind)))

func show_core() -> void:
	close_sheet()
	mode = "core"
	clear_sheet("Core")
	sheet_content.add_child(UI.paragraph("Enemies that reach the core escape. Build and upgrade towers along the roads to stop them.", 14))

func return_to_core() -> void:
	field.camera = VigilWorld.CORE_POSITION
	field.zoom = 1.0
	field.camera_changed.emit()
	close_sheet()
	app.persist()

func _settings_card(tint: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := UI.surface(tint, UI.OUTLINE, 10)
	card.add_theme_stylebox_override("panel", style)
	return card

func _player_card() -> PanelContainer:
	var card := _settings_card(UI.GOLD)
	card.name = "PlayerNameCard"
	var stack := HBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	card.add_child(stack)
	var caption := UI.label("PLAYER ACCOUNT", 12)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_child(caption)
	var player_name := UI.heading("", 24)
	player_name.name = "SettingsPlayerName"
	player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	stack.add_child(player_name)
	var refresh := func():
		var signed_in: bool = app.cloud.signed_in()
		player_name.text = app.cloud.display_name if signed_in and not app.cloud.display_name.is_empty() else ("Choose your name" if signed_in else "Guest")
	refresh.call()
	app.cloud.changed.connect(refresh)
	card.tree_exiting.connect(func():
		if app.cloud.changed.is_connected(refresh):
			app.cloud.changed.disconnect(refresh))
	return card

func show_settings() -> void:
	if mode == "developer":
		commit_developer_fields()
		app.persist()
	mode = "settings"
	clear_sheet("Settings")
	sheet_content.add_theme_constant_override("separation", 6)
	sheet_content.add_child(_player_card())
	var account_divider := ColorRect.new()
	account_divider.color = UI.BORDER
	account_divider.custom_minimum_size.y = 2
	account_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet_content.add_child(account_divider)
	var cloud_button := UI.button("Account & cloud backups", show_cloud_saves)
	cloud_button.name = "OpenCloudSaves"
	sheet_content.add_child(UI.action_row("Account & cloud backups", cloud_button, "Open"))
	sheet_content.add_child(UI.heading("Current game", 18))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	sheet_content.add_child(stats)
	for stat in [["Lifetime gold", game.data.lifetime_earnings], ["Escaped", game.data.escapes]]:
		var stat_panel := _settings_card(UI.PANEL.lerp(UI.GOLD, 0.45))
		stat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(stat_panel)
		var contents := VBoxContainer.new()
		contents.add_theme_constant_override("separation", 4)
		stat_panel.add_child(contents)
		contents.add_child(UI.label(stat[0], 12, UI.MUTED))
		contents.add_child(UI.heading(Balance.money(stat[1]), 18))
	if game.is_creative():
		var developer := UI.button("Developer Controls", show_developer_controls)
		developer.name = "OpenDeveloperControls"
		sheet_content.add_child(UI.action_row("Creative rules", developer, "Edit"))
	var stats_button := UI.button("Stat configurations", func():
		if app.show_save_slots(): app.slot_menu.show_stat_configurations()
	)
	stats_button.name = "OpenStatConfigurations"
	sheet_content.add_child(UI.action_row("Custom gameplay stats", stats_button, "Open"))
	sheet_content.add_child(UI.heading("Preferences", 18))
	var sound_button := UI.button("Sound", show_sound_settings)
	sound_button.name = "OpenSoundSettings"
	sheet_content.add_child(UI.action_row("Sound", sound_button, "Open"))
	var upload := UI.button("Upload build", app.show_save_slots.bind(true))
	upload.name = "UploadBuild"
	sheet_content.add_child(UI.action_row("Upload build", upload, "Open"))
	sheet_content.add_child(UI.action_row("Reset progress", UI.accent_button("Reset progress", show_reset_confirmation, UI.DANGER), "Reset"))
	sheet_content.add_child(UI.action_row("Saved Games", UI.button("Saved Games", app.show_save_slots), "Exit"))

func show_sound_settings() -> void:
	mode = "sound"
	clear_sheet("Sound")
	var sound := preload("res://scripts/audio/audio_settings.gd").new()
	sound.app = app
	sheet_content.add_child(sound)
	add_header_back("Back to settings", show_settings)

func add_header_back(label: String, action: Callable) -> Button:
	var back := UI.back_button(label, action)
	back.name = "BackToSettings"
	var header := header_content.get_child(0)
	header.add_child(back)
	header.move_child(back, 0)
	return back

func show_developer_controls() -> void:
	if not game.is_creative():
		return
	mode = "developer"
	clear_sheet("Developer Controls")
	var controls := DeveloperControls.new()
	controls.game = game
	controls.field = field
	controls.changed.connect(app.balance_changed)
	var back := add_header_back("Back to settings", func():
		if controls.editor.visible:
			controls.show_categories()
			content_scroll.scroll_vertical = 0
		else:
			show_settings()
	)
	controls.layout_changed.connect(func():
		back.name = "BackToCategories" if controls.editor.visible else "BackToSettings"
		back.accessibility_name = "Back to categories" if controls.editor.visible else "Back to settings"
		var title := header_content.find_child("SheetTitle", true, false) as Label
		title.text = controls.category_title(controls.category) if controls.editor.visible else "Developer Controls"
		UI.fit_heading(title)
		content_scroll.scroll_vertical = 0
		call_deferred("fit_sheet")
	)
	sheet_content.add_child(controls)

func show_reset_confirmation() -> void:
	mode = "reset"
	clear_sheet("Reset all progress?", "This permanently removes claimed territories, purchases, upgrades, and earned gold. You will start again with the core territory, empty tower slots, and starting gold.")
	action_footer.add_child(UI.button("Cancel", show_settings))
	action_footer.add_child(UI.accent_button("Reset and start over", app.reset_progress, UI.DANGER))
	action_footer.get_parent().show()

func refresh_affordability() -> void:
	if is_instance_valid(action_button):
		action_button.disabled = game.data.balance < action_cost or (mode == "build" and game.economy.needs_first_property())
		action_button.accessibility_description = "Buy your first property before building a tower." if mode == "build" and game.economy.needs_first_property() else ""
	for item in prices:
		if is_instance_valid(item.button):
			item.button.disabled = item.locked or game.data.balance < item.cost
			item.button.accessibility_description = "Need " + UI.exact_money(item.cost - game.data.balance) + " more gold" if not item.locked and game.data.balance < item.cost else ""

func price_button(button: Button, cost: float, locked: bool = false) -> void:
	prices.append({"button": button, "cost": cost, "locked": locked})
	button.disabled = locked or game.data.balance < cost

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not app.return_overlay.visible and not app.tower_dialog.visible:
		if mode == "reset":
			show_settings()
		else:
			close_sheet()
		get_viewport().set_input_as_handled()

func show_cloud_saves() -> void:
	mode = "cloud"
	clear_sheet("Account & cloud backups")
	var controls := preload("res://scripts/cloud/cloud_panel.gd").new()
	controls.app = app
	sheet_content.add_child(controls)
	add_header_back("Close backups", close_sheet)
