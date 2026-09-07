extends RefCounted
## Shared save identity, progress and actions. The menu supplies display data and
## buttons; save access, recovery and session changes stay with their owners.

const UI = preload("res://scripts/ui/shared/interface.gd")

static func card(slot: int, title: String, mode: String, description: String, stats: Array, buttons: Array[Button]) -> PanelContainer:
	var body := VBoxContainer.new()
	body.name = "GameSlot" + str(slot + 1)
	body.add_theme_constant_override("separation", UI.GAP)
	var panel := UI.info_card(body, UI.SURFACE, UI.CARD_PADDING)
	panel.name = "SavedGameCard" + str(slot + 1)
	var slot_label := UI.heading("Slot %d" % (slot + 1), UI.CAPTION)
	body.add_child(slot_label)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", UI.CARD_GAP)
	body.add_child(identity)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UI.CARD_GAP)
	identity.add_child(header)
	var heading := UI.heading(title, 18)
	heading.name = "GameTitle"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var name_card := UI.info_card(heading)
	name_card.name = "GameNameCard"
	header.add_child(name_card)
	if not mode.is_empty():
		var mode_label := UI.heading(mode, 18)
		mode_label.name = "GameMode"
		mode_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		mode_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var mode_card := UI.info_card(mode_label)
		mode_card.name = "GameModeCard"
		mode_card.size_flags_horizontal = Control.SIZE_SHRINK_END
		mode_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		header.add_child(mode_card)
	if not description.is_empty():
		var detail := UI.paragraph(description)
		detail.name = "GameDescription"
		identity.add_child(detail)
	if not stats.is_empty():
		var values := GridContainer.new()
		values.name = "GameProgress"
		values.columns = 2
		values.add_theme_constant_override("h_separation", UI.CARD_GAP)
		values.add_theme_constant_override("v_separation", UI.CARD_GAP)
		body.add_child(values)
		for entry: Dictionary in stats:
			var column := UI.stat(entry.label, entry.value)
			column.name = entry.key
			if not str(entry.get("detail", "")).is_empty():
				column.add_child(UI.paragraph(entry.detail))
			values.add_child(UI.info_card(column))
		values.resized.connect(func(): values.columns = 1 if values.size.x < 240 else 2)
	var actions := BoxContainer.new()
	actions.name = "GameActions"
	actions.add_theme_constant_override("separation", UI.GAP)
	body.add_child(actions)
	for button in buttons:
		button.custom_minimum_size.y = 52
		actions.add_child(button)
	# Measure the labels so longer actions stack without squeezing touch targets.
	var reflow := func():
		var widest := 0.0
		for button in buttons:
			var text_width := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
			widest = maxf(widest, text_width + button.get_theme_stylebox("normal").get_minimum_size().x)
		var required := widest * buttons.size() + UI.GAP * maxi(0, buttons.size() - 1)
		actions.vertical = actions.size.x < required
	actions.resized.connect(reflow)
	return panel
