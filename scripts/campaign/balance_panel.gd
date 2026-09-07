extends VBoxContainer
## A wave draft owns composition, timing and rewards; content stats belong to Edit rules.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Fields = preload("res://scripts/content/catalogs/levels.gd")
const Picker = preload("res://scripts/ui/shared/illustrated_picker.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")
signal export_requested
signal saved
var store: RefCounted
var index := 0
var draft := {}
var scope := 0
var body: VBoxContainer
var numbers: Array[SpinBox] = []
var message: Label
var groups: Array = []
var live_run: RefCounted
var initial_scope := 0
var apply_changes: Callable
var shared_page := false

func _ready() -> void:
	name = "CampaignBalancePanel"
	add_theme_constant_override("separation", 12)
	draft = store.overrides(index)
	scope = initial_scope
	add_child(UI.paragraph("Level %d · %s" % [index + 1, Configuration.Catalog.level(index).name], 16))
	add_child(UI.paragraph("Existing enemies stay on the field; pending spawns use the new settings. Times are measured from the wave's start." if live_run != null else "Changes stay in this draft until you apply them.", 14))
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	message = UI.paragraph("", 14)
	message.hide()
	add_child(message)
	var save := UI.gold_button("Apply wave changes", save_changes)
	save.name = "SaveCampaignConfiguration"
	add_child(save)
	save.visible = not shared_page
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
	var mission := Configuration.resolve(index, draft)
	if not draft.has("waves"): draft.waves = {}
	if not draft.waves.has(str(scope)): draft.waves[str(scope)] = {}
	var wave_override: Dictionary = draft.waves[str(scope)]
	var reward := number_row("Wave completion gold", mission.wave_rules[scope].reward, Fields.CONFIGURATION_FIELDS.reward, func(value: float): wave_override.reward = value)
	reward.name = "CampaignWaveReward"
	groups = mission.waves[scope].duplicate(true)
	build_groups()

func build_groups() -> void:
	body.add_child(UI.heading("Wave spawn groups", 18))
	for group_index in groups.size():
		var group: Array = groups[group_index]
		body.add_child(UI.heading("Group %d" % (group_index + 1), 16))
		var selector := Picker.new()
		selector.menu_title = "Choose spawn type"
		selector.preview_factory = func(kind: String):
			return Portrait.preview("bosses" if Balance.BOSSES.has(kind) else "enemies", kind)
		selector.custom_minimum_size.y = UI.TARGET
		selector.name = "CampaignGroupKind" + str(group_index)
		for kind in Configuration.spawn_kinds():
			var category := "bosses" if Balance.BOSSES.has(kind) else "enemies"
			selector.add_item(Balance.definitions(category)[kind].name)
			selector.set_item_metadata(selector.item_count - 1, kind)
			if kind == group[0]: selector.select(selector.item_count - 1)
		selector.item_selected.connect(func(item: int): group[0] = selector.get_item_metadata(item))
		body.add_child(selector)
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
	draft.waves[str(scope)].groups = groups.duplicate(true)

func show_message(text: String) -> void:
	message.text = text
	message.visible = not text.is_empty()

func save_changes() -> void:
	commit_scope()
	var ok: bool = apply_changes.call(index, draft) if apply_changes.is_valid() else store.save_level(index, draft)
	if ok:
		show_message("Wave changes saved.")
		saved.emit()
	else:
		show_message(store.last_error)
