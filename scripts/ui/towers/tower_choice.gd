extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")
const CARD_SIZE := Vector2(48, 48)

static func create(kind: String, title: String, cost: float, action: Callable, level: int = 1, branch: String = "", reach: float = -1.0) -> Button:
	var button := UI.button("", action, CARD_SIZE.y, true)
	button.custom_minimum_size = CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.accessibility_name = "%s · %s gold" % [title, UI.exact_money(cost)]
	var definition := Balance.definition("towers", kind)
	var tint := Color(str(definition.get("color", "e0b568")))
	for state in ["normal", "hover", "disabled"]:
		button.add_theme_stylebox_override(state, UI.surface(UI.PANEL.lerp(tint, 0.12), UI.OUTLINE, 8))
	for state in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, UI.surface(UI.PANEL.lerp(UI.GOLD, 0.45), UI.OUTLINE, 8))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 3)
	button.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)
	var portrait := Portrait.preview("towers", kind, level, branch)
	portrait.name = "TowerPortrait"
	portrait.custom_minimum_size = Vector2(42, 42)
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(portrait)
	if reach >= 0.0:
		button.accessibility_name += " · Range %s" % UI.exact_money(reach)
	# Custom button contents must contribute their minimum for enlarged UI text.
	margin.minimum_size_changed.connect(func():
		button.custom_minimum_size = CARD_SIZE.max(margin.get_combined_minimum_size())
	)
	_ignore_mouse(margin)
	button.draw.connect(func():
		layout.modulate.a = 0.45 if button.disabled else 1.0
	)
	return button

## Permanent path cards use native portraits and explicit purchase states.
static func branch_card(kind: String, title: String, price: float, branch: String, state: String, selected: bool, action: Callable) -> Button:
	var button := UI.button("", action, 148)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.accessibility_name = "%s · %s gold · %s" % [title, UI.exact_money(price), state]
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(style, UI.surface(UI.GOLD if selected else UI.PANEL, UI.OUTLINE, 8))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var art := Portrait.preview("towers", kind, 4, branch)
	art.custom_minimum_size = Vector2(48, 56)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(art)
	for caption in [title, UI.exact_money(price) + " gold", state]:
		var label := UI.paragraph(caption, 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	margin.minimum_size_changed.connect(func(): button.custom_minimum_size.y = maxf(148, margin.get_combined_minimum_size().y))
	_ignore_mouse(margin)
	return button

## One detail renderer for both modes, driven by resolved content and stat metadata.
static func details(kind: String, tuning: Dictionary, tier: int = 1, branch: String = "", previous: Dictionary = {}, show_range: bool = false, effective: Dictionary = {}) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.name = "TowerDetails"
	body.add_theme_constant_override("separation", UI.GAP)
	var stats := Balance.stats(kind, tier, tuning, branch) if effective.is_empty() else effective
	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", UI.GAP)
	var summary_card := UI.info_card(summary, UI.SURFACE, UI.CARD_PADDING)
	summary_card.name = "TowerSummary"
	body.add_child(summary_card)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UI.CARD_GAP)
	summary.add_child(header)
	var level := UI.heading("Level %d" % tier if previous.is_empty() else "Level %d → %d" % [tier - 1, tier], 18)
	level.name = "TowerLevel"
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(level)
	if not effective.is_empty():
		var base := UI.label("Equipped stats", 12, UI.MUTED)
		base.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(base)
	var description := UI.paragraph(Balance.tower_description(stats), 14)
	description.name = "TowerDescription"
	description.add_theme_constant_override("line_spacing", 0)
	summary.add_child(description)
	_ignore_mouse(summary)
	var grid := GridContainer.new()
	grid.name = "TowerStats"
	grid.columns = 2
	grid.resized.connect(func(): grid.columns = 3 if grid.size.x >= 400 else 2)
	grid.add_theme_constant_override("h_separation", UI.CARD_GAP)
	grid.add_theme_constant_override("v_separation", UI.CARD_GAP)
	body.add_child(grid)
	var values := stats.duplicate(true)
	values.fire_rate = 1.0 / stats.period
	values.dps = stats.damage / stats.period
	var before := previous.duplicate(true)
	if not before.is_empty():
		before.fire_rate = 1.0 / before.period
		before.dps = before.damage / before.period
	add_numeric_stat(grid, "damage", "Damage / hit", values, before)
	add_numeric_stat(grid, "fire_rate", "Attacks / sec", values, before)
	add_numeric_stat(grid, "period", "Seconds / attack", values, before, " s")
	if show_range:
		add_numeric_stat(grid, "range", "Range", values, before, " units")
	add_numeric_stat(grid, "dps", "Base DPS", values, before)
	add_numeric_stat(grid, "targets", "Targets / hit", values, before)
	add_numeric_stat(grid, "splash", "Blast radius", values, before, " units")
	# Cost lives in the pinned Build action; build details omit range.
	# Future numeric content fields use the same presentation and schema labels.
	for field in stats:
		if field in ["cost", "damage", "range", "period", "splash", "targets"]:
			continue
		if not stats.has(field) or not (stats[field] is float or stats[field] is int):
			continue
		var spec: Dictionary = Balance.TUNING_FIELDS.towers.get(field, {})
		var title: String = spec.get("label", str(field).capitalize())
		add_numeric_stat(grid, field, title, values, before, str(spec.get("suffix", "")))
	return body

