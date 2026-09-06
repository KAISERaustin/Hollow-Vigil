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
var sheet_revision := 0
var prices: Array[Dictionary] = []
var content_scroll: ScrollContainer
var header_content: VBoxContainer
var action_footer: VBoxContainer
var opener: Control
var settings_sheet_height := 520.0

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)
	header_content = UI.margin(layout, 16)
	action_footer = UI.margin(layout, 16)
	header_content.get_parent().add_theme_constant_override("margin_top", 12)
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
	sheet_content.minimum_size_changed.connect(func():
		if visible:
			call_deferred("fit_sheet")
	)
	app.resized.connect(fit_sheet)
	hide()

func clear_sheet(title: String, subtitle: String = "") -> void:
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
	action_footer.get_parent().hide()
	if not visible:
		opener = get_viewport().gui_get_focus_owner()
	for container in [header_content, action_footer]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	content_scroll.show()
	content_scroll.scroll_vertical = 0
	sheet_revision += 1
	prices.clear()
	for node in sheet_content.get_children():
		sheet_content.remove_child(node)
		node.queue_free()
	action_button = null
	var row := HBoxContainer.new()
	header_content.add_child(row)
	var heading := UI.heading(title, 30 if mode == "settings" else 24)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var close := UI.button("×", close_sheet, 48)
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
	elif mode in ["sound", "cloud"]:
		# Keep the Settings frame when entering or rebuilding its submenus.
		desired_height = settings_sheet_height
	if mode == "core":
		# Include the shared inner margins and panel padding, without unused space.
		desired_height = sheet_height()
	var bottom := field.get_global_rect().end.y - 12.0
	var top := field.global_position.y + 12.0
	if app.size.y >= 700.0:
		top = maxf(140.0, top)
	self.size.y = minf(desired_height, bottom - top)
	self.position.y = bottom - self.size.y
	UI.trap_focus(self)

func sheet_height() -> float:
	var layout := header_content.get_parent().get_parent() as VBoxContainer
	var height := get_theme_stylebox("panel").get_minimum_size().y
	var sections := 0
	for section in [header_content.get_parent(), content_scroll, action_footer.get_parent()]:
		if section.visible:
			sections += 1
			height += sheet_content.get_parent().get_combined_minimum_size().y if section == content_scroll else section.get_combined_minimum_size().y
	return height + maxi(0, sections - 1) * layout.get_theme_constant("separation")

func commit_developer_fields() -> void:
	for child in sheet_content.get_children():
		if child is DeveloperControls:
			child.commit_fields()

func close_sheet() -> void:
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
	else:
		show_build()

func show_build() -> void:
	mode = "build"
	field.preview_kind = selection_kind
	clear_sheet("Build")
	if game.economy.needs_first_property():
		sheet_content.add_child(UI.paragraph("Buy your first property before building a tower. Close this panel and select a neighboring territory marked + to buy it for 100 gold. You will have 180 gold left for towers.", 14))
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	sheet_content.add_child(row)
	for kind in Balance.TOWERS:
		var definition := Balance.definition("towers", kind, game.tuning)
		var b := UI.button(definition.name + " · " + UI.exact_money(definition.cost) + " gold", func(): selection_kind = kind; show_build(), 48)
		b.add_theme_font_size_override("font_size", UI.type_size(14))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := UI.box(UI.SURFACE)
			style.content_margin_left = 12
			style.content_margin_right = 12
			b.add_theme_stylebox_override(state, style)
		b.toggle_mode = true
		b.set_pressed_no_signal(selection_kind == kind)
		if selection_kind == kind:
			var selected := UI.box(UI.GOLD)
			selected.content_margin_left = 12
			selected.content_margin_right = 12
			b.add_theme_stylebox_override("normal", selected)
			b.add_theme_stylebox_override("hover", selected)
			b.add_theme_stylebox_override("pressed", selected)
			b.add_theme_stylebox_override("hover_pressed", selected)
		row.add_child(UI.action_row(definition.name + " · " + UI.exact_money(definition.cost) + " gold", b, "Select"))
	var s := Balance.definition("towers", selection_kind, game.tuning)
	action_cost = s.cost
	var revision := sheet_revision
	action_button = UI.gold_button("Build " + s.name + "  ·  " + UI.exact_money(s.cost) + " gold", func():
		if revision != sheet_revision:
			return
		if game.economy.needs_first_property():
			app.toast("Buy your first property before building a tower.")
			return
		var id := game.economy.build(selection_kind, selection_region, selection_pad)
		if id != "":
			selection_tower = id
			field.selected_tower = id
			app.persist()
			show_tower()
		else:
			app.toast("Not enough gold, or this socket is already occupied.")
	)
	action_footer.add_child(action_button)
	action_footer.get_parent().show()
	app.update_hud()

