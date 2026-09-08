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

func _ready() -> void:
	name = "TowerDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(UI.BORDER, 0.65)
	mouse_filter = Control.MOUSE_FILTER_STOP
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, 0))
	add_child(card)
	layout = UI.margin(card, UI.SCREEN_PADDING)
	layout.add_theme_constant_override("separation", 16)
	identity = HBoxContainer.new()
	identity.add_theme_constant_override("separation", 12)
	layout.add_child(identity)
	header_back = UI.back_button("Back to equipment", func(): open_action("equipment"))
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
			VigilTerrainArt.sentinel_portrait(portrait, tower_kind, Vector2(20, 41) if mode == "preview" else Vector2(24, 51), 0.65 if mode == "preview" else 0.85, Rect2(Vector2.ZERO, portrait.size).grow(-2), shown_level, tower_branch)
	)
	identity.add_child(portrait)
	heading = UI.heading("", 24)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(heading)
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

func open_action(action: String, branch: String = "") -> void:
	if action == "upgrade":
		if visible:
			dismiss()
		app.tower_actions.request_upgrade()
		return
	app.tower_actions.cancel_upgrade()
	var id: String = app.field.selected_tower
	if not action in ["info", "preview", "upgrade", "sell", "move", "target", "equipment"] or not app.game.data.towers.has(id):
		return
	opener = get_viewport().gui_get_focus_owner()
	revision += 1
	mode = action
	layout.add_theme_constant_override("separation", 8 if action == "preview" else 16)
	body.add_theme_constant_override("separation", 8 if action == "preview" else 12)
	portrait.custom_minimum_size = Vector2(40, 48) if action == "preview" else Vector2(48, 64)
	header_back.hide()
	header_close.visible = action in ["equipment", "preview"]
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
	if action not in ["equipment", "preview"]:
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
		body.add_child(UI.paragraph("Choose an empty socket in any owned territory. Tapping it pays the cost and starts rebuilding. Your tower keeps its level and stored gold, but cannot fire, upgrade, or move again until ready. Rebuilding continues while you are away.", 14))
	if action == "upgrade":
		var progression := "Maximum level reached · %d / %d" % [tower_level, Balance.MAX_TOWER_LEVEL] if tower_level >= Balance.MAX_TOWER_LEVEL else "Level %d → %d / %d" % [tower_level, tower_level + 1, Balance.MAX_TOWER_LEVEL]
		body.add_child(UI.label(progression, 14))
	if action == "info":
		body.add_child(UI.paragraph(Balance.tower_description(stats), 14))
		var relic_kind := preload("res://scripts/gameplay/progression/relics.gd").kind(app.game.data, tower)
		body.add_child(UI.heading("Equipment", 18))
		body.add_child(UI.paragraph("Empty slot · Defeat bosses to collect relics." if relic_kind == "" else preload("res://scripts/gameplay/progression/relics.gd").DEFINITIONS[relic_kind].name + "\n" + preload("res://scripts/gameplay/progression/relics.gd").description(relic_kind, app.game.tuning), 14))
		if tower_level == 3:
			body.add_child(UI.heading("Level 4 specializations", 18))
			var instructions := "Open Upgrade, choose a specialization to compare its stats and cost, then press Upgrade to purchase that permanent specialization." if app.tower_actions.upgrade_in_dialog else "At level 3, the upgrade button locks and two choices appear beside it. Tap a side once, then tap its checkmark to purchase that permanent specialization."
			body.add_child(UI.paragraph(instructions, 14))
			var branch_options: Array = Balance.BRANCHES[tower.kind].keys()
			for side in range(branch_options.size()):
				var option := Balance.stats(tower.kind, 4, app.game.tuning, branch_options[side])
				body.add_child(UI.heading(("Left · " if side == 0 else "Right · ") + option.name, 16))
				body.add_child(UI.paragraph(Balance.tower_description(option), 14))
		var next := Balance.equipment_stats(Balance.stats(tower.kind, mini(tower_level + 1, Balance.MAX_TOWER_LEVEL), app.game.tuning), tower, app.game.tuning, app.game.data.relics)
		var grid := GridContainer.new()
		grid.name = "TowerStats"
		grid.columns = 2
		grid.resized.connect(func(): grid.columns = 1 if card.size.x < 400 * UI.text_scale else 2)
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 12)
		body.add_child(grid)
		stat(grid, "Damage / hit", stats.damage, next.damage)
		stat(grid, "Fire rate / sec", 1.0 / stats.period, 1.0 / next.period, 2)
		stat(grid, "Base DPS / target", stats.damage / stats.period, next.damage / next.period)
		stat(grid, "Range", stats.range, next.range, 0)
		if stats.has("targets"):
			stat(grid, "Targets per pulse", stats.targets, next.targets, 0)
		stat(grid, "Attack interval", stats.period, next.period, 2, "s")
		if stats.splash > 0:
			stat(grid, "Blast radius", stats.splash, next.splash, 0)
	var opened_revision := revision
	scroll.scroll_vertical = 0
	cancel = UI.button("Cancel", dismiss, 48)
	cancel.name = "CancelTowerAction"
	cancel.custom_minimum_size.x = 92
	cancel.size_flags_horizontal = Control.SIZE_FILL
	footer.add_child(cancel)
	var text: String = {"info": "Close", "preview": "Upgrade · " + UI.exact_money(cost) + " gold", "upgrade": "Upgrade · " + UI.exact_money(cost) + " gold", "sell": "Sell · +" + UI.exact_money(refund) + " gold", "move": "Choose destination", "target": "Apply targeting", "equipment": "Apply equipment"}[action]
	confirm = UI.accent_button(text, func(): commit(opened_revision), UI.DANGER if action == "sell" else (UI.SURFACE if action == "info" else UI.GOLD), 48)
	confirm.name = "ConfirmTowerAction"
	confirm.add_theme_font_size_override("font_size", UI.type_size(16))
	footer.add_child(confirm)
	if action == "equipment":
		confirm.hide()
		cancel.text = "Close"
		footer.hide()
	app.tower_actions.blocked = true
	app.tower_actions.refresh()
	show()
	refresh()
	call_deferred("fit_dialog")
	cancel.visible = action not in ["info", "preview"]
	(header_close if action in ["equipment", "preview"] else (confirm if action == "info" else cancel)).grab_focus()
	UI.trap_focus(card)

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
	if not visible:
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
	scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, maxf(40.0, height_limit - chrome))
	card.size.y = 0.0
	card.position = safe.position + (safe.size - card.size) * 0.5

func refresh() -> void:
	if not visible:
		return
	if (mode.begins_with("equipment") or mode == "preview") and app.field.selected_tower != tower_id:
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
	rebuild_status.visible = remaining > 0.0
	rebuild_status.text = "Rebuilding · " + Balance.rebuild_time_text(remaining)
	var disabled: bool = (mode in ["preview", "upgrade", "move"] and (app.game.data.balance < cost or remaining > 0.0)) or (mode in ["preview", "upgrade"] and tower_level >= Balance.MAX_TOWER_LEVEL)
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
		dismiss()
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

func dismiss(restore_actions: bool = true) -> void:
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
	else:
		dismiss()
