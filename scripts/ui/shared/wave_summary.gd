extends RefCounted
## Reusable Wave presentation. Reports and callbacks come from the owning screen;
## this component never retains a run or changes content, rewards, or spawn state.

const UI = preload("res://scripts/ui/shared/interface.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")

static func card(report: Dictionary, status: String, details: Callable, edit: Callable = Callable()) -> PanelContainer:
	var body := VBoxContainer.new()
	var panel := UI.info_card(body, UI.SURFACE, UI.CARD_PADDING)
	panel.name = "WaveSummary" + str(report.wave)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UI.GAP)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UI.GAP)
	body.add_child(header)
	var title := UI.heading("Wave %d" % report.wave, 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if not status.is_empty():
		var state := UI.label(status, UI.META, UI.MUTED)
		state.name = "WaveStatus"
		state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(state)
	body.add_child(UI.rule())
	var stats := GridContainer.new()
	stats.name = "WaveStats"
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", UI.CARD_GAP)
	stats.add_theme_constant_override("v_separation", UI.CARD_GAP)
	body.add_child(stats)
	stats.add_child(UI.info_card(UI.stat("Enemies", str(report.spawn_count))))
	stats.add_child(UI.info_card(UI.stat("Wave gold", UI.exact_money(report.completion_gold))))
	stats.add_child(UI.info_card(UI.stat("Total health", UI.exact_money(report.total_spawn_health))))
	stats.add_child(UI.info_card(UI.stat("Last spawn", "%s s" % UI.exact_money(report.last_spawn_seconds))))
	stats.resized.connect(func(): stats.columns = 4 if stats.size.x >= 400 else 2)
	var roster := VBoxContainer.new()
	roster.name = "EnemyRoster"
	roster.add_theme_constant_override("separation", UI.CARD_GAP)
	body.add_child(roster)
	for kind: String in report.enemy_counts:
		roster.add_child(enemy_row(kind, int(report.enemy_counts[kind])))
	var actions := HBoxContainer.new()
	actions.name = "WaveActions"
	actions.add_theme_constant_override("separation", UI.GAP)
	body.add_child(actions)
	var balance := UI.button("Balancing details", details)
	balance.name = "WaveBalancingDetails" + str(report.wave)
	balance.accessibility_name = "Wave %d balancing details" % report.wave
	balance.add_theme_font_size_override("font_size", UI.type_size(UI.CAPTION))
	balance.size_flags_stretch_ratio = 1.6
	actions.add_child(balance)
	if edit.is_valid():
		var edit_button := UI.button("Edit wave", edit)
		edit_button.name = "EditCampaignWave" + str(report.wave)
		edit_button.accessibility_name = "Edit wave %d" % report.wave
		edit_button.add_theme_font_size_override("font_size", UI.type_size(UI.CAPTION))
		actions.add_child(edit_button)
	return panel

static func enemy_row(kind: String, count: int, detail: String = "") -> PanelContainer:
	var panel := UI.info_card(enemy_identity(kind, count, detail))
	panel.name = "EnemyCard_" + kind
	return panel

static func enemy_identity(kind: String, count: int, detail: String = "") -> HBoxContainer:
	var boss := Balance.BOSSES.has(kind)
	var definition := Balance.definition("bosses" if boss else "enemies", kind)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.CARD_GAP)
	var art := Portrait.preview("bosses" if boss else "enemies", kind)
	art.custom_minimum_size = Vector2(48, 48)
	row.add_child(art)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 0)
	row.add_child(identity)
	identity.add_child(UI.heading(str(definition.name), UI.CAPTION))
	identity.add_child(UI.paragraph(detail if not detail.is_empty() else str(definition.get("role", "Boss")).split(" · ")[-1].capitalize(), UI.META))
	var quantity := UI.value("×%d" % count, 18)
	quantity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quantity.accessibility_name = "%d %s" % [count, definition.name]
	var badge := UI.info_card(quantity, UI.SURFACE, 6)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	return row
