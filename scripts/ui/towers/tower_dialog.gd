class_name VigilTowerDialog
extends ColorRect

const UI = preload("res://scripts/ui/shared/interface.gd")
const TowerChoice = preload("res://scripts/ui/towers/tower_choice.gd")
signal upgraded
## Active mode host: game, field, controls, persistence and feedback.
var app: Control
var clear_selection_on_upgrade := false
var card: PanelContainer
var layout: VBoxContainer
var body: VBoxContainer
var scroll: ScrollContainer
var footer: BoxContainer
var heading: Label
var identity_card: PanelContainer
var management_grid: VBoxContainer
var management_bottom: HBoxContainer
var dismissal: Tween
var dismissing := false
var identity_row: BoxContainer
var identity_text: VBoxContainer
var level_holder: VBoxContainer
var level_display: Control
var identity: HBoxContainer
var equipment_summary: VBoxContainer
var portrait: Control
var header_close: Button
var header_back: Button
var header_divider: ColorRect
var tower_kind := "rapid"
var tower_branch := ""
var confirm: Button
var cancel: Button
var opener: Control
var mode := ""
var tower_id := ""
var tower_level := 0
var revision := 0
var cost := 0.0
var refund := 0.0
var rebuild_seconds := 0.0
var rebuild_status: Label
var target_choice := "first"
var relic_choice := ""
var relic_original := ""
var relic_owner := ""
var equipment_state := ""
var preview_state := ""
var upgrade_armed := false
var branch_cards: VBoxContainer

func _ready() -> void:
	name = "TowerDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(UI.BORDER, 0.65)
	mouse_filter = Control.MOUSE_FILTER_STOP
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, 0))
	add_child(card)
	layout = UI.margin(card, UI.SCREEN_PADDING)
	layout.minimum_size_changed.connect(func(): call_deferred("fit_dialog"))
	layout.add_theme_constant_override("separation", 16)
	identity = HBoxContainer.new()
	identity.add_theme_constant_override("separation", 12)
	layout.add_child(identity)
	header_back = UI.back_button("Back to tower", go_back)
	header_back.hide()
	identity.add_child(header_back)
	portrait = Control.new()
	portrait.custom_minimum_size = Vector2(48, 64)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.draw.connect(func():
		if mode == "equipment_detail" and app.game.data.relics.has(relic_choice):
			preload("res://scripts/rendering/actors/relic_art.gd").draw(portrait, app.game.data.relics[relic_choice], portrait.size * 0.5, minf(portrait.size.x, portrait.size.y) / 34.0)
		else:
			var shown_level := mini(tower_level + 1, Balance.MAX_TOWER_LEVEL) if mode == "preview" else tower_level
			VigilTerrainArt.sentinel_portrait(portrait, tower_kind, Vector2(20, 41) if mode == "preview" else Vector2(24, 45 if mode == "info" else 51), 0.65 if mode == "preview" else 0.85, Rect2(Vector2.ZERO, portrait.size).grow(-2), shown_level, tower_branch)
	)
	identity_card = PanelContainer.new()
	identity_card.name = "TowerIdentityCard"
	identity_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(identity_card)
	identity_row = BoxContainer.new()
	identity_row.add_theme_constant_override("separation", 8)
	identity_card.add_child(identity_row)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity_row.add_child(portrait)
	heading = UI.heading("", 24)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_text = VBoxContainer.new()
	identity_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_text.add_theme_constant_override("separation", 4)
	identity_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity_row.add_child(identity_text)
	identity_text.add_child(heading)
	header_close = UI.close_button(func():
		if mode == "equipment_detail": open_action("equipment")
		else: dismiss()
	, UI.TARGET)
	header_close.name = "CloseEquipment"
	header_close.accessibility_description = "Close"
	header_close.custom_minimum_size.x = UI.TARGET
	header_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	header_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(header_close)
	level_holder = VBoxContainer.new()
	layout.add_child(level_holder)
	management_grid = VBoxContainer.new()
	management_grid.add_theme_constant_override("separation", 8)
	management_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(management_grid)
	header_divider = ColorRect.new()
	header_divider.color = UI.BORDER
	header_divider.custom_minimum_size.y = UI.OUTLINE
	header_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(header_divider)
	equipment_summary = VBoxContainer.new()
	equipment_summary.hide()
	layout.add_child(equipment_summary)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	UI.keyboard_scroll(scroll, "Tower details")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	body.minimum_size_changed.connect(func(): call_deferred("fit_dialog"))
	footer = BoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	app.resized.connect(fit_dialog)
	hide()

