class_name VigilTowerActions
extends Control

const UI = preload("res://scripts/ui/interface.gd")
const BUTTON_SIZE := Vector2(48, 48)
const ACTION_OFFSETS := {
	"info": Vector2(-78, 0),
	"upgrade": Vector2(0, 78),
	"sell": Vector2(78, 0),
	"move": Vector2(0, -78),
	"target": Vector2(64, -64)
}
signal action_requested(action: String)
signal upgraded
var field: Battlefield
var buttons: Dictionary = {}
var blocked := false
var upgrade_maxed := false
var pending_tower := ""
var pending_level := -1
var pending_cost := 0.0
var upgrade_quote: Label
var branch_bar: HBoxContainer
var branch_card: PanelContainer
var branch_description: Label
var branch_scroll: ScrollContainer
var branch_confirm: Button
var branch_title: Label
var branch_portrait: Control
var chosen_branch := ""
var branch_kind := "rapid"

func cancel_upgrade() -> void:
	pending_tower = ""
	pending_level = -1
	chosen_branch = ""
	if is_instance_valid(branch_bar):
		branch_bar.hide()
		branch_card.hide()
	if is_instance_valid(upgrade_quote):
		upgrade_quote.hide()
	if buttons.has("upgrade"):
		buttons.upgrade.queue_redraw()

func request_upgrade() -> void:
	refresh()
	if not visible or buttons.upgrade.disabled:
		return
	var id := field.selected_tower
	var tower: Dictionary = field.state.data.towers[id]
	if pending_tower == id and tower.level == 3:
		cancel_upgrade()
		return
	if pending_tower == id:
		var level := pending_level
		cancel_upgrade()
		if field.state.economy.upgrade(id, level):
			upgraded.emit()
	else:
		pending_tower = id
		pending_level = int(tower.level)
		pending_cost = Balance.upgrade_cost(tower, field.state.tuning)
	refresh()
	buttons.upgrade.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if pending_tower != "" and event.is_action_pressed("ui_cancel"):
		cancel_upgrade()
		refresh()
		get_viewport().set_input_as_handled()

func _ready() -> void:
	field.tower_selection_changed.connect(cancel_upgrade)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_quote = UI.paragraph("", 14)
	upgrade_quote.name = "UpgradeQuote"
	upgrade_quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_quote.add_theme_stylebox_override("normal", UI.surface(UI.PANEL, 2, 12))
	add_child(upgrade_quote)
	upgrade_quote.hide()
	for action in ACTION_OFFSETS:
		var button := UI.accent_button("", func(): action_requested.emit(action), UI.GOLD if action == "upgrade" else UI.SURFACE)
		button.size = BUTTON_SIZE
		button.tooltip_text = action.capitalize()
		button.accessibility_name = action.capitalize() + " tower"
		button.name = "Tower" + action.capitalize()
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed", "focus"]:
			var color := UI.GOLD if action == "upgrade" else UI.SURFACE
			var style := UI.focus_box() if state == "focus" else UI.box(color)
			style.set_content_margin_all(0)
			button.add_theme_stylebox_override(state, style)
		button.draw.connect(draw_icon.bind(button, action))
		add_child(button)
		buttons[action] = button
	build_branches()
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	visible = not blocked and field.state.data.towers.has(field.selected_tower)
	if not visible:
		cancel_upgrade()
		return
	var tower: Dictionary = field.state.data.towers[field.selected_tower]
	var cost := Balance.upgrade_cost(tower, field.state.tuning)
	if pending_tower != "" and (pending_tower != field.selected_tower or pending_level != int(tower.level) or pending_cost != cost):
		cancel_upgrade()
	var upgrade: Button = buttons.upgrade
	var maxed: bool = tower.level >= Balance.MAX_TOWER_LEVEL
	if upgrade_maxed != maxed:
		upgrade_maxed = maxed
		upgrade.queue_redraw()
	upgrade.mouse_default_cursor_shape = Control.CURSOR_ARROW if maxed else Control.CURSOR_POINTING_HAND
	upgrade.disabled = tower.level >= Balance.MAX_TOWER_LEVEL or tower.get("rebuild_remaining", 0.0) > 0.0 or (field.state.data.balance < cost and tower.level != 3)
	upgrade.tooltip_text = ("Confirm upgrade" if pending_tower != "" else "Upgrade") + " · " + UI.exact_money(cost) + " gold"
	if tower.level >= Balance.MAX_TOWER_LEVEL:
		upgrade.tooltip_text = "Max level"
	elif tower.get("rebuild_remaining", 0.0) > 0.0:
		upgrade.tooltip_text = "Rebuilding"
	upgrade.accessibility_name = upgrade.tooltip_text
	upgrade_quote.visible = pending_tower != "" and pending_level != 3
	refresh_branches(tower)
	if upgrade_quote.visible:
		upgrade_quote.text = "Upgrade to level %d · %s gold\nTap the checkmark to confirm." % [pending_level + 1, UI.exact_money(pending_cost)]
		upgrade_quote.size.x = maxf(1.0, field.size.x - 24.0)
		upgrade_quote.size.y = upgrade_quote.get_combined_minimum_size().y
		upgrade_quote.position = Vector2(12, field.size.y - upgrade_quote.size.y - 12)
	var center := field.screen(VigilWorld.pad_position(tower.region, tower.pad))
	if not Rect2(Vector2.ZERO, field.size).has_point(center):
		hide()
		return
	# Keep the entire control cluster fixed to the tower in map space.
	for action in ACTION_OFFSETS:
		var button: Button = buttons[action]
		button.scale = Vector2.ONE * field.zoom
		button.position = center + (ACTION_OFFSETS[action] - BUTTON_SIZE * 0.5) * field.zoom

