extends Button
## Reusable illustrated selection menu. Choice data and artwork belong to callers.
signal item_selected(index: int)

const UI = preload("res://scripts/ui/shared/interface.gd")
var items: Array[Dictionary] = []
var item_count: int:
	get: return items.size()
var selected := -1
var menu_title := "Choose item"
var preview_factory: Callable
var illustration := "rules"
var direct_choices := false
var popup: PopupPanel
var scroll: ScrollContainer
var rows: VBoxContainer

func _ready() -> void:
	custom_minimum_size.y = UI.TARGET
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pressed.connect(show_popup)
	popup = PopupPanel.new()
	popup.name = "IllustratedSelectionMenu"
	popup.theme = UI.theme()
	popup.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, 12))
	add_child(popup)
	popup.popup_hide.connect(func():
		if is_visible_in_tree(): grab_focus()
	)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	popup.add_child(body)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	body.add_child(heading)
	var header := HBoxContainer.new()
	heading.add_child(header)
	var title := UI.fitted_heading(menu_title, 24)
	title.name = "PickerTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UI.close_button(popup.hide))
	heading.add_child(UI.rule())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	UI.keyboard_scroll(scroll, "Scroll through choices")
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Row contents center between adjacent rules, without extra space above them.
	rows.add_theme_constant_override("separation", 0)
	scroll.add_child(rows)
	get_viewport().size_changed.connect(fit_popup)

func clear() -> void:
	items.clear()
	selected = -1
	text = "Choose item"

func add_item(label: String) -> void:
	items.append({"label": label, "metadata": null, "disabled": false})
	if selected < 0: select(0)

func set_item_disabled(index: int, value: bool) -> void:
	items[index].disabled = value

func is_item_disabled(index: int) -> bool:
	return items[index].disabled

func set_item_metadata(index: int, value: Variant) -> void:
	items[index].metadata = value

func get_item_metadata(index: int) -> Variant:
	return items[index].metadata

func select(index: int) -> void:
	selected = index
	text = str(items[index].label) + " · Choose" if index >= 0 else menu_title

func get_popup() -> PopupPanel:
	return popup

func choose(index: int) -> void:
	if disabled or is_item_disabled(index): return
	select(index)
	# A selection callback may replace this page and detach the popup.
	popup.set_input_as_handled()
	popup.hide()
	item_selected.emit(index)

func show_popup() -> void:
	if disabled: return
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	popup.find_child("PickerTitle", true, false).text = menu_title
	for index in range(item_count):
		if direct_choices:
			var choice := UI.button(str(items[index].label), choose.bind(index))
			choice.name = "Choice_" + str(index)
			choice.disabled = is_item_disabled(index)
			rows.add_child(choice)
			continue
		var button := UI.button("Select", choose.bind(index))
		button.name = "Choice_" + str(index)
		button.toggle_mode = true
		button.disabled = is_item_disabled(index)
		button.set_pressed_no_signal(index == selected)
		var preview: Control = preview_factory.call(items[index].metadata) if preview_factory.is_valid() else preload("res://scripts/ui/shared/choice_portrait.gd").preview(illustration)
		var row := UI.action_row(str(items[index].label), button, "Select", preview)
		row.name = "ChoiceRow_" + str(index)
		row.custom_minimum_size.y = 76
		rows.add_child(row)
	# Reserve the same action column for every row, including the longer
	# selected caption. Selection must never shift artwork or label widths.
	var action_width := 88.0
	for row in rows.get_children():
		if direct_choices: break
		var action := row.get_child(row.get_child_count() - 1) as Button
		action_width = maxf(action_width, action.get_combined_minimum_size().x)
	for row in rows.get_children():
		if direct_choices: break
		var action := row.get_child(row.get_child_count() - 1) as Button
		action.custom_minimum_size.x = action_width
	popup.popup()
	fit_popup()
	fit_popup.call_deferred()
	scroll.scroll_vertical = 0
	UI.trap_focus(popup.get_child(0))
	if selected >= 0:
		var active := rows.find_child("Choice_" + str(selected), true, false) as Button
		active.grab_focus()
		scroll.ensure_control_visible.call_deferred(active)

func fit_popup() -> void:
	if not is_instance_valid(popup) or not popup.visible: return
	var safe := UI.safe_viewport(self).grow(-12)
	popup.max_size = Vector2i(safe.size)
	var height := 560.0
	if direct_choices:
		rows.add_theme_constant_override("separation", 8)
		height = 24 + popup.get_child(0).get_child(0).get_combined_minimum_size().y + rows.get_combined_minimum_size().y
	popup.size = Vector2i(Vector2(minf(480, safe.size.x), minf(height, safe.size.y)))
	popup.position = Vector2i(safe.get_center() - Vector2(popup.size) * 0.5)
	# Rotation changes the scroll range after containers lay out their children.
	var focus := popup.gui_get_focus_owner()
	if focus != null and rows.is_ancestor_of(focus):
		scroll.ensure_control_visible.call_deferred(focus)