func _has_point(point: Vector2) -> bool:
	var screen_point := global_position + point
	if mode == "info" and is_instance_valid(card) and not card.get_global_rect().has_point(screen_point):
		if _external_button_at(app, screen_point):
			return false
	# The compact management card leaves the persistent build strip interactive.
	# Purchase and equipment dialogs retain their full modal input boundary.
	if mode == "info" and is_instance_valid(app.ground_build):
		var palette: Control = app.ground_build.palette
		if palette.is_visible_in_tree() and palette.get_global_rect().has_point(global_position + point):
			return false
	return Rect2(Vector2.ZERO, size).has_point(point)

func open_action(action: String, branch: String = "") -> void:
	if action.begins_with("equipment"): return
	app.field.selected_tower_range_visible = true
	if dismissal: dismissal.kill()
	dismissing = false
	if action == "upgrade":
		open_action("info")
		arm_upgrade()
		return
	upgrade_armed = false
	app.field.upgrade_range_preview.clear()
	app.field.queue_redraw()
	card.scale = Vector2.ONE
	app.tower_actions.cancel_upgrade()
	if is_instance_valid(branch_cards):
		branch_cards.get_parent().remove_child(branch_cards)
		branch_cards.queue_free()
		branch_cards = null
	identity_card.show()
	var id: String = app.field.selected_tower
	if not action in ["info", "preview", "upgrade", "sell", "move", "target"] or not app.game.data.towers.has(id):
		return
	opener = get_viewport().gui_get_focus_owner()
	revision += 1
	header_close.reparent(identity)
	for child in management_grid.get_children():
		management_grid.remove_child(child)
		child.queue_free()
	mode = action
	management_grid.visible = action == "info"
	identity_row.vertical = action == "info"
	identity_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if action == "info" else HORIZONTAL_ALIGNMENT_LEFT
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if action == "info":
		level_holder.reparent(identity)
	else:
		level_holder.reparent(layout)
	if action == "info": identity.move_child(level_holder, 0)
	level_holder.visible = action == "info"
	identity_card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, 8) if action == "info" else UI.surface(UI.PANEL, 0, 0))
	footer.alignment = BoxContainer.ALIGNMENT_CENTER if action == "info" else BoxContainer.ALIGNMENT_BEGIN
	footer.add_theme_constant_override("separation", 8 if action == "info" else 12)
	scroll.visible = action != "info"
	color = Color(UI.BORDER, 0.0 if action == "info" else 0.65)
	layout.add_theme_constant_override("separation", 8 if action in ["info", "preview"] else 16)
	body.add_theme_constant_override("separation", 8 if action == "preview" else 12)
	portrait.custom_minimum_size = Vector2(40, 48) if action == "preview" else Vector2(48, 56 if action == "info" else 64)
	header_back.visible = action != "info"
	header_close.visible = action != "info"
	header_divider.visible = action == "equipment"
	footer.show()
	tower_id = id
	var tower: Dictionary = app.game.data.towers[id]
	tower_kind = tower.kind
	tower_branch = tower.get("branch", "")
	target_choice = tower.get("target_mode", "first")
	relic_original = tower.get("relic", "")
	relic_choice = relic_original
	relic_owner = preload("res://scripts/gameplay/progression/relics.gd").owner(app.game.data, relic_choice)
	equipment_state = equipment_fingerprint()
	portrait.queue_redraw()
	tower_level = int(tower.level)
	if is_instance_valid(level_display):
		level_holder.remove_child(level_display)
		level_display.queue_free()
		level_display = null
	heading.add_theme_font_size_override("font_size", UI.type_size(18 if action == "info" else 24))
	if action == "info":
		# Four 20-unit squares and three 8-unit gaps match the 104-unit action grid.
		level_display = preload("res://scripts/ui/shared/tower_level_indicator.gd").create(tower_level, false, true, 20.0)
		level_holder.add_child(level_display)
	cost = Balance.upgrade_cost(tower, app.game.tuning) if action == "upgrade" else 0.0
	if action == "preview":
		if tower_level == 3:
			tower_branch = branch if Balance.valid_branch(tower_kind, branch) else str(Balance.BRANCHES[tower_kind].keys()[0])
		cost = Balance.upgrade_cost(tower, app.game.tuning, tower_branch) if tower_level < Balance.MAX_TOWER_LEVEL else 0.0
		preview_state = preview_fingerprint()
	refund = app.game.economy.sell_refund(tower) if action == "sell" else 0.0
	if action == "move":
		cost = Balance.move_cost(tower, app.game.tuning)
	rebuild_seconds = Balance.rebuild_seconds(tower, app.game.tuning)
	for parent in [body, footer, equipment_summary]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	equipment_summary.visible = action == "equipment"
	var stats := Balance.tower_stats(tower, app.game.tuning, app.game.data.relics)
	heading.text = stats.name
	var label := {"info": "Tower information · Level %d", "upgrade": "Upgrade · Level %d", "sell": "Sell tower · Level %d", "move": "Move tower · Level %d", "target": "Targeting · Level %d", "equipment": "Equipment · Level %d"}
	if action not in ["info", "equipment", "preview"]:
		body.add_child(UI.label(label[action] % tower_level, 14))
	rebuild_status = UI.label("", 14, UI.TEXT)
	body.add_child(rebuild_status)
	if action == "preview":
		var next_level := mini(tower_level + 1, Balance.MAX_TOWER_LEVEL)
		body.add_child(preload("res://scripts/ui/shared/tower_level_indicator.gd").create(tower_level))
		var next := Balance.stats(tower_kind, next_level, app.game.tuning, tower_branch)
		heading.text = next.name
		if tower_level == Balance.MAX_TOWER_LEVEL:
			body.add_child(UI.label("Maximum level reached", 12, UI.MUTED))
		if tower_level == 3:
			var branches := HBoxContainer.new()
			branches.name = "UpgradeBranches"
			branches.add_theme_constant_override("separation", 8)
			body.add_child(branches)
			for option in Balance.BRANCHES[tower_kind]:
				var choice := UI.button(Balance.stats(tower_kind, next_level, app.game.tuning, option).name, func(): open_action("preview", option), 48)
				choice.name = "Preview_" + option
				choice.toggle_mode = true
				choice.set_pressed_no_signal(option == tower_branch)
				choice.add_theme_font_size_override("font_size", UI.type_size(14))
				branches.add_child(choice)
		var next_stats := Balance.equipment_stats(Balance.stats(tower_kind, next_level, app.game.tuning, tower_branch), tower, app.game.tuning, app.game.data.relics)
		var equipped: bool = app.game.data.relics.has(tower.get("relic", ""))
		body.add_child(TowerChoice.details(tower_kind, app.game.tuning, next_level, tower_branch, stats if tower_level < Balance.MAX_TOWER_LEVEL else {}, true, next_stats if equipped else {}))
	if action == "equipment":
		preload("res://scripts/ui/towers/relic_picker.gd").build(self)
	if action == "target":
		body.add_child(UI.paragraph("Choose which enemy this tower attacks within its range. First and Last use the remaining road distance to the core.", 14))
		var group := ButtonGroup.new()
		var descriptions := {"first": "Closest to the core", "last": "Farthest from the core", "most_hp": "Highest current health"}
		for key in Balance.TARGET_MODES:
			var choice := UI.button(Balance.TARGET_MODES[key] + "\n" + descriptions[key], func(): target_choice = key, 64)
			choice.add_theme_font_size_override("font_size", UI.type_size(14))
			choice.name = "Target_" + key
			choice.toggle_mode = true
			choice.button_group = group
			choice.add_theme_stylebox_override("pressed", UI.box(UI.GOLD))
			choice.add_theme_stylebox_override("hover_pressed", UI.box(UI.GOLD))
			choice.button_pressed = key == target_choice
			body.add_child(UI.action_row(Balance.TARGET_MODES[key] + "\n" + descriptions[key], choice, "Select"))
	if action == "move":
		var quote := UI.value("%s gold · Rebuild %s" % [UI.exact_money(cost), Balance.rebuild_time_text(rebuild_seconds)], 18)
		quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(quote)
		body.add_child(UI.paragraph("Choose clear ground away from roads, portals, and other towers. Tapping it pays the cost and starts rebuilding. Your tower keeps its level and stored gold, but cannot fire, upgrade, or move again until ready. Rebuilding continues while you are away.", 14))
	if action == "upgrade":
		var progression := "Maximum level reached · %d / %d" % [tower_level, Balance.MAX_TOWER_LEVEL] if tower_level >= Balance.MAX_TOWER_LEVEL else "Level %d → %d / %d" % [tower_level, tower_level + 1, Balance.MAX_TOWER_LEVEL]
		body.add_child(UI.label(progression, 14))
	if action == "sell":
		body.add_child(UI.paragraph("Remove this tower and refund " + UI.exact_money(refund) + " gold. Its stored " + UI.exact_money(tower.earnings) + " gold will also be collected. Equipment returns to your inventory.", 16))
	var opened_revision := revision
	scroll.scroll_vertical = 0
	cancel = UI.button("Cancel", go_back, 48)
	cancel.name = "CancelTowerAction"
	cancel.custom_minimum_size.x = 92
	cancel.size_flags_horizontal = Control.SIZE_FILL
	footer.add_child(cancel)
	if action == "info":
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		management_grid.add_child(top)
		management_bottom = HBoxContainer.new()
		management_bottom.add_theme_constant_override("separation", 8)
		management_grid.add_child(management_bottom)
		for item in [["equipment", "Equipment"], ["target", "Targeting"], ["sell", "Sell tower"], ["move", "Move tower"]]:
			var action_button := management_button(item[0], item[1], open_action.bind(item[0]))
			(management_bottom if item[0] == "move" else top).add_child(action_button)
	var text: String = {"info": "Upgrade", "preview": "Upgrade · " + UI.exact_money(cost) + " gold", "upgrade": "Upgrade · " + UI.exact_money(cost) + " gold", "sell": "Sell · +" + UI.exact_money(refund) + " gold", "move": "Choose destination", "target": "Apply targeting", "equipment": "Apply equipment"}[action]
	confirm = UI.accent_button(text, func(): commit(opened_revision), UI.DANGER if action == "sell" else UI.GOLD, 48)
	confirm.name = "ConfirmTowerAction"
	confirm.add_theme_font_size_override("font_size", UI.type_size(16))
	if action == "info":
		confirm.text = ""
		configure_management_button(confirm, "upgrade", "Upgrade tower")
	footer.add_child(confirm)
	if action == "info":
		confirm.reparent(management_bottom)
		confirm.custom_minimum_size.x = 104
		confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.hide()
	if action == "equipment":
		confirm.hide()
		cancel.text = "Close"
		footer.hide()
	if action == "info" and tower_level >= 3:
		build_branch_cards()
	app.tower_actions.blocked = true
	app.tower_actions.refresh()
	show()
	refresh()
	call_deferred("fit_dialog")
	cancel.visible = action not in ["info", "preview"]
	(header_close if action in ["equipment", "preview"] else (confirm if action == "info" else cancel)).grab_focus()
	UI.trap_focus(card)

