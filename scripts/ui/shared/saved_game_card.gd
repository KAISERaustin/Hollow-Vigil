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
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UI.CARD_GAP)
	body.add_child(header)
	var slot_label := UI.heading("Slot %d" % (slot + 1), UI.CAPTION)
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(slot_label)
	if not mode.is_empty(): header.add_child(UI.label(mode, UI.CAPTION, UI.MUTED))
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", UI.CARD_GAP)
	body.add_child(identity)
	var heading := UI.heading(title, 18)
	heading.name = "GameTitle"
	identity.add_child(heading)
	if not description.is_empty():
		var detail := UI.paragraph(description)
		detail.name = "GameDescription"
		identity.add_child(detail)
	if not stats.is_empty():
		body.add_child(UI.rule())
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