static func change_text(value: float, previous: float, suffix: String = "") -> String:
	var difference := value - previous
	if is_zero_approx(difference):
		return "No change"
	# Preserve small improvements that would otherwise round to +0.00.
	var amount := UI.exact_money(absf(difference)) if absf(difference) >= 0.01 else String.num(absf(difference), 4)
	return ("+" if difference > 0.0 else "−") + amount + suffix

static func add_numeric_stat(grid: GridContainer, key: String, title: String, values: Dictionary, before: Dictionary, suffix: String = "") -> void:
	var change := "" if before.is_empty() else change_text(values[key], before.get(key, 0.0), suffix)
	add_stat(grid, key, title, UI.exact_money(values[key]) + suffix, change)

static func add_stat(grid: GridContainer, key: String, title: String, value: String, change: String = "") -> void:
	var column := UI.stat(title, value)
	var panel := UI.info_card(column)
	panel.name = "StatCard_" + key
	grid.add_child(panel)
	var number: Label = column.get_child(0)
	number.name = "Stat_" + key
	if not change.is_empty():
		var difference := UI.label(change, 12, UI.MUTED)
		difference.name = "Change_" + key
		difference.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(difference)
	_ignore_mouse(column)

static func show_details(choices: ScrollContainer, tuning: Dictionary, kind: String) -> void:
	clear_details(choices)
	select(choices, kind)
	choices.hide()
	choices.get_parent().add_child(build_preview(kind, tuning))

## Shared compact construction identity; specialization choices belong to level 3.
static func build_preview(kind: String, tuning: Dictionary) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.name = "TowerDetails"
	body.set_meta("tower_kind", kind)
	body.add_theme_constant_override("separation", UI.CARD_GAP)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.GAP)
	body.add_child(row)
	var portrait := Portrait.preview("towers", kind)
	portrait.name = "BuildPortrait"
	portrait.custom_minimum_size = Vector2(96, 96)
	row.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 4)
	row.add_child(identity)
	var definition := Balance.definition("towers", kind, tuning)
	var title := UI.heading(definition.name, 18)
	title.name = "BuildTowerName"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(title)
	var cost := UI.heading(UI.exact_money(definition.cost) + " gold", 18)
	cost.name = "BuildCost"
	cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(cost)
	var level := preload("res://scripts/ui/shared/tower_level_indicator.gd").create(1, false)
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	identity.add_child(level)
	_ignore_mouse(body)
	return body

static func clear_details(choices: ScrollContainer) -> void:
	var previous := choices.get_parent().get_node_or_null("TowerDetails")
	if previous != null:
		choices.get_parent().remove_child(previous)
		previous.queue_free()
	choices.show()

static func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)

## Shared base-tower catalog; hosts retain placement and transaction ownership.
static func first_kind() -> String:
	return str(Balance.TOWERS.keys()[0])

static func build_list(tuning: Dictionary, action: Callable, selected_kind: String = "", balance: float = INF, prefix: String = "Build_", fit_row: bool = false) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "TowerCards"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	if fit_row:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.accessibility_name = "Tower cards. All build options visible"
	else:
		UI.keyboard_scroll(scroll, "Tower cards. Swipe left or right to browse", true)
	var choices := HBoxContainer.new()
	choices.name = "Cards"
	if fit_row:
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 8)
	scroll.add_child(choices)
	scroll.resized.connect(func():
		var edge := maxf(CARD_SIZE.x, (scroll.size.x - 8.0 * (choices.get_child_count() - 1)) / maxf(1, choices.get_child_count()))
		if fit_row:
			# Whole layout units prevent container rounding from overflowing the row.
			edge = maxf(1, floorf((scroll.size.x - 8.0 * (choices.get_child_count() - 1)) / maxf(1, choices.get_child_count())))
		for card in choices.get_children():
			if fit_row:
				card.find_child("TowerPortrait", true, false).custom_minimum_size = Vector2.ONE * maxf(1, edge - 6)
			card.custom_minimum_size = Vector2(edge, edge)
	)
	choices.minimum_size_changed.connect(func():
		scroll.custom_minimum_size.y = choices.get_combined_minimum_size().y
	)
	for kind in Balance.TOWERS:
		var definition := Balance.definition("towers", kind, tuning)
		var button := create(kind, definition.name, definition.cost, action.bind(kind), 1, "", definition.range)
		if fit_row:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var margin: MarginContainer = button.get_child(0)
			for connection in margin.minimum_size_changed.get_connections():
				margin.minimum_size_changed.disconnect(connection.callable)
			button.find_child("TowerPortrait", true, false).custom_minimum_size = Vector2.ZERO
			button.custom_minimum_size = Vector2.ZERO
		button.name = prefix + kind
		button.set_meta("tower_kind", kind)
		button.disabled = balance < definition.cost
		button.toggle_mode = not selected_kind.is_empty()
		button.set_pressed_no_signal(selected_kind == kind)
		choices.add_child(button)
		if selected_kind == kind:
			scroll.ready.connect(func(): scroll.ensure_control_visible.call_deferred(button))
	return scroll

static func select(scroll: ScrollContainer, kind: String) -> void:
	for button in scroll.get_node("Cards").get_children():
		button.set_pressed_no_signal(button.get_meta("tower_kind") == kind)