func arm_upgrade(branch: String = "") -> void:
	if tower_level >= Balance.MAX_TOWER_LEVEL:
		return
	var selected_branch := branch if tower_level == 3 else tower_branch
	var tower: Dictionary = app.game.data.towers[tower_id]
	if app.game.data.balance < Balance.upgrade_cost(tower, app.game.tuning, selected_branch) or tower.get("rebuild_remaining", 0.0) > 0.0:
		return
	upgrade_armed = true
	if tower_level == 3:
		tower_branch = branch if Balance.valid_branch(tower_kind, branch) else str(Balance.BRANCHES[tower_kind].keys()[0])
	cost = Balance.upgrade_cost(app.game.data.towers[tower_id], app.game.tuning, tower_branch)
	app.field.upgrade_range_preview = {"id": tower_id, "level": tower_level, "branch": tower_branch}
	app.field.queue_redraw()
	for child in footer.get_children():
		footer.remove_child(child)
		child.queue_free()
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	footer.add_child(stack)
	if tower_level == 3:
		build_branch_cards()
	footer.hide()
	confirm.accessibility_name = "Confirm upgrade"
	confirm.queue_redraw()
	refresh()
	call_deferred("fit_dialog")

func build_branch_cards() -> void:
	if is_instance_valid(branch_cards):
		branch_cards.get_parent().remove_child(branch_cards)
		branch_cards.queue_free()
	identity_card.hide()
	branch_cards = VBoxContainer.new()
	branch_cards.name = "BranchCards"
	branch_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branch_cards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	branch_cards.add_theme_constant_override("separation", 8)
	identity.add_child(branch_cards)
	identity.move_child(branch_cards, identity_card.get_index())
	for option in Balance.BRANCHES[tower_kind]:
		var price := Balance.upgrade_cost({"kind": tower_kind, "level": 3}, app.game.tuning, option)
		var selected: bool = option == tower_branch
		var state := ("Selected" if selected else "Locked") if tower_level >= 4 else ("Tap again to confirm" if selected and upgrade_armed else "Select path")
		var choice := TowerChoice.branch_card(tower_kind, Balance.stats(tower_kind, 4, app.game.tuning, option).name, price, option, state, selected, func():
			if tower_level != 3: return
			if upgrade_armed and tower_branch == option:
				commit(revision)
			else:
				arm_upgrade(option)
		)
		choice.name = "Branch_" + option
		choice.disabled = tower_level >= 4 or app.game.data.balance < price or app.game.data.towers[tower_id].get("rebuild_remaining", 0.0) > 0.0
		branch_cards.add_child(choice)
	confirm.show()
	confirm.disabled = true
	confirm.accessibility_name = "Upgrade locked; choose a tower card" if tower_level == 3 else "Upgrade locked; maximum level"

