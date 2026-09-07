extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")
const CARD_SIZE := Vector2(196, 112)

static func create(kind: String, title: String, cost: float, action: Callable, level: int = 1, branch: String = "", reach: float = -1.0) -> Button:
	var button := UI.button("", action, 112, true)
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
		margin.add_theme_constant_override("margin_" + side, 8)
	button.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	layout.add_child(header)
	var heading := UI.fitted_heading(title, 18, 14)
	heading.name = "TowerName"
	header.add_child(heading)
	var marker := Control.new()
	marker.custom_minimum_size = Vector2(20, 20)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(marker)
	marker.draw.connect(func():
		var center := marker.size * 0.5
		marker.draw_circle(center, 8, UI.GOLD if button.button_pressed else UI.PANEL)
		marker.draw_arc(center, 8, 0, TAU, 32, UI.BORDER, 1.5, true)
		if button.button_pressed:
			marker.draw_polyline(PackedVector2Array([center + Vector2(-4, 0), center + Vector2(-1, 3), center + Vector2(4, -3)]), UI.TEXT, 2, true)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	layout.add_child(row)
	var portrait := Portrait.profile("towers", kind, tint, level, branch)
	portrait.name = "TowerPortrait"
	row.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", 4)
	row.add_child(copy)
	copy.add_child(stat_badge(cost, "gold", UI.PANEL.lerp(UI.GOLD, 0.65)))
	if reach >= 0.0:
		button.accessibility_name += " · Range %s" % UI.exact_money(reach)
		copy.add_child(stat_badge(reach, "range", UI.PANEL.lerp(tint, 0.22)))
	# Custom button contents must contribute their minimum for enlarged UI text.
	margin.minimum_size_changed.connect(func():
		button.custom_minimum_size = CARD_SIZE.max(margin.get_combined_minimum_size())
	)
	_ignore_mouse(margin)
	button.draw.connect(func():
		layout.modulate.a = 0.45 if button.disabled else 1.0
		marker.queue_redraw()
	)
	return button

static func stat_badge(amount: float, caption: String, tint: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size.y = 28
	var style := UI.surface(tint, 1, 2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	badge.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	badge.add_child(row)
	var number := UI.value(UI.exact_money(amount), 17)
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(number)
	var label := UI.label(caption, 12)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return badge

static func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)

## Shared base-tower catalog; hosts retain placement and transaction ownership.
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
