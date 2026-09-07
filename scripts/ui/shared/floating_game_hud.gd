extends Control
## Screen-anchored identity and live values; gestures pass through to the world.
const UI = preload("res://scripts/ui/shared/interface.gd")
var header := HBoxContainer.new()
var identity: PanelContainer
var left_card: PanelContainer
var right_card: PanelContainer
var detail_card: PanelContainer
var notice_card: PanelContainer
var title: Label
var left_value: Label
var right_value: Label
var detail: Label
var notice: Label

func _init() -> void:
	name = "FloatingGameHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Later contextual controls draw above this passive world overlay.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", UI.CARD_GAP)
	add_child(header)
	title = UI.value("", UI.BODY)
	identity = _card(title, UI.CARD_PADDING)
	header.add_child(identity)
	left_value = UI.value("", UI.BODY)
	left_card = _card(left_value)
	header.add_child(left_card)
	right_value = UI.value("", UI.BODY)
	right_card = _card(right_value)
	header.add_child(right_card)
	detail = UI.value("", UI.BODY)
	detail_card = _card(detail)
	header.add_child(detail_card)
	for caption: Label in [title, left_value, right_value, detail]:
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice = UI.paragraph("", UI.CAPTION)
	notice.hide()
	notice_card = _card(notice)
	notice_card.hide()
	add_child(notice_card)
	notice.visibility_changed.connect(func():
		notice_card.visible = notice.visible
		fit()
	)
	resized.connect(fit)
	header.minimum_size_changed.connect(fit)
	notice_card.minimum_size_changed.connect(fit)

func _card(content: Control, padding: int = UI.INSET_PADDING) -> PanelContainer:
	var card := UI.info_card(content, UI.PANEL, padding)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_FILL
	return card

func _text_width(caption: Label, text: String) -> float:
	return ceilf(caption.get_theme_font("font").get_string_size(text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size("font_size")).x)

func fit() -> void:
	if not is_inside_tree(): return
	var safe := UI.safe_rect(self).grow(-UI.SCREEN_PADDING)
	var captions: Array[Label] = [title, left_value, right_value, detail]
	var cards: Array[PanelContainer] = [identity, left_card, right_card, detail_card]
	var minimums: Array[float] = []
	var preferred: Array[float] = []
	# Keep four cards in one row. Give words room before distributing the rest;
	# longer content wraps vertically without reducing the font sizes.
	for index in cards.size():
		var caption := captions[index]
		var padding := (UI.CARD_PADDING if index == 0 else UI.INSET_PADDING) * 2.0
		var word_width := 0.0
		for word in caption.text.split(" "):
			word_width = maxf(word_width, _text_width(caption, word))
		minimums.append(word_width + padding)
		preferred.append(_text_width(caption, caption.text) + padding)
	var available := maxf(1.0, safe.size.x - UI.CARD_GAP * (cards.size() - 1))
	# A long name or unusually large number must not break short words such as
	# "gold", "Wave" and "remaining" in all the neighboring cards.
	minimums[1] = minf(minimums[1], _text_width(left_value, "9999") + UI.INSET_PADDING * 2)
	minimums[0] = minf(minimums[0], maxf(UI.CARD_PADDING * 2 + UI.META,
		available - minimums[1] - minimums[2] - minimums[3]))
	var minimum_total := 0.0
	var preferred_total := 0.0
	for index in cards.size():
		minimum_total += minimums[index]
		preferred_total += preferred[index]
	var used := 0.0
	for index in cards.size():
		var width := minimums[index] * minf(1.0, available / maxf(1.0, minimum_total))
		if available > minimum_total:
			var fraction := (preferred[index] - minimums[index]) / maxf(1.0, preferred_total - minimum_total)
			width += minf(available - minimum_total, preferred_total - minimum_total) * fraction
			width += maxf(0.0, available - preferred_total) / cards.size()
		width = floorf(width) if index < cards.size() - 1 else available - used
		cards[index].custom_minimum_size.x = width
		used += width
	header.position = safe.position
	header.size = Vector2(safe.size.x, header.get_combined_minimum_size().y)
	notice_card.size = Vector2(minf(safe.size.x, _text_width(notice, notice.text) + UI.INSET_PADDING * 2), notice_card.get_combined_minimum_size().y)
	notice_card.position = Vector2(safe.position.x, safe.end.y - notice_card.size.y)

func overview_padding() -> Vector4:
	var bottom := size.y - notice_card.position.y if notice_card.visible else UI.SCREEN_PADDING
	return Vector4(UI.SCREEN_PADDING, header.position.y + header.size.y + UI.SCREEN_PADDING,
		UI.SCREEN_PADDING, bottom + UI.SCREEN_PADDING)