func management_button(action: String, label: String, callback: Callable) -> Button:
	var button := UI.button("", callback, 48)
	button.name = "Manage_" + action
	configure_management_button(button, action, label)
	return button

func configure_management_button(button: Button, action: String, label: String) -> void:
	button.disabled = action == "equipment"
	button.custom_minimum_size = Vector2(48, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.accessibility_name = label
	button.accessibility_description = label
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := UI.box(UI.GOLD if action == "upgrade" else UI.SURFACE)
		style.set_content_margin_all(0)
		button.add_theme_stylebox_override(state, style)
	button.draw.connect(func():
		var equipped := preload("res://scripts/gameplay/progression/relics.gd").kind(app.game.data, app.game.data.towers[tower_id]) if app.game.data.towers.has(tower_id) else ""
		var center := button.size * 0.5
		if action == "upgrade" and tower_level >= 3:
			preload("res://scripts/ui/towers/tower_action_icon.gd").draw(button, action, equipped, true, "", center)
			return
		if action == "upgrade":
			var caption := "Max" if tower_level >= Balance.MAX_TOWER_LEVEL else UI.exact_money(cost if upgrade_armed else Balance.upgrade_cost(app.game.data.towers[tower_id], app.game.tuning))
			var font := button.get_theme_font("font")
			var font_size := UI.type_size(14)
			var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var left := (button.size.x - width - 32.0) * 0.5
			center.x = left + 12
			button.draw_string(font, Vector2(left + 32, (button.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UI.TEXT)
			button.accessibility_description = "Upgrade tower: " + caption
		preload("res://scripts/ui/towers/tower_action_icon.gd").draw(button, action, equipped, tower_level >= Balance.MAX_TOWER_LEVEL, tower_id if upgrade_armed else "", center)
	)

func show_equipment_details(relic_id: String) -> void:
	const Relics = preload("res://scripts/gameplay/progression/relics.gd")
	if mode != "equipment" or not app.game.data.relics.has(relic_id) or not Relics.owner(app.game.data, relic_id).is_empty():
		return
	mode = "equipment_detail"
	relic_choice = relic_id
	relic_owner = Relics.owner(app.game.data, relic_id)
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	rebuild_status = UI.label("", 14)
	body.add_child(rebuild_status)
	var kind: String = app.game.data.relics[relic_id]
	heading.text = Relics.DEFINITIONS[kind].name
	portrait.queue_redraw()
	equipment_summary.hide()
	body.add_child(UI.paragraph(Relics.description(kind, app.game.tuning), 16))
	if relic_owner != "" and relic_owner != tower_id:
		body.add_child(UI.paragraph("Equipped on " + Balance.tower_stats(app.game.data.towers[relic_owner], app.game.tuning).name, 14))
	confirm.text = "Equipped" if relic_choice == relic_original else ("Transfer equipment" if relic_owner != "" else "Equip")
	confirm.show()
	footer.show()
	cancel.hide()
	header_close.hide()
	header_back.show()
	refresh()
	header_back.grab_focus()
	call_deferred("fit_dialog")
	UI.trap_focus(card)

func request_equipment_removal() -> void:
	if mode not in ["equipment", "equipment_detail"] or relic_original == "":
		return
	mode = "equipment_remove"
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	rebuild_status = UI.label("", 14)
	body.add_child(rebuild_status)
	body.add_child(UI.heading("Remove equipment?", 20))
	body.add_child(UI.paragraph("Are you sure you want to remove this equipment? It will return to your inventory.", 16))
	equipment_summary.find_child("RemoveEquipment", true, false).hide()
	confirm.text = "Remove equipment"
	footer.show()
	confirm.show()
	cancel.text = "Cancel"
	for connection in cancel.pressed.get_connections():
		cancel.pressed.disconnect(connection.callable)
	cancel.pressed.connect(func(): open_action("equipment"))
	cancel.grab_focus()
	refresh()
	call_deferred("fit_dialog")
	UI.trap_focus(card)

func stat(grid: GridContainer, title: String, value: float, next: float, decimals: int = 1, suffix: String = "") -> void:
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 4)
	grid.add_child(stack)
	stack.add_child(UI.label(title, 14, UI.MUTED))
	var format := "%." + str(decimals) + "f"
	var text := (Balance.money(value) if value >= 10000 else format % value) + suffix
	if mode == "upgrade":
		text += " → " + (Balance.money(next) if next >= 10000 else format % next) + suffix
	var value_label := UI.value(text, 18)
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(value_label)

func fit_dialog() -> void:
	if not visible or dismissing:
		return
	if mode == "info":
		var info_safe := UI.safe_rect(app).grow(-12)
		card.size.x = minf(520.0, info_safe.size.x)
		heading.set_meta("fitted_heading_max", 18)
		heading.set_meta("fitted_heading_min", 14)
		UI.fit_heading(heading)
		footer.vertical = false
		scroll.custom_minimum_size.y = 0
		card.size.y = 0
		# Preserve the compact level/cards/actions row inside narrow portrait safe areas.
		var fitted_scale := minf(1.0, info_safe.size.x / card.size.x)
		card.scale = Vector2.ONE * fitted_scale
		var bottom := minf(info_safe.end.y, app.field.get_global_rect().end.y - 8)
		card.position = Vector2(info_safe.position.x + (info_safe.size.x - card.size.x * fitted_scale) * 0.5, maxf(info_safe.position.y, bottom - card.size.y * fitted_scale))
		return
	if mode == "preview":
		# Stat cards use the modal's safe area, with navigation and purchase pinned.
		var preview_safe := UI.safe_rect(app).grow(-16)
		card.size.x = minf(460.0, preview_safe.size.x)
		footer.vertical = false
		var preview_chrome: float = identity.get_combined_minimum_size().y + footer.get_combined_minimum_size().y + 2 * UI.SCREEN_PADDING + 8 + 16
		scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, maxf(40, preview_safe.size.y - preview_chrome))
		card.size.y = 0
		card.position = preview_safe.position + (preview_safe.size - card.size) * 0.5
		return
	var safe := UI.safe_rect(app).grow(-16)
	card.size.x = minf(460.0, safe.size.x)
	footer.vertical = card.size.x < 400 * UI.text_scale
	var chrome: float = identity.get_combined_minimum_size().y + (footer.get_combined_minimum_size().y if footer.visible else 0.0) + 64.0
	if header_divider.visible:
		chrome += header_divider.get_combined_minimum_size().y + layout.get_theme_constant("separation")
	if equipment_summary.visible:
		chrome += equipment_summary.get_combined_minimum_size().y + layout.get_theme_constant("separation")
	# Keep the inventory compact while its existing scroll container exposes every item.
	var height_limit := safe.size.y * 0.5 if mode == "equipment" else safe.size.y
	# A compact inventory still needs room for one complete touch row.
	var minimum_body := UI.TARGET + 2 * UI.CARD_PADDING if mode == "equipment" else UI.TARGET
	scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, maxf(minimum_body, height_limit - chrome))
	card.size.y = 0.0
	card.position = safe.position + (safe.size - card.size) * 0.5

