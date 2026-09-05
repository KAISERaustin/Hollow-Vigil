class_name VigilPanels
extends PanelContainer

const UI = preload("res://scripts/ui/interface.gd")
const FieldGuide = preload("res://scripts/ui/field_guide.gd")
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
var guide: FieldGuide
var header_content: VBoxContainer
var action_footer: VBoxContainer
var affordability: Label
var opener: Control

func _ready() -> void:
	var layout := VBoxContainer.new()
	add_child(layout)
	header_content = UI.margin(layout, 16)
	action_footer = UI.margin(layout, 16)
	content_scroll = ScrollContainer.new()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content_scroll)
	layout.move_child(action_footer.get_parent(), -1)
	sheet_content = UI.margin(content_scroll, 16)
	sheet_content.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_content.minimum_size_changed.connect(func():
		if visible:
			call_deferred("fit_sheet")
	)
	guide = FieldGuide.new()
	guide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide.close_requested.connect(close_sheet)
	layout.add_child(guide)
	guide.hide()
	app.resized.connect(fit_sheet)
	hide()

func clear_sheet(title: String, subtitle: String = "") -> void:
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
	affordability = null
	guide.hide()
	content_scroll.show()
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
	if mode == "reset":
		self.size.x = minf(460.0, UI.safe_rect(app).size.x - 32.0)
		var content_height: float = sheet_content.get_parent().get_combined_minimum_size().y + header_content.get_parent().get_combined_minimum_size().y + action_footer.get_parent().get_combined_minimum_size().y
		self.size.y = minf(content_height, app.size.y - 32.0)
		self.position = (app.size - self.size) * 0.5
		UI.trap_focus(self)
		return
	self.size.x = minf(460.0, UI.safe_rect(app).size.x - 24.0)
	self.position.x = UI.safe_rect(app).position.x + (UI.safe_rect(app).size.x - self.size.x) * 0.5
	var heights := {"info": 580.0, "build": 500.0, "expand": 290.0, "rift": 470.0, "core": 310.0, "settings": 520.0}
	var desired_height: float = heights.get(mode, 340.0)
	if mode == "core":
		# Include the shared inner margins and panel padding, without unused space.
		desired_height = sheet_content.get_parent().get_combined_minimum_size().y + header_content.get_parent().get_combined_minimum_size().y + action_footer.get_parent().get_combined_minimum_size().y
	var bottom := field.get_global_rect().end.y - 12.0
	var top := field.global_position.y + 12.0
	if app.size.y >= 700.0:
		top = maxf(140.0, top)
	self.size.y = minf(desired_height, bottom - top)
	self.position.y = bottom - self.size.y
	UI.trap_focus(self)

func close_sheet() -> void:
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

