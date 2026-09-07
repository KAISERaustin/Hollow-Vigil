extends Control
## Screen-anchored identity and live values; gestures pass through to the world.
const UI = preload("res://scripts/ui/shared/interface.gd")
var identity: PanelContainer
var footer := VBoxContainer.new()
var left_card: PanelContainer
var right_card: PanelContainer
var notice_card: PanelContainer
var title: Label
var context: Label
var left_value: Label
var right_value: Label
var detail: Label
var notice: Label

func _init() -> void:
	name = "FloatingGameHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Later contextual controls draw above this passive world overlay.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var identity_text := VBoxContainer.new()
	identity_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_text.add_theme_constant_override("separation", 0)
	context = UI.label("", UI.CAPTION)
	identity_text.add_child(context)
	title = UI.heading("", UI.OBJECT_TITLE)
	identity_text.add_child(title)
	identity = _card(identity_text, UI.CARD_PADDING)
	add_child(identity)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", UI.CARD_GAP)
	add_child(footer)
	notice = UI.paragraph("", UI.CAPTION)
	notice.hide()
	notice_card = _card(notice)
	notice_card.hide()
	footer.add_child(notice_card)
	notice.visibility_changed.connect(func(): notice_card.visible = notice.visible)
	var values := HBoxContainer.new()
	values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	values.add_theme_constant_override("separation", 0)
	footer.add_child(values)
	left_value = UI.value("", 18)
	left_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_card = _card(left_value)
	left_card.size_flags_vertical = Control.SIZE_SHRINK_END
	values.add_child(left_card)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.custom_minimum_size.x = UI.CARD_GAP
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values.add_child(space)
	var wave_text := VBoxContainer.new()
	wave_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_text.add_theme_constant_override("separation", UI.CARD_GAP)
	detail = UI.label("", UI.CAPTION)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.hide()
	wave_text.add_child(detail)
	right_value = UI.value("", 18)
	right_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave_text.add_child(right_value)
	right_card = _card(wave_text)
	right_card.size_flags_vertical = Control.SIZE_SHRINK_END
	values.add_child(right_card)
	resized.connect(fit)
	footer.minimum_size_changed.connect(fit)
	identity.minimum_size_changed.connect(fit)

func _card(content: Control, padding: int = UI.INSET_PADDING) -> PanelContainer:
	var card := UI.info_card(content, UI.PANEL, padding)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return card

func _text_width(caption: Label) -> float:
	return ceilf(caption.get_theme_font("font").get_string_size(caption.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size("font_size")).x)

func fit() -> void:
	if not is_inside_tree(): return
	var safe := UI.safe_rect(self).grow(-UI.SCREEN_PADDING)
	var identity_width := minf(safe.size.x, maxf(_text_width(context), _text_width(title)) + UI.CARD_PADDING * 2)
	identity.position = safe.position
	identity.size = Vector2(identity_width, identity.get_combined_minimum_size().y)
	var right_width := _text_width(right_value)
	if detail.visible: right_width = maxf(right_width, _text_width(detail))
	right_width += UI.INSET_PADDING * 2
	var available := safe.size.x - UI.CARD_GAP
	var left_width := minf(_text_width(left_value) + UI.INSET_PADDING * 2,
		maxf(available * 0.5, available - right_width))
	left_card.custom_minimum_size.x = left_width
	right_card.custom_minimum_size.x = minf(right_width, available - left_width)
	notice_card.custom_minimum_size.x = minf(safe.size.x, _text_width(notice) + UI.INSET_PADDING * 2)
	footer.size = Vector2(safe.size.x, footer.get_combined_minimum_size().y)
	footer.position = Vector2(safe.position.x, safe.end.y - footer.size.y)

func overview_padding() -> Vector4:
	return Vector4(UI.SCREEN_PADDING, identity.position.y + identity.size.y + UI.SCREEN_PADDING,
		UI.SCREEN_PADDING, size.y - footer.position.y + UI.SCREEN_PADDING)
