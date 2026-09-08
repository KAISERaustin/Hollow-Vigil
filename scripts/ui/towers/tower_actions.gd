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
## Hosts can use the shared stat preview instead of inline upgrade confirmation.
var upgrade_in_dialog := false
var upgrade_maxed := false
var equipment_kind := ""
var pending_tower := ""
var pending_level := -1
var pending_cost := 0.0
var upgrade_quote: Label
var branch_bar: Control
var chosen_branch := ""
var framing_signature: Array = []

func reset_framing() -> void:
	framing_signature.clear()
	field.camera_framing.cancel()

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
	if upgrade_in_dialog:
		action_requested.emit("preview")
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
	field.tower_selection_changed.connect(reset_framing)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_quote = UI.paragraph("", 14)
	upgrade_quote.name = "UpgradeQuote"
	upgrade_quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_quote.add_theme_stylebox_override("normal", UI.surface(UI.PANEL, UI.OUTLINE, 12))
	add_child(upgrade_quote)
	upgrade_quote.hide()
	for action in ACTION_OFFSETS:
		var button := UI.accent_button("", func(): action_requested.emit(action), UI.GOLD if action == "upgrade" else UI.SURFACE)
		button.size = BUTTON_SIZE
		button.accessibility_description = action.capitalize()
		button.accessibility_name = action.capitalize() + " tower"
		button.name = "Tower" + action.capitalize()
		button.focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
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
	visible = false # Controls now live in the shared tower information menu.
	if not visible:
		cancel_upgrade()
		if not framing_signature.is_empty():
			reset_framing()
		return
	var tower: Dictionary = field.state.data.towers[field.selected_tower]
	var relic_kind := preload("res://scripts/gameplay/progression/relics.gd").kind(field.state.data, tower)
	if equipment_kind != relic_kind:
		equipment_kind = relic_kind
		buttons.equipment.queue_redraw()
	buttons.equipment.accessibility_description = "Equipment · " + ("Empty slot" if relic_kind == "" else preload("res://scripts/gameplay/progression/relics.gd").DEFINITIONS[relic_kind].name)
	buttons.equipment.accessibility_name = buttons.equipment.accessibility_description
	var cost := Balance.upgrade_cost(tower, field.state.tuning, chosen_branch)
	if pending_tower != "" and (pending_tower != field.selected_tower or pending_level != int(tower.level) or pending_cost != cost):
		cancel_upgrade()
	var upgrade: Button = buttons.upgrade
	var maxed: bool = tower.level >= (Balance.MAX_TOWER_LEVEL if upgrade_in_dialog else 3)
	if upgrade_maxed != maxed:
		upgrade_maxed = maxed
		upgrade.queue_redraw()
	upgrade.disabled = maxed or (not upgrade_in_dialog and (tower.get("rebuild_remaining", 0.0) > 0.0 or field.state.data.balance < cost))
	upgrade.accessibility_description = ("Confirm upgrade" if pending_tower != "" else "Upgrade") + " · " + UI.exact_money(cost) + " gold"
	if tower.level >= Balance.MAX_TOWER_LEVEL:
		upgrade.accessibility_description = "Max level"
	elif tower.level == 3:
		upgrade.accessibility_description = "Preview level 4 specializations" if upgrade_in_dialog else "Choose the left or right specialization · See info for details"
	elif tower.get("rebuild_remaining", 0.0) > 0.0:
		upgrade.accessibility_description = "Rebuilding"
	upgrade.accessibility_name = upgrade.accessibility_description
	upgrade_quote.visible = not upgrade_in_dialog and tower.level < Balance.MAX_TOWER_LEVEL
	refresh_branches(tower)
	if upgrade_quote.visible:
		if pending_tower != "":
			upgrade_quote.text = "Upgrade to level %d · %s gold\nTap the checkmark to confirm." % [pending_level + 1, UI.exact_money(pending_cost)]
			if pending_level == 3:
				upgrade_quote.text = "%s · %s gold\nTap the checkmark to confirm." % [Balance.BRANCHES[tower.kind][chosen_branch].name, UI.exact_money(pending_cost)]
		elif tower.level == 3:
			var lines := PackedStringArray()
			var options: Array = Balance.BRANCHES[tower.kind].keys()
			for index in range(options.size()):
				lines.append("%s · %s · %s gold" % ["← Left" if index == 0 else "Right →", Balance.BRANCHES[tower.kind][options[index]].name, UI.exact_money(Balance.upgrade_cost(tower, field.state.tuning, options[index]))])
			upgrade_quote.text = "\n".join(lines)
		else:
			upgrade_quote.text = "Upgrade to level %d · %s gold" % [int(tower.level) + 1, UI.exact_money(cost)]
		upgrade_quote.size.x = maxf(1.0, field.size.x - 24.0)
		upgrade_quote.size.y = upgrade_quote.get_combined_minimum_size().y
		upgrade_quote.position = Vector2(12, field.size.y - upgrade_quote.size.y - 12)
	frame_controls(tower)
	var center := field.screen(VigilWorld.pad_position(tower.region, tower.pad))
	if not Rect2(Vector2.ZERO, field.size).has_point(center):
		hide()
		return
	# Keep the entire control cluster fixed to the tower in map space.
	for action in ACTION_OFFSETS:
		var button: Button = buttons[action]
		button.scale = Vector2.ONE * field.zoom
		button.position = center + (ACTION_OFFSETS[action] - BUTTON_SIZE * 0.5) * field.zoom

func frame_controls(tower: Dictionary) -> void:
	if field.size.x <= 20.0 or field.size.y <= 20.0:
		return
	var available := Rect2(Vector2.ZERO, field.size).grow(-10.0)
	if upgrade_quote.visible:
		available.size.y = upgrade_quote.position.y - 10.0 - available.position.y
		# Wrapped text needs a layout frame when it is first assigned a width.
		if available.size.y <= 0.0:
			return
	var radius: float = Balance.tower_stats(tower, field.state.tuning, field.state.data.relics).range
	var signature := [field.state, field.selected_tower, tower.region, tower.pad, tower.level, radius, available]
	if signature == framing_signature:
		return
	framing_signature = signature
	var center := VigilWorld.pad_position(tower.region, tower.pad)
	var bounds := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	for action in ACTION_OFFSETS:
		bounds = bounds.merge(Rect2(center + ACTION_OFFSETS[action] - BUTTON_SIZE * 0.5, BUTTON_SIZE))
	if branch_bar.visible:
		for x in [-64, 64]:
			bounds = bounds.merge(Rect2(center + Vector2(x, 78) - BUTTON_SIZE * 0.5, BUTTON_SIZE))
	field.frame_world_rect(bounds, available)

func draw_icon(button: Button, action: String) -> void:
	preload("res://scripts/ui/towers/tower_action_icon.gd").draw(button, action, equipment_kind, upgrade_maxed, pending_tower)

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
	branch_bar.visible = not upgrade_in_dialog and int(tower.level) == 3
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
		button.accessibility_description = ("Confirm " if armed else ("Left: " if index == 0 else "Right: ")) + option.name + " · " + UI.exact_money(Balance.upgrade_cost(tower, field.state.tuning, options[index])) + " gold"
		button.accessibility_name = button.accessibility_description