func show_info() -> void:
	close_sheet()
	# Retire any pending purchase callback before opening the read-only guide.
	sheet_revision += 1
	prices.clear()
	action_button = null
	mode = "info"
	content_scroll.hide()
	header_content.get_parent().hide()
	action_footer.get_parent().hide()
	guide.show()
	guide.show_category("towers")
	show()
	guide.tabs.towers.grab_focus()
	call_deferred("fit_sheet")

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
	clear_sheet("Raise a sentinel", "Choose a tower. The ring shows its reach. Tap Build to raise it.")
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	sheet_content.add_child(row)
	for kind in Balance.TOWERS:
		var definition: Dictionary = Balance.TOWERS[kind]
		var b := UI.button(definition.name + " · " + definition.role + " · " + UI.exact_money(definition.cost) + " gold", func(): selection_kind = kind; show_build(), 48)
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
		row.add_child(b)
	var s: Dictionary = Balance.TOWERS[selection_kind]
	sheet_content.add_child(UI.paragraph(s.description))
	sheet_content.add_child(UI.paragraph("%s damage   ·   %.2fs attack   ·   %d reach" % [Balance.money(s.damage), s.period, s.range], 13))
	action_cost = s.cost
	var revision := sheet_revision
	action_button = UI.gold_button("Build " + s.name + "  ·  " + UI.exact_money(s.cost) + " gold", func():
		if revision != sheet_revision:
			return
		var id := game.economy.build(selection_kind, selection_region, selection_pad)
		if id != "":
			selection_tower = id
			field.selected_tower = id
			app.persist()
			app.toast(s.name + " joins the vigil.")
			show_tower()
		else:
			app.toast("Not enough gold, or this socket is already occupied.")
	)
	action_footer.add_child(action_button)
	action_footer.get_parent().show()
	affordability = UI.paragraph("")
	action_footer.add_child(affordability)
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
	if not VigilWorld.frontier(game.data.regions).has(id):
		return
	mode = "expand"
	field.show_expansion = true
	clear_sheet("Beyond the mist", "Claim territory " + id + " to uncover a rift, four tower sockets, and a road to the core.")
	sheet_content.add_child(UI.paragraph("Defeat enemies from the new rift to earn more gold.", 14))
	action_cost = Balance.expansion_cost(game.data.regions.size())
	var revision := sheet_revision
	action_button = UI.gold_button("Claim territory  ·  " + UI.exact_money(action_cost) + " gold", func():
		if revision == sheet_revision and game.expand(id):
			field.camera = VigilWorld.center(id) * 0.65 + field.camera * 0.35
			selection_region = id
			app.persist()
			close_sheet()
			app.toast("A new rift opens. Raise sentinels along its roads.")
	)
	action_footer.add_child(action_button)
	action_footer.get_parent().show()
	affordability = UI.paragraph("")
	action_footer.add_child(affordability)
	app.update_hud()

func show_entrance(id: String) -> void:
	if not VigilWorld.has_rift(id) or not game.data.regions.has(id):
		show_core()
		return
	selection_region = id
	mode = "rift"
	var r: Dictionary = game.data.regions[id]
	clear_sheet("Rift  /  " + id, "Enemies pour from the rift. Increase their numbers or attune the rift to new foes.")
	var rate := 60.0 / game.economy.spawn_period(id)
	sheet_content.add_child(UI.paragraph("%.0f enemies/min  →  %.0f with next traffic upgrade" % [rate, 60.0 / Balance.traffic_period(r.traffic + 1)], 13))
	var basic: Dictionary = Balance.ENEMIES.basic
	var minimum_basic: float = Balance.enemy_mix(Balance.UNLOCK_COSTS.keys()).basic
	sheet_content.add_child(UI.paragraph("%s: at least %.0f%% of enemies · %s HP · %s gold per defeat." % [basic.name, minimum_basic * 100.0, String.num(basic.hp, 2), String.num(basic.payout, 2)], 13))
	var revision := sheet_revision
	var traffic := UI.button("Increase traffic  ·  " + UI.exact_money(game.economy.traffic_cost(id)) + " gold", func():
		if revision == sheet_revision and game.economy.buy_traffic(id, int(r.traffic)):
			app.persist()
			show_entrance(id)
	)
	price_button(traffic, game.economy.traffic_cost(id), r.traffic >= Balance.MAX_TRAFFIC_LEVEL)
	sheet_content.add_child(traffic)
	for kind in Balance.UNLOCK_COSTS:
		var s: Dictionary = Balance.ENEMIES[kind]
		var unlocked: bool = kind in r.unlocks
		var price: float = Balance.UNLOCK_COSTS[kind]
		var description := "%s: %.0f%% of traffic · %s HP\n%s · %s gold" % [s.name, Balance.ENEMY_SHARES[kind] * 100.0, String.num(s.hp, 2), s.role.to_lower(), String.num(s.payout, 2)]
		var b := UI.button(description + ("\nAlready attuned" if unlocked else "\nAttune  ·  " + UI.exact_money(price) + " gold"), func():
			if revision == sheet_revision and game.economy.unlock(id, kind):
				app.persist()
				show_entrance(id)
		, 58)
		b.add_theme_font_size_override("font_size", UI.type_size(14))
		price_button(b, price, unlocked)
		sheet_content.add_child(b)

