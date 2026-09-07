extends RefCounted
## Composes the owning campaign's Wave report; never changes simulation or tuning.

const UI = preload("res://scripts/ui/shared/interface.gd")
const WaveSummary = preload("res://scripts/ui/shared/wave_summary.gd")
const Comparison = preload("res://scripts/ui/shared/stat_comparison.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")
const METRICS := {
	"spawn_count": ["Enemies", ""],
	"total_spawn_health": ["Total health", ""],
	"total_defeat_gold": ["Defeat gold", ""],
	"completion_gold": ["Wave gold", ""],
	"last_spawn_seconds": ["Last spawn", " s"],
}

static func content(report: Dictionary) -> VBoxContainer:
	var body := column()
	body.name = "WaveBalanceDetails"
	var groups := column()
	groups.name = "SpawnGroups"
	body.add_child(groups)
	for index in report.groups.size():
		var group_card := spawn_card(report.groups[index])
		group_card.name = "SpawnGroup%d" % index
		groups.add_child(group_card)
	var changes: Dictionary = report.changes_from_previous_wave
	var summary := column()
	var summary_card := UI.info_card(summary, UI.SURFACE, UI.CARD_PADDING)
	summary_card.name = "WaveChanges"
	body.add_child(summary_card)
	summary.add_child(UI.heading("Changes from wave %d" % (report.wave - 1) if report.wave > 1 else "Opening wave", 18))
	if report.wave == 1:
		summary.add_child(UI.paragraph("These are the level’s starting wave values. Later waves compare against the wave before them."))
		return body
	if changes.is_empty():
		summary.add_child(UI.paragraph("No changes from the previous wave."))
		return body
	var totals := grid()
	totals.name = "WaveTotalChanges"
	for key: String in METRICS:
		if changes.has(key):
			var tile := Comparison.card(METRICS[key][0], changes[key], METRICS[key][1])
			tile.name = "Change_" + key
			totals.add_child(tile)
	if totals.get_child_count() > 0:
		summary.add_child(totals)
	else:
		totals.free()
	if changes.has("enemy_counts"):
		var roster := column()
		roster.name = "EnemyCountChanges"
		roster.add_child(UI.heading("Enemy composition", UI.BODY))
		for kind: String in changes.enemy_counts:
			var change: Dictionary = changes.enemy_counts[kind]
			roster.add_child(WaveSummary.enemy_row(kind, int(change.after), "Was %d · %s" % [change.before, Comparison.signed(change.delta)]))
		summary.add_child(roster)
	if changes.has("spawn_groups"):
		summary.add_child(UI.paragraph("Composition or spawn settings changed. Exports include both waves."))
	for category: String in changes.get("effective_stats", {}):
		for kind: String in changes.effective_stats[category]:
			body.add_child(tuning_card(category, kind, changes.effective_stats[category][kind]))
	return body

static func spawn_card(group: Dictionary) -> PanelContainer:
	var body := column()
	var identity := WaveSummary.enemy_identity(group.kind, int(group.count), "Lane %s · Starts at %s s" % [String.chr(65 + int(group.lane)), UI.exact_money(group.delay_seconds)])
	body.add_child(identity)
	body.add_child(UI.rule())
	var stats := grid()
	stats.name = "SpawnStats"
	body.add_child(stats)
	for metric in [["Health / enemy", group.spawn_health, ""], ["Speed", group.move_speed, " / s"], ["Gold / defeat", group.gold_per_defeat, ""], ["Spawn interval", group.interval_seconds, " s"]]:
		stats.add_child(UI.info_card(UI.stat(metric[0], Comparison.number(metric[1], metric[2]))))
	return UI.info_card(body, UI.SURFACE, UI.CARD_PADDING)

static func tuning_card(category: String, kind: String, changes: Dictionary) -> PanelContainer:
	var body := column()
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", UI.CARD_GAP)
	var art := Portrait.preview(category, kind)
	art.custom_minimum_size = Vector2(48, 48)
	identity.add_child(art)
	var title := UI.stat("Stat changes", str(Balance.definition(category, kind).name))
	identity.add_child(title)
	body.add_child(identity)
	body.add_child(UI.rule())
	var stats := grid()
	body.add_child(stats)
	for field: String in changes:
		var limits := Balance.field_limits(category, kind, field)
		var tile := Comparison.card(limits.label, changes[field], limits.get("suffix", ""))
		tile.name = "TuningChange_" + field
		stats.add_child(tile)
	var panel := UI.info_card(body, UI.SURFACE, UI.CARD_PADDING)
	panel.name = "TuningChanges_" + category + "_" + kind
	return panel

static func column() -> VBoxContainer:
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UI.GAP)
	return body

static func grid() -> GridContainer:
	var stats := GridContainer.new()
	stats.columns = 2
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("h_separation", UI.CARD_GAP)
	stats.add_theme_constant_override("v_separation", UI.CARD_GAP)
	stats.resized.connect(func():
		var count := stats.get_child_count()
		stats.columns = maxi(1, count) if count <= 1 or (count <= 4 and stats.size.x >= 400) else 2
	)
	return stats
