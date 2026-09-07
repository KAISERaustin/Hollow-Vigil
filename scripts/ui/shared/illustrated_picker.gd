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
	popup.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 3, 12))
	add_child(popup)
	popup.popup_hide.connect(func():
		if is_visible_in_tree(): grab_focus()
	)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	popup.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := UI.fitted_heading(menu_title, 24)
	title.name = "PickerTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UI.close_button(popup.hide))
	body.add_child(UI.rule())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	UI.keyboard_scroll(scroll, "Scroll through choices")
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)

func clear() -> void:
	items.clear()
	selected = -1
	text = "Choose item"

func add_item(label: String) -> void:
	items.append({"label": label, "metadata": null})

func set_item_metadata(index: int, value: Variant) -> void:
	items[index].metadata = value

func get_item_metadata(index: int) -> Variant:
	return items[index].metadata

func select(index: int) -> void:
	selected = index
	text = str(items[index].label) + " · Choose"

func get_popup() -> PopupPanel:
	return popup

func choose(index: int) -> void:
	select(index)
	popup.hide()
	item_selected.emit(index)

func show_popup() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	popup.find_child("PickerTitle", true, false).text = menu_title
	for index in range(item_count):
		var button := UI.button("", choose.bind(index), 76)
		button.name = "Choice_" + str(index)
		button.accessibility_name = str(items[index].label)
		button.toggle_mode = true
		button.set_pressed_no_signal(index == selected)
		rows.add_child(button)
		var content := HBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 8
		content.offset_right = -8
		content.add_theme_constant_override("separation", 12)
		button.add_child(content)
		if preview_factory.is_valid():
			content.add_child(preview_factory.call(items[index].metadata))
		var label := UI.paragraph(str(items[index].label), UI.BODY)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(label)
		if index < item_count - 1: rows.add_child(UI.rule())
	var available := get_viewport_rect().size - Vector2(24, 24)
	popup.popup_centered(Vector2i(minf(480, available.x), minf(560, available.y)))
	scroll.scroll_vertical = 0
	UI.trap_focus(popup.get_child(0))
	if selected >= 0:
		var active := rows.get_node("Choice_" + str(selected)) as Button
		active.grab_focus()
		scroll.ensure_control_visible.call_deferred(active)