func show_core() -> void:
	close_sheet()
	mode = "core"
	clear_sheet("The core", "The core is the portal at the center of the map. All enemy routes end here.")
	sheet_content.add_child(UI.paragraph("Build sentinels in nearby stone sockets to defeat enemies and earn gold. Expand your territory to add more defenses along the roads.", 14))
	sheet_content.add_child(UI.paragraph("Enemies that reach the core escape. They cause no damage and take no gold, but you earn nothing from them.", 13))
	sheet_content.add_child(UI.paragraph("Escaped through the core  " + Balance.money(game.data.escapes), 13))

func return_to_core() -> void:
	field.camera = VigilWorld.CORE_POSITION
	field.zoom = 1.0
	field.camera_changed.emit()
	close_sheet()
	app.persist()

func show_settings() -> void:
	mode = "settings"
	clear_sheet("Settings", "Raise sentinels, gather gold, and expand your vigil beyond the mist.")
	sheet_content.add_child(UI.button("Power saving: " + ("On · 30 FPS" if game.data.settings.low_power else "Off · 60 FPS"), func():
		game.data.settings.low_power = not game.data.settings.low_power
		Engine.max_fps = 30 if game.data.settings.low_power else 60
		app.persist()
		show_settings()
	))
	sheet_content.add_child(UI.button("Text size: %d%%" % roundi(UI.text_scale * 100), func():
		var sizes := [1.0, 1.25, 1.5]
		game.data.settings.text_scale = sizes[(sizes.find(UI.text_scale) + 1) % sizes.size()]
		app.apply_ui_preferences()
		app.persist()
		show_settings()
	))
	sheet_content.add_child(UI.button("Reduced motion: " + ("On" if UI.reduced_motion else "Off"), func():
		game.data.settings.reduced_motion = not UI.reduced_motion
		app.apply_ui_preferences()
		app.persist()
		show_settings()
	))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	sheet_content.add_child(stats)
	for stat in [["Lifetime gold", game.data.lifetime_earnings], ["Escaped", game.data.escapes]]:
		var field := PanelContainer.new()
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.add_theme_stylebox_override("panel", UI.plain())
		stats.add_child(field)
		var contents := VBoxContainer.new()
		contents.add_theme_constant_override("separation", 4)
		field.add_child(contents)
		contents.add_child(UI.label(stat[0], 12, UI.MUTED))
		contents.add_child(UI.heading(Balance.money(stat[1]), 18))
	sheet_content.add_child(UI.rule())
	sheet_content.add_child(UI.heading("Progress", 18))
	sheet_content.add_child(UI.accent_button("Reset progress", show_reset_confirmation, UI.DANGER))
	sheet_content.add_child(UI.button("Return to the core", return_to_core))

func show_reset_confirmation() -> void:
	mode = "reset"
	clear_sheet("Reset all progress?", "This permanently removes claimed territories, purchases, upgrades, and earned gold. You will start again with the core territory, empty tower slots, and starting gold.")
	action_footer.add_child(UI.button("Cancel", show_settings))
	action_footer.add_child(UI.accent_button("Reset and start over", app.reset_progress, UI.DANGER))
	action_footer.get_parent().show()

func refresh_affordability() -> void:
	if is_instance_valid(action_button):
		action_button.disabled = game.data.balance < action_cost
		if is_instance_valid(affordability):
			affordability.text = "Need " + UI.exact_money(action_cost - game.data.balance) + " more gold" if action_button.disabled else "Cost: " + UI.exact_money(action_cost) + " gold"
	for item in prices:
		if is_instance_valid(item.button):
			item.button.disabled = item.locked or game.data.balance < item.cost
			item.button.text = item.label + ("\nNeed " + UI.exact_money(item.cost - game.data.balance) + " more gold" if not item.locked and game.data.balance < item.cost else "")

func price_button(button: Button, cost: float, locked: bool = false) -> void:
	prices.append({"button": button, "cost": cost, "locked": locked, "label": button.text})
	button.disabled = locked or game.data.balance < cost

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not app.return_overlay.visible and not app.tower_dialog.visible:
		if mode == "reset":
			show_settings()
		else:
			close_sheet()
		get_viewport().set_input_as_handled()