func show_tower() -> void:
	if not game.data.towers.has(selection_tower):
		return
	hide()
	sheet_revision += 1
	action_button = null
	prices.clear()
	mode = "tower"
	app.tower_actions.blocked = false
	app.tower_actions.refresh()
	app.update_hud()

func show_expansion(id: String) -> void:
	if not VigilWorld.frontier(game.data.regions, int(game.data.seed)).has(id):
		return
	mode = "expand"
	field.show_expansion = true
	clear_sheet("Claim Castle Ruin" if VigilWorld.is_ruin(id, int(game.data.seed)) else "Expand")
	if VigilWorld.is_ruin(id, int(game.data.seed)):
		var description := "Open dungeon ground with connecting paths and four tower sockets. This territory has no portal; the other ruin territories remain available to claim."
		if VigilWorld.is_dungeon_portal(id, int(game.data.seed)):
			description = "Four tower sockets surround this dungeon’s only portal. Other ruin territories remain available to claim. " + Balance.rift_description("castle_ruin", game.tuning)
		sheet_content.add_child(UI.paragraph(description, 14))
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
	if style != "castle_ruin":
		for kind in Balance.UNLOCK_COSTS:
			if kind not in r.unlocks:
				rift_maxed = false
	clear_sheet(Balance.rift_name(style))
	if rift_maxed:
		var status := UI.paragraph("MAX · Rift maxed out", 16)
		status.add_theme_color_override("font_color", UI.GOLD)
		sheet_content.add_child(status)
	sheet_content.add_child(UI.paragraph(Balance.rift_description(style, game.tuning) + ("" if style == "castle_ruin" else " Applies to every enemy from this rift for its entire journey."), 14))
	var revision := sheet_revision
	var traffic := UI.button("Traffic · MAX" if traffic_maxed else "Increase traffic  ·  " + UI.exact_money(game.economy.traffic_cost(id)) + " gold", func():
		if revision == sheet_revision and game.economy.buy_traffic(id, int(r.traffic)):
			app.persist()
			show_entrance(id)
	)
	price_button(traffic, game.economy.traffic_cost(id), traffic_maxed)
	sheet_content.add_child(UI.action_row(traffic.text, traffic, "MAX" if traffic_maxed else "Increase"))
	if style == "castle_ruin":
		return
	for kind in Balance.UNLOCK_COSTS:
		var s: Dictionary = Balance.ENEMIES[kind]
		var unlocked: bool = kind in r.unlocks
		var price: float = Balance.UNLOCK_COSTS[kind]
		var b := UI.button(s.name + (" · Attuned" if unlocked else " · Attune · " + UI.exact_money(price) + " gold"), func():
			if revision == sheet_revision and game.economy.unlock(id, kind):
				app.persist()
				show_entrance(id)
		, 58)
		b.add_theme_font_size_override("font_size", UI.type_size(14))
		price_button(b, price, unlocked)
		sheet_content.add_child(UI.action_row(b.text, b, "Attuned" if unlocked else "Attune"))

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