func refresh() -> void:
	if not visible:
		return
	if (mode.begins_with("equipment") or mode in ["info", "preview"]) and app.field.selected_tower != tower_id:
		dismiss(false)
		return
	if not app.game.data.towers.has(tower_id) or app.game.data.towers[tower_id].level != tower_level:
		dismiss()
		return
	var tower: Dictionary = app.game.data.towers[tower_id]
	if mode == "preview" and preview_state != preview_fingerprint():
		open_action("preview", tower_branch)
		return
	if mode.begins_with("equipment") and equipment_state != equipment_fingerprint():
		open_action("equipment")
		return
	var remaining: float = tower.get("rebuild_remaining", 0.0)
	if mode == "info" and is_instance_valid(branch_cards) and tower_level == 3:
		for choice in branch_cards.get_children():
			var option := String(choice.name).trim_prefix("Branch_")
			choice.disabled = remaining > 0.0 or app.game.data.balance < Balance.upgrade_cost(tower, app.game.tuning, option)
	if mode == "info" and upgrade_armed:
		if Balance.upgrade_cost(tower, app.game.tuning, tower_branch) != cost:
			open_action("info")
			return
	rebuild_status.visible = remaining > 0.0
	rebuild_status.text = "Rebuilding · " + Balance.rebuild_time_text(remaining)
	var disabled: bool = (mode in ["preview", "upgrade", "move"] and (app.game.data.balance < cost or remaining > 0.0)) or (mode in ["preview", "upgrade"] and tower_level >= Balance.MAX_TOWER_LEVEL)
	if mode == "info":
		confirm.queue_redraw()
		disabled = tower_level >= 3 or remaining > 0.0 or app.game.data.balance < Balance.upgrade_cost(tower, app.game.tuning, tower_branch)
	if mode in ["equipment", "equipment_detail"]:
		disabled = relic_choice == relic_original
	if disabled != confirm.disabled:
		confirm.disabled = disabled
		UI.trap_focus(card)
	if mode in ["preview", "upgrade"] and tower_level >= Balance.MAX_TOWER_LEVEL:
		confirm.text = "Max level"
	elif mode == "sell":
		refund = app.game.economy.sell_refund(tower)
		confirm.text = "Sell · +" + UI.exact_money(refund + app.game.data.towers[tower_id].earnings) + " gold"

