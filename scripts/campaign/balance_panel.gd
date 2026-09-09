extends VBoxContainer
## Immediate-save wave composition; persistence belongs to the campaign owner.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Editor = preload("res://scripts/campaign/wave_editor.gd")
const Fields = preload("res://scripts/content/catalogs/levels.gd")
const Picker = preload("res://scripts/ui/shared/illustrated_picker.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")
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
var saving := false
var committed := {}

func _ready() -> void:
	name = "CampaignBalancePanel"
	add_theme_constant_override("separation", UI.GAP)
	draft = store.overrides(index).duplicate(true)
	committed = draft.duplicate(true)
	scope = initial_scope
	add_child(UI.paragraph("Level %d · %s" % [index + 1, Configuration.Catalog.level(index).name], 16))
	add_child(UI.paragraph("Changes save when you finish entering a value or choose an option. Empty waves are skipped during play. Reset wave restores its defaults."))
	message = UI.paragraph("Changes save automatically.")
	add_child(message)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", UI.GAP)
	add_child(body)
	build_scope()

func number_row(title: String, value: float, limits: Dictionary, change: Callable) -> SpinBox:
	var number := SpinBox.new()
	number.min_value = limits.min
	number.max_value = limits.max
	number.step = limits.step
	number.value = value
	number.accessibility_name = title
	numbers.append(number)
	body.add_child(UI.number_row(title, number))
	if limits.get("integer", false): number.get_line_edit().virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	number.value_changed.connect(func(amount: float):
		change.call(amount)
		save_changes()
	)
	return number

func build_scope() -> void:
	numbers.clear()
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if live_run != null and live_run.phase == "wave":
		body.add_child(UI.paragraph("Wave editing is locked until the active wave ends."))
		return
	var mission := Configuration.resolve(index, draft)
	if scope < 0 or scope >= mission.waves.size(): return
	if not draft.has("waves"): draft.waves = {}
	if not draft.waves.has(str(scope)): draft.waves[str(scope)] = {}
	var wave_override: Dictionary = draft.waves[str(scope)]
	var reward := number_row("Wave completion gold", mission.wave_rules[scope].reward, Fields.CONFIGURATION_FIELDS.reward, func(value: float): wave_override.reward = value)
	reward.name = "CampaignWaveReward"
	groups = mission.waves[scope].duplicate(true)
	build_groups(mission)
	var reset := UI.button("Reset wave to default", func():
		draft = Editor.reset_wave(index, committed, scope)
		groups = draft.waves[str(scope)].groups.duplicate(true)
		save_changes()
		build_scope.call_deferred()
	)
	reset.name = "ResetCampaignWave"
	body.add_child(reset)

func enemy_picker(title: String) -> Button:
	var selector := Picker.new()
	selector.menu_title = title
	selector.preview_factory = func(kind: String): return Portrait.preview("bosses" if Balance.BOSSES.has(kind) else "enemies", kind)
	for kind in Configuration.spawn_kinds():
		var category := "bosses" if Balance.BOSSES.has(kind) else "enemies"
		selector.add_item(Balance.definitions(category)[kind].name)
		selector.set_item_metadata(selector.item_count - 1, kind)
	return selector

func build_groups(mission: Dictionary) -> void:
	body.add_child(UI.heading("Enemies and entrances", 18))
	if groups.is_empty(): body.add_child(UI.paragraph("No enemies yet. Add an enemy to populate this wave."))
	for group_index in groups.size():
		var group: Array = groups[group_index]
		body.add_child(UI.rule())
		var selector := enemy_picker("Choose enemy")
		selector.name = "CampaignGroupKind" + str(group_index)
		for item in selector.item_count:
			if selector.get_item_metadata(item) == group[0]: selector.select(item)
		selector.item_selected.connect(func(item: int):
			group[0] = selector.get_item_metadata(item)
			save_changes()
			build_scope.call_deferred()
		)
		var identity := HBoxContainer.new()
		identity.add_theme_constant_override("separation", UI.CARD_GAP)
		var portrait := Portrait.preview("bosses" if Balance.BOSSES.has(group[0]) else "enemies", group[0])
		portrait.custom_minimum_size = Vector2(48, 48)
		identity.add_child(portrait)
		identity.add_child(selector)
		body.add_child(identity)
		var limits: Dictionary = Fields.GROUP_FIELDS[1].duplicate()
		limits.min = 0
		var count := number_row("Enemy count · 0 removes", group[1], limits, func(value: float):
			group[1] = value
			if value == 0:
				groups.erase(group)
				build_scope.call_deferred()
		)
		count.name = "CampaignGroup%d_1" % group_index
		var portal := Picker.new()
		portal.name = "CampaignGroupPortal%d" % group_index
		portal.menu_title = "Choose entrance portal"
		for lane in mission.routes.size(): portal.add_item("Portal " + String.chr(65 + lane))
		portal.select(int(group[2]))
		portal.item_selected.connect(func(lane: int): group[2] = lane; save_changes())
		body.add_child(portal)
		for column in [3, 4]:
			var input := number_row(Fields.GROUP_FIELDS[column].label, group[column], Fields.GROUP_FIELDS[column], func(value: float): group[column] = value)
			input.name = "CampaignGroup%d_%d" % [group_index, column]
		var category := "bosses" if Balance.BOSSES.has(group[0]) else "enemies"
		var kind: String = group[0]
		var payout := number_row("Gold per defeated enemy", group[5] if group.size() == 6 else Balance.definition(category, kind, mission.wave_rules[scope].tuning).payout,
			Fields.CONFIGURATION_FIELDS.reward, func(value: float):
				if group.size() == 5: group.append(value)
				else: group[5] = value
		)
		payout.name = "CampaignGroupGold%d" % group_index
		body.add_child(UI.button("Remove this enemy group", func():
			groups.remove_at(group_index)
			save_changes()
			build_scope.call_deferred()
		))
	var add := enemy_picker("Add enemies")
	add.name = "AddWaveEnemies"
	add.text = "Add enemies"
	add.disabled = groups.size() >= 32
	add.item_selected.connect(func(item: int):
		groups.append(Editor.default_group(index, add.get_item_metadata(item)))
		save_changes()
		build_scope.call_deferred()
	)
	body.add_child(add)
	body.add_child(UI.paragraph("Add the same enemy again to use another portal, spawn time or gold reward. Up to 32 groups, 1,000 enemies per group and 5,000 per wave."))

func commit_scope() -> void:
	draft.waves[str(scope)].groups = groups.duplicate(true)

func finish_editing() -> void:
	for number in numbers.duplicate():
		if is_instance_valid(number): number.apply()

func show_message(text: String) -> void:
	message.text = text
	message.visible = not text.is_empty()

func save_changes() -> void:
	if saving: return
	saving = true
	commit_scope()
	var ok: bool = apply_changes.call(index, draft) if apply_changes.is_valid() else store.save_level(index, draft)
	if ok:
		committed = draft.duplicate(true)
		show_message("Saved")
		saved.emit()
	else:
		draft = committed.duplicate(true)
		show_message("Couldn't save this change. Keep at least one enemy in the level and stay within the wave limits. Your previous settings are preserved.")
		build_scope.call_deferred()
	saving = false
