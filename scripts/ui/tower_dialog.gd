class_name VigilTowerDialog
extends ColorRect

const UI = preload("res://scripts/ui/interface.gd")
var app: VigilApp
var card: PanelContainer
var layout: VBoxContainer
var body: VBoxContainer
var scroll: ScrollContainer
var footer: BoxContainer
var heading: Label
var identity: HBoxContainer
var portrait: Control
var tower_kind := "rapid"
var confirm: Button
var cancel: Button
var balance_preview: Label
var earnings_preview: Label
var opener: Control
var mode := ""
var tower_id := ""
var tower_level := 0
var revision := 0
var cost := 0.0
var refund := 0.0

func _ready() -> void:
	name = "TowerDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(UI.BORDER, 0.65)
	mouse_filter = Control.MOUSE_FILTER_STOP
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 4, 0))
	add_child(card)
	layout = UI.margin(card, 16)
	layout.add_theme_constant_override("separation", 16)
	identity = HBoxContainer.new()
	identity.add_theme_constant_override("separation", 12)
	layout.add_child(identity)
	portrait = Control.new()
	portrait.custom_minimum_size = Vector2(48, 64)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.draw.connect(func(): VigilTerrainArt.sentinel(portrait, tower_kind, Vector2(24, 46), 0.9))
	identity.add_child(portrait)
	heading = UI.heading("", 24)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(heading)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	var id: String = app.field.selected_tower
	if not action in ["info", "upgrade", "sell"] or not app.game.data.towers.has(id):
		return
	opener = get_viewport().gui_get_focus_owner()
	revision += 1
	mode = action
	tower_id = id
	var tower: Dictionary = app.game.data.towers[id]
	tower_kind = tower.kind
	portrait.queue_redraw()
	tower_level = int(tower.level)
	cost = Balance.upgrade_cost(tower) if action == "upgrade" else 0.0
	refund = Balance.sell_refund(tower) if action == "sell" else 0.0
	balance_preview = null
	earnings_preview = null
	for parent in [body, footer]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	var stats := Balance.stats(tower.kind, tower_level)
	heading.text = stats.name
	var label := {"info": "Tower information · Level %d", "upgrade": "Upgrade · Level %d", "sell": "Sell tower · Level %d"}
	body.add_child(UI.label(label[action] % tower_level, 14))
	if action == "sell":
		body.add_child(UI.paragraph("Remove this tower and free its socket for a new defense.", 14))
		body.add_child(UI.heading("Sale refund   +" + UI.exact_money(refund) + " gold", 18))
		body.add_child(UI.paragraph("50% of its build and upgrade costs. All stored gold is collected when you confirm.", 13))
		earnings_preview = UI.paragraph("", 14)
		body.add_child(earnings_preview)
	else:
		if action == "info":
			body.add_child(UI.paragraph(stats.description, 14))
		else:
			body.add_child(UI.label("Current → Next · Level " + str(mini(tower_level + 1, Balance.MAX_TOWER_LEVEL)), 14, UI.MUTED))
		var next := Balance.stats(tower.kind, mini(tower_level + 1, Balance.MAX_TOWER_LEVEL))
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
		stat(grid, "Attack interval", stats.period, next.period, 2, "s")
		if stats.splash > 0:
			stat(grid, "Blast radius", stats.splash, next.splash, 0)
	if action == "info":
		body.add_child(UI.paragraph("Close returns to the tower controls. No gold is spent.", 13))
	else:
		balance_preview = UI.paragraph("", 14)
		body.add_child(balance_preview)
		body.add_child(UI.paragraph("Cancel keeps your tower and gold unchanged.", 13))
	var opened_revision := revision
	cancel = UI.button("Cancel", dismiss, 48)
	cancel.name = "CancelTowerAction"
	cancel.custom_minimum_size.x = 92
	cancel.size_flags_horizontal = Control.SIZE_FILL
	footer.add_child(cancel)
	var text: String = {"info": "Close", "upgrade": "Upgrade · " + UI.exact_money(cost) + " gold", "sell": "Sell tower"}[action]
	confirm = UI.accent_button(text, func(): commit(opened_revision), UI.DANGER if action == "sell" else (UI.SURFACE if action == "info" else UI.GOLD), 48)
	confirm.name = "ConfirmTowerAction"
	confirm.add_theme_font_size_override("font_size", UI.type_size(16))
	footer.add_child(confirm)
	app.tower_actions.blocked = true
	app.tower_actions.refresh()
	show()
	refresh()
	call_deferred("fit_dialog")
	cancel.visible = action != "info"
	(confirm if action == "info" else cancel).grab_focus()
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
	var chrome: float = identity.get_combined_minimum_size().y + footer.get_combined_minimum_size().y + 64.0
	scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, maxf(40.0, safe.size.y - chrome))
	card.size.y = 0.0
	card.position = safe.position + (safe.size - card.size) * 0.5

func refresh() -> void:
	if not visible:
		return
	if not app.game.data.towers.has(tower_id) or app.game.data.towers[tower_id].level != tower_level:
		dismiss()
		return
	var disabled: bool = mode == "upgrade" and (app.game.data.balance < cost or tower_level >= Balance.MAX_TOWER_LEVEL)
	if disabled != confirm.disabled:
		confirm.disabled = disabled
		UI.trap_focus(card)
	if mode == "upgrade":
		balance_preview.text = "Gold after upgrade: " + Balance.money(maxf(0, app.game.data.balance - cost))
		if tower_level >= Balance.MAX_TOWER_LEVEL:
			balance_preview.text = "This tower is at its maximum level."
		elif app.game.data.balance < cost:
			balance_preview.text = "You need " + Balance.money(cost - app.game.data.balance) + " more gold for this upgrade."
	elif mode == "sell":
		var earnings: float = app.game.data.towers[tower_id].earnings
		earnings_preview.text = "Stored gold   +" + Balance.money(earnings) + " gold"
		balance_preview.text = "Gold after sale: " + Balance.money(minf(Balance.MAX_MONEY, app.game.data.balance + refund + earnings))

func commit(opened_revision: int) -> void:
	if not visible or opened_revision != revision:
		return
	if mode == "info":
		dismiss()
	elif mode == "upgrade":
		if app.game.economy.upgrade(tower_id, tower_level):
			dismiss()
			app.persist()
			app.toast("Tower upgraded to level " + str(tower_level + 1) + ".")
	elif mode == "sell":
		var result: Dictionary = app.game.economy.sell(tower_id, tower_level)
		if not result.is_empty():
			dismiss(false)
			app.panels.close_sheet()
			app.persist()
			app.collection_effect(result.total)
			app.toast("Tower sold. Its socket is ready to build again.")

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
