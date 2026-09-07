extends VBoxContainer
## Reuses the ordinary stat controls against an isolated configuration draft.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Fields = preload("res://scripts/content/catalogs/levels.gd")
const Controls = preload("res://scripts/ui/developer/developer_controls.gd")
signal export_requested
signal saved
var store: RefCounted
var index := 0
var draft := {}
var scope := -1
var scope_picker: OptionButton
var body: VBoxContainer
var controls: VBoxContainer
var editing_game: VigilState
var numbers: Array[SpinBox] = []
var message: Label
var inherited := {}
var groups: Array = []
var live_run: RefCounted
var initial_scope := -1
var apply_changes: Callable

func _ready() -> void:
	name = "CampaignBalancePanel"
	add_theme_constant_override("separation", 12)
	draft = store.overrides(index)
	add_child(UI.paragraph("Level %d · %s" % [index + 1, Configuration.Catalog.level(index).name], 16))
	add_child(UI.paragraph("Save applies rules to this run and future replays. Existing enemies stay on the field; pending spawns use the new settings. Times are measured from the wave's start. Starting gold and flame apply during initial setup or on restart." if live_run != null else "Save changes to use them next time this level starts.", 14))
	scope_picker = OptionButton.new()
	scope_picker.name = "CampaignBalanceScope"
	scope_picker.custom_minimum_size.y = UI.TARGET
	scope_picker.add_item("Level defaults")
	for wave in Configuration.Catalog.level(index).waves.size(): scope_picker.add_item("Wave %d overrides" % (wave + 1))
	scope = initial_scope
	scope_picker.select(scope + 1)
	scope_picker.item_selected.connect(func(selected: int):
		commit_scope()
		scope = selected - 1
		build_scope()
	)
	add_child(scope_picker)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	message = UI.paragraph("", 14)
	add_child(message)
	var save := UI.gold_button("Save level configuration", save_changes)
	save.name = "SaveCampaignConfiguration"
	add_child(save)
	var export_button := UI.button("Export saved level data", func(): export_requested.emit())
	export_button.name = "ExportCampaignLevel"
	add_child(export_button)
	var reset := UI.button("Restore level defaults", func():
		draft = {}
		scope = -1
		scope_picker.select(0)
		build_scope()
		message.text = "Default configuration ready. Save to apply it."
	)
	reset.name = "ResetCampaignConfiguration"
	add_child(reset)
	build_scope()

func number_row(title: String, value: float, limits: Dictionary, change: Callable) -> SpinBox:
	var number := SpinBox.new()
	number.min_value = limits.min
	number.max_value = limits.max
	number.step = limits.step
	number.value = value
	number.accessibility_name = title
	number.value_changed.connect(change)
	numbers.append(number)
	body.add_child(UI.number_row(title, number))
	return number

func build_scope() -> void:
	numbers.clear()
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var level := draft.duplicate(true)
	level.erase("waves")
	var level_mission := Configuration.resolve(index, level)
	var mission := Configuration.resolve(index, draft)
	inherited = Configuration.Catalog.level(index).tuning if scope < 0 else level_mission.tuning
	if scope < 0:
		for key in Fields.CONFIGURATION_FIELDS:
			var limits: Dictionary = Fields.CONFIGURATION_FIELDS[key]
			var number := number_row(limits.label, mission[key], limits, func(value: float): draft[key] = value)
			number.name = "Campaign_" + key
	else:
		if not draft.has("waves"): draft.waves = {}
		if not draft.waves.has(str(scope)): draft.waves[str(scope)] = {}
		var wave_override: Dictionary = draft.waves[str(scope)]
		var reward := number_row("Wave completion gold", mission.wave_rules[scope].reward, Fields.CONFIGURATION_FIELDS.reward, func(value: float): wave_override.reward = value)
		reward.name = "CampaignWaveReward"
		groups = mission.waves[scope].duplicate(true)
		build_groups()
	editing_game = VigilState.new(42, "creative", mission.tuning if scope < 0 else mission.wave_rules[scope].tuning)
	controls = Controls.new()
	controls.game = editing_game
	controls.categories.assign(Balance.TUNING_FIELDS.keys().filter(func(category): return category != "session"))
	controls.configuration_only = true
	body.add_child(controls)
	body.add_child(UI.button("All stat categories", controls.show_categories))

func build_groups() -> void:
	body.add_child(UI.heading("Wave spawn groups", 18))
	for group_index in groups.size():
		var group: Array = groups[group_index]
		body.add_child(UI.heading("Group %d" % (group_index + 1), 16))
		var selector := OptionButton.new()
		selector.custom_minimum_size.y = UI.TARGET
		selector.name = "CampaignGroupKind" + str(group_index)
		for kind in Configuration.spawn_kinds():
			var category := "bosses" if Balance.BOSSES.has(kind) else "enemies"
			selector.add_item(Balance.definitions(category)[kind].name)
			selector.set_item_metadata(selector.item_count - 1, kind)
			if kind == group[0]: selector.select(selector.item_count - 1)
		selector.item_selected.connect(func(item: int): group[0] = selector.get_item_metadata(item))
		body.add_child(selector)
		selector.get_popup().max_size = Vector2i(int(get_viewport_rect().size.x), mini(UI.TARGET * 6, int(get_viewport_rect().size.y)))
		for column in Fields.GROUP_FIELDS:
			var limits: Dictionary = Fields.GROUP_FIELDS[column].duplicate()
			if column == 2: limits.max = Configuration.Catalog.level(index).routes.size() - 1
			var input := number_row(limits.label, group[column], limits, func(value: float): group[column] = value)
			input.name = "CampaignGroup%d_%d" % [group_index, column]
		if groups.size() > 1 and not (live_run != null and live_run.phase == "wave" and live_run.wave == scope):
			body.add_child(UI.button("Remove group %d" % (group_index + 1), func():
				commit_scope()
				groups.remove_at(group_index)
				draft.waves[str(scope)].groups = groups.duplicate(true)
				build_scope()
			))
	var add := UI.button("Add spawn group", func():
		commit_scope()
		groups.append(groups[-1].duplicate(true))
		draft.waves[str(scope)].groups = groups.duplicate(true)
		build_scope()
	)
	add.disabled = groups.size() >= 32
	body.add_child(add)

func commit_scope() -> void:
	for number in numbers:
		if is_instance_valid(number): number.apply()
	controls.commit_fields()
	var tuning := Configuration.tuning_difference(inherited, editing_game.tuning)
	if scope < 0:
		draft.tuning = tuning
	else:
		draft.waves[str(scope)].tuning = tuning
		draft.waves[str(scope)].groups = groups.duplicate(true)

func save_changes() -> void:
	commit_scope()
	var ok: bool = apply_changes.call(index, draft) if apply_changes.is_valid() else store.save_level(index, draft)
	if ok:
		message.text = "Level configuration saved. Active rules updated." if live_run != null else "Level configuration saved."
		saved.emit()
	else:
		message.text = store.last_error
