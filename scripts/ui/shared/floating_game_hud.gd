extends Control
## Screen-anchored identity and live values; gestures pass through to the world.
const UI = preload("res://scripts/ui/shared/interface.gd")
var identity := VBoxContainer.new()
var footer := VBoxContainer.new()
var title: Label
var context: Label
var left_value: Label
var right_value: Label
var detail: Label
var notice: Label

func _init() -> void:
	name = "FloatingGameHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_theme_constant_override("separation", 0)
	add_child(identity)
	context = UI.label("", UI.CAPTION)
	identity.add_child(context)
	title = UI.heading("", UI.OBJECT_TITLE)
	identity.add_child(title)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 4)
	add_child(footer)
	notice = UI.paragraph("", UI.CAPTION)
	notice.hide()
	footer.add_child(notice)
	detail = UI.label("", UI.CAPTION)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	detail.hide()
	footer.add_child(detail)
	var values := HBoxContainer.new()
	values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	values.add_theme_constant_override("separation", UI.CARD_GAP)
	footer.add_child(values)
	left_value = UI.value("", 18)
	left_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	values.add_child(left_value)
	right_value = UI.value("", 18)
	right_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	values.add_child(right_value)
	resized.connect(fit)
	footer.minimum_size_changed.connect(fit)
	identity.minimum_size_changed.connect(fit)

func fit() -> void:
	if not is_inside_tree(): return
	var safe := UI.safe_rect(self).grow(-UI.SCREEN_PADDING)
	identity.position = safe.position
	identity.size = Vector2(safe.size.x, identity.get_combined_minimum_size().y)
	footer.size = Vector2(safe.size.x, footer.get_combined_minimum_size().y)
	footer.position = Vector2(safe.position.x, safe.end.y - footer.size.y)

func overview_padding() -> Vector4:
	return Vector4(UI.SCREEN_PADDING, identity.position.y + identity.size.y + UI.SCREEN_PADDING,
		UI.SCREEN_PADDING, size.y - footer.position.y + UI.SCREEN_PADDING)