func _player_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "PlayerNameCard"
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := UI.surface(UI.GOLD, 3, 16)
	style.shadow_color = Color(UI.BORDER, 0.18)
	style.shadow_offset = Vector2(0, 4)
	style.shadow_size = 2
	card.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	card.add_child(stack)
	var caption := UI.label("HOLLOW VIGIL  /  PLAYER", 12)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(caption)
	stack.add_child(UI.rule())
	var player_name := UI.heading("", 24)
	player_name.name = "SettingsPlayerName"
	player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	stack.add_child(player_name)
	var hint := UI.paragraph("", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(hint)
	var refresh := func():
		var signed_in: bool = app.cloud.signed_in()
		player_name.text = app.cloud.display_name if signed_in and not app.cloud.display_name.is_empty() else ("Choose your name" if signed_in else "Guest")
		hint.text = "Manage your name in Account & cloud saves" if signed_in else "Sign in to give your account a name"
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
	sheet_content.add_child(_player_card())
	var sound_button := UI.button("Sound", show_sound_settings)
	sound_button.name = "OpenSoundSettings"
	sheet_content.add_child(UI.action_row("Sound", sound_button, "Open"))
	var cloud_button := UI.button("Account & cloud saves", show_cloud_saves)
	cloud_button.name = "OpenCloudSaves"
	sheet_content.add_child(UI.action_row(cloud_button.text, cloud_button, "Open"))
	sheet_content.add_child(UI.paragraph("Save %d · %s" % [app.active_slot + 1, str(game.data.get("mode", "creative")).capitalize()], 14))
	sheet_content.add_child(UI.action_row("Your saves", UI.button("Your saves", app.show_save_slots), "Open"))
	var public_button := UI.button("Public Builds", app.show_public_builds)
	public_button.name = "OpenPublicBuilds"
	sheet_content.add_child(UI.action_row(public_button.text, public_button, "Open"))
	if game.data.has("setup"):
		sheet_content.add_child(UI.paragraph(game.data.setup.name + "\n" + game.data.setup.description, 14))
	if game.is_creative():
		var developer := UI.button("Developer Controls", show_developer_controls)
		developer.name = "OpenDeveloperControls"
		sheet_content.add_child(UI.action_row(developer.text, developer, "Open"))
		sheet_content.add_child(UI.action_row("Save configuration", UI.button("Save configuration", app.show_save_slots.bind(true)), "Open"))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	sheet_content.add_child(stats)
	for stat in [["Lifetime gold", game.data.lifetime_earnings], ["Escaped", game.data.escapes]]:
		var stat_panel := PanelContainer.new()
		stat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_panel.add_theme_stylebox_override("panel", UI.plain())
		stats.add_child(stat_panel)
		var contents := VBoxContainer.new()
		contents.add_theme_constant_override("separation", 4)
		stat_panel.add_child(contents)
		contents.add_child(UI.label(stat[0], 12, UI.MUTED))
		contents.add_child(UI.heading(Balance.money(stat[1]), 18))
	sheet_content.add_child(UI.rule())
	sheet_content.add_child(UI.heading("Progress", 18))
	sheet_content.add_child(UI.action_row("Reset progress", UI.accent_button("Reset progress", show_reset_confirmation, UI.DANGER), "Reset"))
	sheet_content.add_child(UI.action_row("Return to the core", UI.button("Return to the core", return_to_core), "Return"))

func show_sound_settings() -> void:
	mode = "sound"
	clear_sheet("Sound")
	var sound := preload("res://scripts/audio/audio_settings.gd").new()
	sound.app = app
	sheet_content.add_child(sound)
	var back := UI.button("Back to settings", show_settings)
	back.name = "BackToSettings"
	sheet_content.add_child(UI.action_row(back.text, back, "Back"))

func show_developer_controls() -> void:
	if not game.is_creative():
		return
	mode = "developer"
	clear_sheet("Developer Controls")
	var controls := DeveloperControls.new()
	controls.game = game
	controls.field = field
	controls.changed.connect(app.balance_changed)
	var back := UI.button("←", func():
		if controls.editor.visible:
			controls.show_categories()
			content_scroll.scroll_vertical = 0
		else:
			show_settings()
	)
	back.custom_minimum_size.x = UI.TARGET
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var header := header_content.get_child(0)
	header.add_child(back)
	header.move_child(back, 0)
	controls.layout_changed.connect(func():
		back.name = "BackToCategories" if controls.editor.visible else "BackToSettings"
		back.accessibility_name = "Back to categories" if controls.editor.visible else "Back to settings"
		back.tooltip_text = back.accessibility_name
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
		action_button.tooltip_text = "Buy your first property before building a tower." if mode == "build" and game.economy.needs_first_property() else ""
	for item in prices:
		if is_instance_valid(item.button):
			item.button.disabled = item.locked or game.data.balance < item.cost
			item.button.tooltip_text = "Need " + UI.exact_money(item.cost - game.data.balance) + " more gold" if not item.locked and game.data.balance < item.cost else ""

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
	clear_sheet("Account & cloud saves")
	var controls := preload("res://scripts/cloud/cloud_panel.gd").new()
	controls.app = app
	sheet_content.add_child(controls)
	action_footer.add_child(UI.button("Back to settings", show_settings))
	action_footer.get_parent().show()
