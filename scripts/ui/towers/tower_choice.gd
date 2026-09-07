extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")
const CARD_SIZE := Vector2(104, 94)

static func create(kind: String, title: String, cost: float, action: Callable, level: int = 1, branch: String = "", reach: float = -1.0) -> Button:
	var button := UI.button("", action, CARD_SIZE.y, true)
	button.custom_minimum_size = CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.accessibility_name = "%s · %s gold" % [title, UI.exact_money(cost)]
	var definition := Balance.definition("towers", kind)
	var tint := Color(str(definition.get("color", "e0b568")))
	for state in ["normal", "hover", "disabled"]:
		button.add_theme_stylebox_override(state, UI.surface(UI.PANEL.lerp(tint, 0.12), 3, 8))
	for state in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, UI.surface(UI.PANEL.lerp(UI.GOLD, 0.45), 3, 8))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	button.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)
	var portrait := Portrait.profile("towers", kind, tint, level, branch)
	portrait.name = "TowerPortrait"
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(portrait)
	var heading := UI.fitted_heading(title, 14, 12)
	heading.name = "TowerName"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(heading)
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

## One detail renderer for both modes, driven by resolved content and stat metadata.
static func details(kind: String, tuning: Dictionary) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.name = "TowerDetails"
	body.add_theme_constant_override("separation", 8)
	var stats := Balance.stats(kind, 1, tuning)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)
	var level := UI.heading("Level 1", 18)
	level.name = "TowerLevel"
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(level)
	var base := UI.label("Before equipment", 12, UI.MUTED)
	base.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(base)
	var description := UI.paragraph(Balance.tower_description(stats), 14)
	description.name = "TowerDescription"
	description.add_theme_constant_override("line_spacing", 0)
	body.add_child(description)
	body.add_child(UI.rule())
	var grid := GridContainer.new()
	grid.name = "TowerStats"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	add_stat(grid, "damage", "Damage / hit", UI.exact_money(stats.damage))
	add_stat(grid, "fire_rate", "Attacks / sec", UI.exact_money(1.0 / stats.period))
	add_stat(grid, "range", "Range", UI.exact_money(stats.range) + " units")
	add_stat(grid, "dps", "DPS / target", UI.exact_money(stats.damage / stats.period))
	add_stat(grid, "targets", "Targets / hit", UI.exact_money(stats.targets))
	add_stat(grid, "splash", "Blast radius", UI.exact_money(stats.splash) + " units")
	# Cost lives in the pinned Build action; interval complements the fire rate.
	# Future numeric content fields use the same presentation and schema labels.
	for field in stats:
		if field in ["cost", "damage", "range", "period", "splash", "targets"]:
			continue
		if not stats.has(field) or not (stats[field] is float or stats[field] is int):
			continue
		var spec: Dictionary = Balance.TUNING_FIELDS.towers.get(field, {})
		var title: String = spec.get("label", str(field).capitalize())
		add_stat(grid, field, title, UI.exact_money(stats[field]) + str(spec.get("suffix", "")))
	var interval := UI.label(UI.exact_money(stats.period) + " s between attacks", 12, UI.MUTED)
	interval.name = "Stat_period"
	body.add_child(interval)
	return body

static func add_stat(grid: GridContainer, key: String, title: String, value: String) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	grid.add_child(column)
	var label := UI.label(title, 12, UI.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	var number := UI.value(value, 18)
	number.name = "Stat_" + key
	number.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(number)

static func show_details(choices: ScrollContainer, tuning: Dictionary, kind: String) -> void:
	clear_details(choices)
	select(choices, kind)
	choices.hide()
	choices.get_parent().add_child(details(kind, tuning))

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

static func build_list(tuning: Dictionary, action: Callable, selected_kind: String = "", balance: float = INF, prefix: String = "Build_") -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "TowerCards"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	UI.keyboard_scroll(scroll, "Tower cards. Swipe left or right to browse", true)
	var choices := HBoxContainer.new()
	choices.name = "Cards"
	choices.add_theme_constant_override("separation", 8)
	scroll.add_child(choices)
	choices.minimum_size_changed.connect(func():
		scroll.custom_minimum_size.y = choices.get_combined_minimum_size().y
	)
	for kind in Balance.TOWERS:
		var definition := Balance.definition("towers", kind, tuning)
		var button := create(kind, definition.name, definition.cost, action.bind(kind), 1, "", definition.range)
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
