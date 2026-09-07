class_name VigilTowerDialog
extends ColorRect

const UI = preload("res://scripts/ui/shared/interface.gd")
## Active mode host: game, field, controls, persistence and feedback.
var app: Control
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

func _ready() -> void:
	name = "TowerDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(UI.BORDER, 0.65)
	mouse_filter = Control.MOUSE_FILTER_STOP
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 4, 0))
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
			preload("res://scripts/rendering/actors/relic_art.gd").draw(portrait, app.game.data.relics[relic_choice], portrait.size * 0.5)
		else:
			VigilTerrainArt.sentinel(portrait, tower_kind, Vector2(24, 51), 0.85, tower_level, tower_branch)
	)
	identity.add_child(portrait)
	heading = UI.heading("", 24)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(heading)
	header_close = UI.close_button(func():
		if mode == "equipment_detail": open_action("equipment")
		else: dismiss()
	, 44)
	header_close.name = "CloseEquipment"
	header_close.accessibility_description = "Close"
	header_close.custom_minimum_size.x = 44
	header_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	header_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(header_close)
	header_divider = ColorRect.new()
	header_divider.color = UI.BORDER
	header_divider.custom_minimum_size.y = 2
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

func open_action(action: String) -> void:
	if action == "upgrade":
		app.tower_actions.request_upgrade()
		return
	app.tower_actions.cancel_upgrade()
	var id: String = app.field.selected_tower
	if not action in ["info", "upgrade", "sell", "move", "target", "equipment"] or not app.game.data.towers.has(id):
		return
	opener = get_viewport().gui_get_focus_owner()
	revision += 1
	mode = action
	header_back.hide()
	header_close.visible = action == "equipment"
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
	refund = app.game.economy.sell_refund(tower) if action == "sell" else 0.0
	if action == "move":
		cost = Balance.move_cost(tower, app.game.tuning)
	rebuild_seconds = Balance.rebuild_seconds(tower, app.game.tuning)
	for parent in [body, footer, equipment_summary]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	equipment_summary.visible = action == "equipment"
	var stats := Balance.tower_stats(tower, app.game.tuning)
	heading.text = stats.name
	var label := {"info": "Tower information · Level %d", "upgrade": "Upgrade · Level %d", "sell": "Sell tower · Level %d", "move": "Move tower · Level %d", "target": "Targeting · Level %d", "equipment": "Equipment · Level %d"}
	if action != "equipment":
		body.add_child(UI.label(label[action] % tower_level, 14))
	rebuild_status = UI.label("", 14, UI.TEXT)
	body.add_child(rebuild_status)
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
		body.add_child(UI.heading("Level 4 specializations", 18))
		body.add_child(UI.paragraph("At level 3, the upgrade button locks and two choices appear beside it. Tap a side once, then tap its checkmark to purchase that permanent specialization.", 14))
		var branch_options: Array = Balance.BRANCHES[tower.kind].keys()
		for side in range(branch_options.size()):
			var option := Balance.stats(tower.kind, 4, app.game.tuning, branch_options[side])
			body.add_child(UI.heading(("Left · " if side == 0 else "Right · ") + option.name, 16))
			body.add_child(UI.paragraph(Balance.tower_description(option), 14))
		var next := Balance.stats(tower.kind, mini(tower_level + 1, Balance.MAX_TOWER_LEVEL), app.game.tuning)
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
	var text: String = {"info": "Close", "upgrade": "Upgrade · " + UI.exact_money(cost) + " gold", "sell": "Sell · +" + UI.exact_money(refund) + " gold", "move": "Choose destination", "target": "Apply targeting", "equipment": "Apply equipment"}[action]
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
	cancel.visible = action != "info"
	(header_close if action == "equipment" else (confirm if action == "info" else cancel)).grab_focus()
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
	if mode.begins_with("equipment") and app.field.selected_tower != tower_id:
		dismiss(false)
		return
	if not app.game.data.towers.has(tower_id) or app.game.data.towers[tower_id].level != tower_level:
		dismiss()
		return
	var tower: Dictionary = app.game.data.towers[tower_id]
	if mode.begins_with("equipment") and equipment_state != equipment_fingerprint():
		open_action("equipment")
		return
	var remaining: float = tower.get("rebuild_remaining", 0.0)
	rebuild_status.visible = remaining > 0.0
	rebuild_status.text = "Rebuilding · " + Balance.rebuild_time_text(remaining)
	var disabled: bool = (mode in ["upgrade", "move"] and (app.game.data.balance < cost or remaining > 0.0)) or (mode == "upgrade" and tower_level >= Balance.MAX_TOWER_LEVEL)
	if mode in ["equipment", "equipment_detail"]:
		disabled = relic_choice == relic_original
	if disabled != confirm.disabled:
		confirm.disabled = disabled
		UI.trap_focus(card)
	if mode == "upgrade" and tower_level >= Balance.MAX_TOWER_LEVEL:
		confirm.text = "Max level"
	elif mode == "sell":
		refund = app.game.economy.sell_refund(tower)
		confirm.text = "Sell · +" + UI.exact_money(refund + app.game.data.towers[tower_id].earnings) + " gold"

func equipment_fingerprint() -> String:
	var assignments := {}
	for id in app.game.data.towers:
		assignments[id] = app.game.data.towers[id].get("relic", "")
	return JSON.stringify([app.game.data.get("relics", {}), assignments])

func commit(opened_revision: int) -> void:
	if not visible or opened_revision != revision:
		return
	if mode == "info":
		dismiss()
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
		dismiss()
		get_viewport().set_input_as_handled()