func draw_icon(button: Button, action: String) -> void:
	var center := button.size * 0.5
	var color := UI.TEXT
	if action == "info":
		button.draw_arc(center, 11, 0, TAU, 40, color, 3, true)
		button.draw_circle(center + Vector2(0, -5), 2, color)
		button.draw_line(center + Vector2(0, -1), center + Vector2(0, 6), color, 3, true)
	elif action == "upgrade":
		if upgrade_maxed:
			button.draw_arc(center + Vector2(0, -4), 7, PI, TAU, 24, UI.MUTED, 3, true)
			button.draw_rect(Rect2(center + Vector2(-10, -4), Vector2(20, 17)), UI.MUTED)
			button.draw_circle(center + Vector2(0, 2), 2, UI.PANEL)
			button.draw_line(center + Vector2(0, 3), center + Vector2(0, 7), UI.PANEL, 2, true)
			return
		if pending_tower != "":
			button.draw_polyline(PackedVector2Array([center + Vector2(-10, 0), center + Vector2(-3, 7), center + Vector2(11, -8)]), color, 3, true)
			return
		for y in [-3, 5]:
			button.draw_polyline(PackedVector2Array([center + Vector2(-9, y + 3), center + Vector2(0, y - 5), center + Vector2(9, y + 3)]), color, 3, true)
	elif action == "target":
		button.draw_arc(center, 10, 0, TAU, 40, color, 2, true)
		button.draw_circle(center, 3, color)
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			button.draw_line(center + direction * 7, center + direction * 15, color, 2, true)
	elif action == "move":
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			var tip: Vector2 = center + direction * 12
			var side: Vector2 = direction.orthogonal() * 4
			button.draw_line(center, tip, color, 2, true)
			button.draw_polyline(PackedVector2Array([tip - direction * 5 + side, tip, tip - direction * 5 - side]), color, 2, true)
	else:
		button.draw_arc(center, 11, 0, TAU, 40, color, 3, true)
		button.draw_line(center + Vector2(-5, 0), center + Vector2(5, 0), color, 3, true)

func build_branches() -> void:
	branch_bar = HBoxContainer.new()
	branch_bar.name = "BranchChoices"
	branch_bar.add_theme_constant_override("separation", 10)
	add_child(branch_bar)
	for index in range(2):
		var button := UI.accent_button("", choose_branch.bind(index), UI.SURFACE)
		button.name = "LeftBranch" if index == 0 else "RightBranch"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		branch_bar.add_child(button)
	branch_card = PanelContainer.new()
	branch_card.name = "BranchDetails"
	branch_card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 3, 12))
	add_child(branch_card)
	var content := UI.margin(branch_card, 12)
	var identity := HBoxContainer.new()
	content.add_child(identity)
	branch_portrait = Control.new()
	branch_portrait.custom_minimum_size = Vector2(64, 78)
	branch_portrait.draw.connect(func(): VigilTerrainArt.sentinel(branch_portrait, branch_kind, Vector2(32, 63), 0.9, 4, chosen_branch))
	identity.add_child(branch_portrait)
	branch_title = UI.heading("", 20)
	branch_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	branch_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(branch_title)
	branch_scroll = ScrollContainer.new()
	branch_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.keyboard_scroll(branch_scroll, "Branch power description")
	content.add_child(branch_scroll)
	branch_description = UI.paragraph("", 14)
	branch_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branch_scroll.add_child(branch_description)
	branch_confirm = UI.accent_button("", confirm_branch, UI.GOLD)
	branch_confirm.name = "ConfirmBranch"
	content.add_child(branch_confirm)
	branch_bar.hide()
	branch_card.hide()

func choose_branch(index: int) -> void:
	if pending_tower == "" or not field.state.data.towers.has(pending_tower):
		return
	var tower: Dictionary = field.state.data.towers[pending_tower]
	branch_kind = tower.kind
	chosen_branch = Balance.BRANCHES[tower.kind].keys()[index]
	branch_portrait.queue_redraw()
	branch_scroll.scroll_vertical = 0
	refresh()

func confirm_branch() -> void:
	var id := pending_tower
	var branch := chosen_branch
	if id == "" or branch == "":
		return
	if field.state.economy.upgrade(id, 3, branch):
		cancel_upgrade()
		upgraded.emit()
	refresh()

func refresh_branches(tower: Dictionary) -> void:
	if not is_instance_valid(branch_bar):
		return
	branch_bar.visible = pending_tower != "" and pending_level == 3
	branch_card.visible = branch_bar.visible and chosen_branch != ""
	if not branch_bar.visible:
		return
	var width := minf(440.0, field.size.x - 24.0)
	branch_bar.size = Vector2(width, 52)
	branch_bar.position = Vector2((field.size.x - width) * 0.5, field.size.y - 64)
	var options: Array = Balance.BRANCHES[tower.kind].values()
	for index in range(2):
		var button: Button = branch_bar.get_child(index)
		button.text = options[index].name
		button.accessibility_name = "Preview " + options[index].name
	if not branch_card.visible:
		return
	var option: Dictionary = Balance.BRANCHES[tower.kind][chosen_branch]
	branch_title.text = option.name
	branch_description.text = option.description + "\n\nPermanent specialization · Level 4"
	branch_confirm.text = "Choose %s · %s gold" % [option.name, UI.exact_money(pending_cost)]
	branch_confirm.add_theme_font_size_override("font_size", 14)
	branch_confirm.disabled = field.state.data.balance < pending_cost or tower.get("rebuild_remaining", 0.0) > 0.0
	branch_scroll.custom_minimum_size.y = clampf(field.size.y - 290.0, 44.0, 160.0)
	branch_card.size = Vector2(width, 0)
	branch_card.position = Vector2(branch_bar.position.x, branch_bar.position.y - branch_card.size.y - 10)
