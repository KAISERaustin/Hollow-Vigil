class_name VigilTowerActions
extends Control

const UI = preload("res://scripts/ui/shared/interface.gd")
const BUTTON_SIZE := Vector2(48, 48)
const ACTION_OFFSETS := {
	"info": Vector2(-78, 0),
	"upgrade": Vector2(0, 78),
	"sell": Vector2(78, 0),
	"move": Vector2(0, -78),
	"target": Vector2(64, -64),
	"equipment": Vector2(-64, -64)
}
signal action_requested(action: String)
signal upgraded
var field: Battlefield
var buttons: Dictionary = {}
var blocked := false
var upgrade_maxed := false
var equipment_kind := ""
var pending_tower := ""
var pending_level := -1
var pending_cost := 0.0
var upgrade_quote: Label
var branch_bar: Control
var chosen_branch := ""

func cancel_upgrade() -> void:
	pending_tower = ""
	pending_level = -1
	chosen_branch = ""
	if is_instance_valid(branch_bar):
		branch_bar.hide()
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
	var relic_kind := preload("res://scripts/gameplay/progression/relics.gd").kind(field.state.data, tower)
	if equipment_kind != relic_kind:
		equipment_kind = relic_kind
		buttons.equipment.queue_redraw()
	buttons.equipment.tooltip_text = "Equipment · " + ("Empty slot" if relic_kind == "" else preload("res://scripts/gameplay/progression/relics.gd").DEFINITIONS[relic_kind].name)
	buttons.equipment.accessibility_name = buttons.equipment.tooltip_text
	var cost := Balance.upgrade_cost(tower, field.state.tuning, chosen_branch)
	if pending_tower != "" and (pending_tower != field.selected_tower or pending_level != int(tower.level) or pending_cost != cost):
		cancel_upgrade()
	var upgrade: Button = buttons.upgrade
	var maxed: bool = tower.level >= 3
	if upgrade_maxed != maxed:
		upgrade_maxed = maxed
		upgrade.queue_redraw()
	upgrade.mouse_default_cursor_shape = Control.CURSOR_ARROW if maxed else Control.CURSOR_POINTING_HAND
	upgrade.disabled = tower.level >= 3 or tower.get("rebuild_remaining", 0.0) > 0.0 or (field.state.data.balance < cost and tower.level != 3)
	upgrade.tooltip_text = ("Confirm upgrade" if pending_tower != "" else "Upgrade") + " · " + UI.exact_money(cost) + " gold"
	if tower.level >= Balance.MAX_TOWER_LEVEL:
		upgrade.tooltip_text = "Max level"
	elif tower.level == 3:
		upgrade.tooltip_text = "Choose the left or right specialization · See info for details"
	elif tower.get("rebuild_remaining", 0.0) > 0.0:
		upgrade.tooltip_text = "Rebuilding"
	upgrade.accessibility_name = upgrade.tooltip_text
	upgrade_quote.visible = pending_tower != ""
	refresh_branches(tower)
	if upgrade_quote.visible:
		upgrade_quote.text = "Upgrade to level %d · %s gold\nTap the checkmark to confirm." % [pending_level + 1, UI.exact_money(pending_cost)]
		if pending_level == 3:
			upgrade_quote.text = "%s · %s gold\nTap the checkmark to confirm." % [Balance.BRANCHES[tower.kind][chosen_branch].name, UI.exact_money(pending_cost)]
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
	if action == "equipment":
		if equipment_kind != "":
			preload("res://scripts/rendering/actors/relic_art.gd").draw(button, equipment_kind, center)
		else:
			button.draw_polyline(PackedVector2Array([center + Vector2(0,-13), center + Vector2(11,0), center + Vector2(0,13), center + Vector2(-11,0), center + Vector2(0,-13)]), color, 2, true)
			button.draw_line(center + Vector2(-5,0), center + Vector2(5,0), color, 2, true)
			button.draw_line(center + Vector2(0,-5), center + Vector2(0,5), color, 2, true)
	elif action == "info":
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
	branch_bar = Control.new()
	branch_bar.name = "BranchChoices"
	branch_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(branch_bar)
	for index in range(2):
		var button := UI.accent_button("", choose_branch.bind(index), UI.GOLD)
		button.name = "LeftBranch" if index == 0 else "RightBranch"
		button.custom_minimum_size = BUTTON_SIZE
		button.size = BUTTON_SIZE
		button.draw.connect(func():
			var center := button.size * 0.5
			if button.get_meta("armed", false):
				button.draw_polyline(PackedVector2Array([center + Vector2(-10, 0), center + Vector2(-3, 7), center + Vector2(11, -8)]), UI.TEXT, 3, true)
			else:
				var direction := -1 if index == 0 else 1
				button.draw_line(center - Vector2(10 * direction, 0), center + Vector2(10 * direction, 0), UI.TEXT, 3, true)
				button.draw_polyline(PackedVector2Array([center + Vector2(2 * direction, -8), center + Vector2(10 * direction, 0), center + Vector2(2 * direction, 8)]), UI.TEXT, 3, true)
		)
		branch_bar.add_child(button)
	branch_bar.hide()

func choose_branch(index: int) -> void:
	refresh()
	if not visible or not branch_bar.visible or index < 0 or index > 1:
		return
	var button: Button = branch_bar.get_child(index)
	if button.disabled:
		return
	var id := field.selected_tower
	var tower: Dictionary = field.state.data.towers[id]
	var branch: String = Balance.BRANCHES[tower.kind].keys()[index]
	if pending_tower == id and chosen_branch == branch:
		cancel_upgrade()
		if field.state.economy.upgrade(id, 3, branch):
			upgraded.emit()
	else:
		pending_tower = id
		pending_level = 3
		pending_cost = Balance.upgrade_cost(tower, field.state.tuning, branch)
		chosen_branch = branch
	refresh()

func refresh_branches(tower: Dictionary) -> void:
	branch_bar.visible = int(tower.level) == 3
	if not branch_bar.visible:
		return
	var center := field.screen(VigilWorld.pad_position(tower.region, tower.pad))
	var options: Array = Balance.BRANCHES[tower.kind].keys()
	for index in range(2):
		var button: Button = branch_bar.get_child(index)
		var option: Dictionary = Balance.BRANCHES[tower.kind][options[index]]
		var armed: bool = pending_tower == field.selected_tower and chosen_branch == options[index]
		button.set_meta("armed", armed)
		button.queue_redraw()
		button.scale = Vector2.ONE * field.zoom
		button.position = center + (Vector2(-64 if index == 0 else 64, 78) - BUTTON_SIZE * 0.5) * field.zoom
		button.disabled = field.state.data.balance < Balance.upgrade_cost(tower, field.state.tuning, options[index]) or tower.get("rebuild_remaining", 0.0) > 0.0
		button.tooltip_text = ("Confirm " if armed else ("Left: " if index == 0 else "Right: ")) + option.name + " · " + UI.exact_money(Balance.upgrade_cost(tower, field.state.tuning, options[index])) + " gold"
		button.accessibility_name = button.tooltip_text
