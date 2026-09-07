extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")

static func create(kind: String, title: String, cost: float, action: Callable, level: int = 1, branch: String = "", reach: float = -1.0) -> Button:
	var button := UI.button("", action, 112, true)
	button.custom_minimum_size.x = 152
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.accessibility_name = "%s · %s gold" % [title, UI.exact_money(cost)]
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	button.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	layout.add_child(row)
	var portrait := Control.new()
	portrait.name = "TowerPortrait"
	portrait.custom_minimum_size = Vector2(30, 40)
	portrait.draw.connect(func():
		# Tower art extends roughly from -42 to +12 around its ground anchor.
		var center := portrait.size * 0.5 + Vector2(0, 7.5)
		VigilTerrainArt.sentinel(portrait, kind, center, 0.5, level, branch)
	)
	portrait.resized.connect(portrait.queue_redraw)
	row.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", 0)
	row.add_child(copy)
	# Portrait and price share the upper half; the full-width title stays below.
	var detail := "%s gold" % UI.exact_money(cost)
	if reach >= 0.0:
		button.accessibility_name += " · Range %s" % UI.exact_money(reach)
	copy.add_child(UI.label(detail, 13))
	if reach >= 0.0:
		copy.add_child(UI.label("Range %s" % UI.exact_money(reach), 13))
	var heading := UI.heading(title, 16)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(heading)
	# Custom button contents must contribute their minimum for enlarged UI text.
	margin.minimum_size_changed.connect(func():
		button.custom_minimum_size = Vector2(152, 112).max(margin.get_combined_minimum_size())
	)
	_ignore_mouse(margin)
	button.draw.connect(func(): layout.modulate.a = 0.45 if button.disabled else 1.0)
	return button

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
