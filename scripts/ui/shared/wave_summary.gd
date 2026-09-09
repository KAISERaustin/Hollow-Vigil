extends RefCounted
## Reusable Wave presentation. Reports and callbacks come from the owning screen;
## this component never retains a run or changes content, rewards, or spawn state.

const UI = preload("res://scripts/ui/shared/interface.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")

static func total_time_card(reports: Array[Dictionary]) -> PanelContainer:
	var seconds := 0.0
	for report in reports:
		seconds += float(report.last_spawn_seconds)
	var rounded := ceili(seconds)
	var duration := "%d min %02d sec" % [rounded / 60, rounded % 60] if rounded >= 60 else "%d sec" % rounded
	var panel := UI.stat_card("Total Wave Time", duration, 28)
	panel.name = "TotalWaveTime"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = panel.get_child(0)
	body.add_child(UI.rule())
	var note := UI.paragraph("No pauses between rounds. Based on spawn timing; defeating the final enemies adds time.", UI.META)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)
	return panel

static func card(report: Dictionary, status: String, details: Callable, edit: Callable = Callable(), authoring: Dictionary = {}) -> PanelContainer:
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
		var row := enemy_row(kind, int(report.enemy_counts[kind]))
		if authoring.has("quantity"):
			var identity: HBoxContainer = row.get_child(0)
			var badge := identity.get_child(-1)
			identity.remove_child(badge)
			badge.queue_free()
			var quantity := UI.button("×%d" % int(report.enemy_counts[kind]), authoring.quantity.bind(kind))
			quantity.name = "WaveEnemyCount_" + kind
			quantity.custom_minimum_size = Vector2(72, UI.TARGET)
			quantity.add_theme_font_size_override("font_size", UI.type_size(UI.CAPTION))
			quantity.accessibility_name = "Edit " + str(report.enemy_counts[kind]) + " " + str(Balance.definition("bosses" if Balance.BOSSES.has(kind) else "enemies", kind).name)
			quantity.size_flags_horizontal = Control.SIZE_SHRINK_END
			quantity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			identity.add_child(quantity)
		roster.add_child(row)
	if report.spawn_count == 0: roster.add_child(UI.paragraph("Empty wave · skipped during play"))
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
	if authoring.has("add"):
		var controls := HBoxContainer.new()
		controls.add_theme_constant_override("separation", UI.GAP)
		body.add_child(controls)
		var add := UI.button("Add enemies", authoring.add)
		add.name = "AddEnemiesWave%d" % report.wave
		controls.add_child(add)
		var remove := UI.button("Remove wave", authoring.remove)
		remove.name = "RemoveWave%d" % report.wave
		controls.add_child(remove)
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