func equipment_fingerprint() -> String:
	var assignments := {}
	for id in app.game.data.towers:
		assignments[id] = app.game.data.towers[id].get("relic", "")
	return JSON.stringify([app.game.data.get("relics", {}), assignments])

func preview_fingerprint() -> String:
	var tower: Dictionary = app.game.data.towers[tower_id]
	return JSON.stringify([Balance.tower_stats(tower, app.game.tuning, app.game.data.relics), Balance.stats(tower.kind, mini(tower_level + 1, Balance.MAX_TOWER_LEVEL), app.game.tuning, tower_branch), Balance.upgrade_cost(tower, app.game.tuning, tower_branch)])

func commit(opened_revision: int) -> void:
	if not visible or opened_revision != revision:
		return
	if mode == "info":
		refresh()
		if not visible or opened_revision != revision:
			return
		if tower_level >= Balance.MAX_TOWER_LEVEL or app.game.data.towers[tower_id].get("rebuild_remaining", 0.0) > 0.0 or (upgrade_armed and app.game.data.balance < cost):
			return
		if not upgrade_armed:
			arm_upgrade()
		elif app.game.economy.upgrade(tower_id, tower_level, tower_branch):
			upgrade_armed = false
			upgraded.emit()
			app.persist()
			open_action("info")
	elif mode == "preview":
		refresh()
		if not visible or revision != opened_revision or confirm.disabled:
			return
		var branch := tower_branch if tower_level == 3 else ""
		if app.game.economy.upgrade(tower_id, tower_level, branch):
			upgraded.emit()
			dismiss(not clear_selection_on_upgrade)
			if clear_selection_on_upgrade:
				app.panels.close_sheet()
			app.persist()
	elif mode in ["equipment", "equipment_detail", "equipment_remove"]:
		var removing := mode == "equipment_remove"
		if app.game.economy.equip_relic(tower_id, "" if removing else relic_choice, relic_original, "" if removing else relic_owner):
			app.field.queue_redraw()
			app.persist()
			open_action("equipment")
		else:
			dismiss()
			app.toast("Equipment changed. Open the equipment slot again.")
	elif mode == "target":
		if app.game.set_tower_target(tower_id, target_choice):
			dismiss()
			app.persist()
	elif mode == "upgrade":
		if app.game.economy.upgrade(tower_id, tower_level):
			upgraded.emit()
			dismiss()
			app.persist()
	elif mode == "sell":
		var result: Dictionary = app.game.economy.sell(tower_id, tower_level)
		if not result.is_empty():
			dismiss(false)
			app.panels.close_sheet()
			app.persist()
			app.collection_effect(result.total)
	elif mode == "move":
		refresh()
		if not visible or confirm.disabled:
			return
		dismiss()
		app.tower_move.begin(tower_id, tower_level, cost, rebuild_seconds)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or mode != "info" or dismissing:
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed or card.get_global_rect().has_point(event.position):
		return
	if _external_button_at(app, event.position):
		# Hide before GUI dispatch so the original press and release reach the button.
		dismiss(false)
		app.panels.close_sheet()

func _external_button_at(node: Node, point: Vector2) -> bool:
	if node == self:
		return false
	if node is Control and not node.is_visible_in_tree():
		return false
	if node is BaseButton and not node.disabled and node.mouse_filter != Control.MOUSE_FILTER_IGNORE and node.get_global_rect().has_point(point):
		return true
	for child in node.get_children():
		if _external_button_at(child, point):
			return true
	return false

func _gui_input(event: InputEvent) -> void:
	if mode != "info" or dismissing:
		return
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if released and not card.get_global_rect().has_point(global_position + event.position):
		accept_event()
		dismissing = true
		app.field.selected_tower_range_visible = false
		app.field.upgrade_range_preview.clear()
		app.field.queue_redraw()
		revision += 1
		dismissal = create_tween()
		dismissal.tween_property(card, "position:y", size.y + card.size.y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		dismissal.tween_callback(func():
			dismiss(false)
			app.panels.close_sheet()
		)

func dismiss(restore_actions: bool = true) -> void:
	app.field.selected_tower_range_visible = false
	app.field.upgrade_range_preview.clear()
	app.field.queue_redraw()
	if dismissal: dismissal.kill()
	dismissing = false
	revision += 1
	hide()
	app.tower_actions.blocked = not restore_actions
	app.tower_actions.refresh()
	if is_instance_valid(cancel):
		cancel.release_focus()
	if restore_actions and is_instance_valid(opener) and opener.is_visible_in_tree():
		opener.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()

func go_back() -> void:
	# System Back follows the same nested equipment route as its visible controls.
	if mode in ["equipment_detail", "equipment_remove"]:
		open_action("equipment")
	elif mode == "info" and upgrade_armed:
		open_action("info")
	elif mode != "info":
		open_action("info")
	else:
		dismiss()
