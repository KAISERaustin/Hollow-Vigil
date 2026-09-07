extends ColorRect

const UI = preload("res://scripts/ui/shared/interface.gd")
const Catalog = preload("res://scripts/campaign/catalog.gd")
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Progress = preload("res://scripts/campaign/progress.gd")
const Board = preload("res://scripts/campaign/board.gd")
const WorldMap = preload("res://scripts/campaign/world_map.gd")
const TowerChoice = preload("res://scripts/ui/towers/tower_choice.gd")
signal closed
var app: VigilApp
var progress := Progress.new()
var configuration := Configuration.new()
var run: RefCounted
var layout: VBoxContainer
var page_scroll: ScrollContainer
var board: Control
var status: Label
var gold: Label
var wave_button: Button
var pause_button: Button
var speed_button: Button
var page := "map"
var paused := false
var speed := 1.0
var accumulator := 0.0
var observed_phase := ""
var dialog: ColorRect
var dialog_card: PanelContainer
var dialog_body: VBoxContainer
var dialog_title: Label
var save_notice: Label
var socket_dialog := false
var waves_dialog := false
var shared_setups: Dictionary = {}
var configuration_picker: Node
var active_overrides: Dictionary = {}

# Host the same tower components against the mission state.
var game: VigilState:
	get: return run.game
var field: Battlefield:
	get: return board
var panels: Control:
	get: return self
var tower_actions: VigilTowerActions
var tower_dialog: VigilTowerDialog
var tower_move: PanelContainer
var selection_region := ""
var selection_pad := -1
var selection_tower := ""

func persist() -> void:
	save_progress()
	refresh()

func toast(message: String) -> void:
	app.toast(message)

func collection_effect(amount: float) -> void:
	toast("Collected %s gold" % UI.exact_money(amount))

func close_sheet() -> void:
	clear_selection()

func clear_selection() -> void:
	if is_instance_valid(dialog) and socket_dialog:
		dialog.hide()
	if is_instance_valid(tower_dialog) and tower_dialog.visible:
		tower_dialog.dismiss(false)
	if is_instance_valid(tower_move):
		tower_move.cancel()
	if is_instance_valid(board):
		board.clear_selection()
	selection_region = ""
	selection_pad = -1
	selection_tower = ""
	if is_instance_valid(tower_actions):
		tower_actions.blocked = false
		tower_actions.refresh()

func show_tower() -> void:
	for socket in run.mission.sockets:
		if socket.region == selection_region and socket.pad == selection_pad:
			show_socket(socket.index)
			return

func clear_tower_ui() -> void:
	for control in [tower_dialog, tower_move, tower_actions]:
		if is_instance_valid(control):
			control.get_parent().remove_child(control)
			control.queue_free()
	tower_dialog = null
	tower_move = null
	tower_actions = null

func build_tower_ui() -> void:
	tower_actions = VigilTowerActions.new()
	tower_actions.field = board
	board.add_child(tower_actions)
	tower_actions.upgraded.connect(persist)
	tower_dialog = VigilTowerDialog.new()
	tower_dialog.app = self
	tower_dialog.z_index = 102
	add_child(tower_dialog)
	tower_actions.action_requested.connect(tower_dialog.open_action)
	tower_move = preload("res://scripts/ui/towers/tower_move.gd").new()
	tower_move.app = self
	board.add_child(tower_move)

func _ready() -> void:
	name = "Campaign"
	color = UI.PANEL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.fullscreen_parchment())
	theme = UI.theme()
	progress.load_progress()
	if is_instance_valid(app) and not app.load_saved_progress:
		configuration.path = app.game.save_path + ".campaign-configuration-test"
	configuration.load_configuration()
	layout = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 12
	layout.offset_top = 12
	layout.offset_right = -12
	layout.offset_bottom = -12
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	page_scroll = ScrollContainer.new()
	page_scroll.name = "CampaignPageScroll"
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.follow_focus = true
	UI.keyboard_scroll(page_scroll, "Campaign menus")
	add_child(page_scroll)
	resized.connect(fit)
	_build_dialog()
	show_map()
	fit()

func fit() -> void:
	var safe := UI.safe_rect(self).grow(-12)
	if page == "battle":
		layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layout.offset_left = safe.position.x
		layout.offset_top = safe.position.y
		layout.offset_right = safe.end.x - size.x
		layout.offset_bottom = safe.end.y - size.y
	else:
		page_scroll.position = safe.position
		page_scroll.size = safe.size
	if is_instance_valid(dialog_card):
		if not socket_dialog:
			dialog_card.size.x = minf(470, safe.size.x)
			# Fit every modal to its wrapped content; overflow stays scrollable.
			dialog_card.size.y = minf(safe.size.y, dialog_card.get_combined_minimum_size().y + dialog_body.get_combined_minimum_size().y)
		if socket_dialog:
			var bounds := safe
			if is_instance_valid(board) and board.size.x > 16 and board.size.y > 16:
				bounds = Rect2(board.global_position - global_position, board.size).grow(-8).intersection(safe)
			dialog_card.size = Vector2(minf(470, bounds.size.x), minf(340, bounds.size.y))
			dialog_card.position = Vector2(bounds.get_center().x - dialog_card.size.x * 0.5, bounds.end.y - dialog_card.size.y)
		else:
			dialog_card.position = safe.position + (safe.size - dialog_card.size) * 0.5

func clear_page(next: String) -> void:
	clear_selection()
	clear_tower_ui()
	page = next
	board = null
	for child in layout.get_children():
		layout.remove_child(child)
		child.queue_free()
	var parent: Node = self if next == "battle" else page_scroll
	if layout.get_parent() != parent:
		layout.reparent(parent, false)
		layout.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.visible = next != "battle"
	page_scroll.set_deferred("scroll_vertical", 0)
	fit()
	dialog.hide()
	accumulator = 0.0

func header(title: String, back: Callable, button_size: float = 48) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	layout.add_child(row)
	var button := UI.button("←", back, button_size)
	button.name = "CampaignBack"
	button.custom_minimum_size.x = button_size
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.accessibility_name = "Back"
	row.add_child(button)
	var caption := UI.heading(title, 24)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(caption)
	return row

func show_map() -> void:
	if run != null and page == "battle":
		save_progress()
	clear_page("map")
	header("The Last Procession", close)
	var cleared := int(progress.data.completed_levels)
	layout.add_child(UI.paragraph("%d / %d levels completed" % [cleared, Catalog.COUNT], 13))
	var world := WorldMap.new()
	world.progress = progress
	world.level_picked.connect(show_briefing)
	layout.add_child(world)
	if cleared < Catalog.COUNT and not progress.blocked:
		var next := UI.gold_button("Play level %d" % (cleared + 1), start_mission.bind(cleared), 48)
		next.name = "ContinueCampaign"
		layout.add_child(next)
	var balancing := UI.button("Campaign balancing", show_balancing_levels)
	balancing.name = "CampaignBalancing"
	layout.add_child(balancing)
	var reset := UI.button("Reset campaign progress", confirm_progress_reset)
	reset.name = "ResetCampaignProgress"
	layout.add_child(reset)
	var backups := UI.button("Account & backups", func(): app.show_backups())
	backups.name = "CampaignBackups"
	layout.add_child(backups)
	save_notice = UI.paragraph(progress.last_error, 12)
	save_notice.visible = not progress.last_error.is_empty()
	layout.add_child(save_notice)
	if cleared == 20:
		layout.add_child(UI.paragraph("Dawn reaches the capital. Every sanctuary burns again. Replay any level to perfect your vigil.", 15))

func show_briefing(index: int) -> void:
	if not progress.unlocked(index):
		return
	clear_page("briefing")
	run = configured_run(index)
	header("%02d · %s" % [index+1, run.mission.name], show_map)
	layout.add_child(UI.paragraph(Catalog.CHAPTERS[int(index / 5.0)].story, 14))
	add_board(false)
	layout.add_child(UI.paragraph(run.mission.brief, 15))
	layout.add_child(UI.paragraph("%d waves  ·  %s starting gold  ·  %d flame" % [run.mission.waves.size(), UI.exact_money(run.mission.gold), run.mission.flame], 13))
	var details := UI.button("Preview waves", show_waves, 48)
	layout.add_child(details)
	var sources := HBoxContainer.new()
	layout.add_child(sources)
	for kind in ["campaign_build", "campaign_stats"]:
		var choose := UI.button("My builds" if kind == "campaign_build" else "Stats", show_configuration_picker.bind(index, kind))
		choose.name = "CampaignChooseBuild" if kind == "campaign_build" else "CampaignChooseStats"
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sources.add_child(choose)
	if shared_setups.has(index):
		layout.add_child(UI.paragraph(shared_setups[index].setup.name + "\n" + shared_setups[index].setup.description, 14))
		layout.add_child(UI.button("Use my level defaults", func():
			shared_setups.erase(index)
			show_briefing(index)
		))
	var start := UI.gold_button("Begin mission", start_mission.bind(index), 50)
	start.name = "BeginCampaignMission"
	layout.add_child(start)

func start_mission(index: int) -> void:
	if not progress.unlocked(index):
		return
	run = configured_run(index)
	connect_run()
	show_battle()
	save_progress()

func connect_run() -> void:
	run.changed.connect(func():
		if page == "battle":
			refresh()
			if run.phase == "planning":
				save_progress()
	)
	run.finished.connect(show_result)
	if is_instance_valid(app) and is_instance_valid(app.audio):
		run.game.combat.sound_requested.connect(play_combat_sound)
		run.game.economy.sound_requested.connect(play_run_sound)

func combat_audio_active() -> bool:
	return page == "battle" and run != null and run.phase == "wave" and not paused

func play_combat_sound(cue: String, sound_position: Vector2) -> void:
	if is_visible_in_tree() and is_instance_valid(board):
		# Combat voices expire with playback; planning transactions remain audible.
		app.audio.play(cue, sound_position, board, combat_audio_active)

func play_run_sound(cue: String, sound_position: Vector2) -> void:
	if page == "battle" and is_visible_in_tree() and is_instance_valid(board):
		app.audio.play(cue, sound_position, board)

func show_battle() -> void:
	clear_page("battle")
	paused = false
	observed_phase = run.phase
	var title_row := header("%02d · %s" % [run.mission.index+1,run.mission.name], show_map, UI.TOOLBAR_BUTTON_SIZE)
	pause_button = UI.playback_button(func():
		paused = not paused
		update_time_controls()
	)
	pause_button.name = "CampaignPause"
	title_row.add_child(pause_button)
	speed_button = UI.playback_button(func():
		speed = 1.0 if speed == 2.0 else 2.0
		update_time_controls()
	, true)
	speed_button.toggle_mode = true
	speed_button.name = "CampaignSpeed"
	title_row.add_child(speed_button)
	update_time_controls()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	layout.add_child(row)
	gold = UI.value("", 21)
	gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gold)
	status = UI.paragraph("", 14)
	status.name = "CampaignStatus"
	layout.add_child(status)
	add_board(true)
	build_tower_ui()
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	layout.add_child(controls)
	var waves := UI.button("Waves", show_waves, 48)
	waves.name = "CampaignWaves"
	waves.custom_minimum_size.x = 80
	waves.size_flags_horizontal = Control.SIZE_FILL
	controls.add_child(waves)
	var share := UI.button("Share", show_campaign_share.bind(index_for_run()))
	share.name = "ShareCampaignConfiguration"
	controls.add_child(share)
	wave_button = UI.gold_button("", begin_wave, 48)
	wave_button.name = "StartCampaignWave"
	controls.add_child(wave_button)
	save_notice = UI.paragraph("", 12)
	save_notice.hide()
	layout.add_child(save_notice)
	refresh()

func add_board(interactive: bool) -> void:
	board = Board.new()
	board.resized.connect(func(): call_deferred("fit"))
	board.name = "CampaignBattlefield"
	board.run = run
	board.interactive = interactive
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size.y = 140 if interactive else 240
	board.socket_picked.connect(show_socket)
	board.empty_picked.connect(func():
		clear_selection()
		if socket_dialog:
			dialog.hide()
	)
	layout.add_child(board)
	var frame := UI.rounded_viewport_frame(UI.PANEL, 3)
	frame.name = "CampaignMapBorder"
	frame.z_index = 100
	board.add_child(frame)

func begin_wave() -> void:
	if run.start_wave():
		paused = false
		update_time_controls()
		save_progress()
		refresh()

func update_time_controls() -> void:
	pause_button.set_meta("paused", paused)
	pause_button.accessibility_description = "Play" if paused else "Pause"
	pause_button.accessibility_name = pause_button.accessibility_description
	pause_button.queue_redraw()
	speed_button.set_pressed_no_signal(speed == 2.0)
	speed_button.accessibility_description = "Return to normal speed" if speed == 2.0 else "Double game speed"
	speed_button.accessibility_name = speed_button.accessibility_description

func refresh() -> void:
	if page != "battle":
		return
	gold.text = "%s gold" % Balance.money(run.game.data.balance)
	var shown_wave := mini(run.wave+1, run.mission.waves.size())
	status.text = "Flame %d / %d   ·   Wave %d / %d%s" % [run.health, run.mission.flame, shown_wave, run.mission.waves.size(), " · Prepare" if run.phase == "planning" else ""]
	wave_button.disabled = run.phase != "planning"
	wave_button.text = "Start wave %d" % (run.wave+1) if run.phase == "planning" else "%d enemies remaining" % (run.game.combat.enemies.size() + run.schedule.size() - run.next_spawn)
	if run.phase in ["victory", "defeat"]:
		wave_button.text = "Sanctuary restored" if run.phase == "victory" else "The flame went out"
	if observed_phase != run.phase:
		observed_phase = run.phase
		clear_selection()
	elif board.selected_tower != "" and not run.game.data.towers.has(board.selected_tower):
		clear_selection()
	if is_instance_valid(tower_dialog):
		tower_dialog.refresh()
	board.simulation_rate = speed
	board.update_view(0, accumulator)

func save_progress() -> void:
	if run == null:
		return
	var ok: bool = progress.save_run(run)
	if is_instance_valid(save_notice) and not ok:
		save_notice.text = progress.last_error
		save_notice.show()

func show_waves() -> void:
	open_dialog("Waves")
	waves_dialog = true
	dialog.z_index = 101
	fit()
	var preview := VBoxContainer.new()
	preview.add_theme_constant_override("separation", 4)
	dialog_body.add_child(preview)
	var reports := Configuration.wave_reports(run.mission)
	for index in range(run.mission.waves.size()):
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 2)
		preview.add_child(section)
		section.add_child(UI.heading("Wave %d%s" % [index+1, " · Cleared" if index < run.wave else ""], 16))
		var report: Dictionary = reports[index]
		section.add_child(UI.paragraph("%d enemies · %s total health · %s wave gold · Last spawn %.2fs" % [report.spawn_count, UI.exact_money(report.total_spawn_health), UI.exact_money(report.completion_gold), report.last_spawn_seconds], 13))
		if index > 0:
			var previous: Dictionary = reports[index - 1]
			section.add_child(UI.paragraph("From previous wave: %+d enemies · %+.2f total health · %+.2f completion gold" % [report.spawn_count - previous.spawn_count, report.total_spawn_health - previous.total_spawn_health, report.completion_gold - previous.completion_gold], 13))
		section.add_child(UI.button("Wave %d balancing details" % (index + 1), show_wave_balance.bind(index)))
		var counts := {}
		for group in run.mission.waves[index]:
			counts[group[0]] = int(counts.get(group[0], 0)) + int(group[1])
		for kind in counts:
			var definitions: Dictionary = Balance.BOSSES if Balance.BOSSES.has(kind) else Balance.ENEMIES
			var enemy: Dictionary = definitions[kind]
			var role: String = str(enemy.get("role", "Boss")).split(" · ")[-1].capitalize()
			section.add_child(UI.paragraph("%d %s · %s" % [counts[kind], enemy.name, role], 14))
	if run.mission.waves.size() <= 3:
		preview.add_child(UI.rule())
		var described: Array[String] = []
		for wave in run.mission.waves:
			for group in wave:
				if group[0] in described:
					continue
				described.append(group[0])
				var definitions: Dictionary = Balance.BOSSES if Balance.BOSSES.has(group[0]) else Balance.ENEMIES
				var enemy: Dictionary = definitions[group[0]]
				preview.add_child(UI.paragraph("%s: %s." % [enemy.name, str(enemy.get("description", enemy.get("weakness", "Boss"))).get_slice(".", 0)], 14))

func show_socket(socket: int) -> void:
	if not run.editable() or not Balance.Content.level(run.mission.index).allows_socket(socket):
		return
	if board.moving_tower != "":
		var destination := Catalog.socket(socket)
		tower_move.place(destination.region, destination.pad)
		return
	clear_selection()
	board.select_socket(socket)
	var id: String = run.tower_at(socket)
	if not id.is_empty():
		dialog.hide()
		tower_actions.blocked = false
		tower_actions.refresh()
		return
	open_dialog("Build a tower", true)
	for kind in Balance.TOWERS:
		var stats := Balance.definition("towers", kind, run.game.tuning)
		var button := TowerChoice.create(kind, stats.name, stats.cost, func():
			if run.build(socket, kind):
				board.select_socket(socket)
				dialog.hide()
		)
		button.name = "CampaignBuild_" + kind
		button.disabled = run.game.data.balance < stats.cost
		dialog_body.add_child(button)

func show_result() -> void:
	clear_selection()
	save_progress()
	var won: bool = run.phase == "victory"
	open_dialog("Sanctuary restored" if won else "The flame went out")
	if won:
		dialog_body.add_child(UI.paragraph("%d flame remains. Level completed. Your progress is saved on this device." % run.health,15))
		if run.mission.index == 19:
			dialog_body.add_child(UI.paragraph("The Prior falls. Across the kingdom, twenty sanctuaries answer the last flame. For the first time in an age, the capital sees dawn.",18))
		else:
			var next := UI.gold_button("Next level", start_mission.bind(run.mission.index+1),48)
			next.name = "NextCampaignLevel"
			dialog_body.add_child(next)
	else:
		dialog_body.add_child(UI.paragraph("Restart this level with its original gold and flame. Previously completed levels remain saved.",15))
	dialog_body.add_child(UI.button("Restart level", start_mission.bind(run.mission.index),48))
	dialog_body.add_child(UI.button("World map",show_map,48))
	if not progress.last_error.is_empty():
		dialog_body.add_child(UI.paragraph(progress.last_error,14))

func _build_dialog() -> void:
	dialog = ColorRect.new()
	dialog.z_index = 101
	dialog.color = Color(0.03,0.04,0.05,0.8)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dialog)
	dialog_card = PanelContainer.new()
	dialog_card.minimum_size_changed.connect(func(): call_deferred("fit"))
	dialog_card.add_theme_stylebox_override("panel",UI.surface(UI.PANEL,3,16))
	dialog.add_child(dialog_card)
	var content := UI.margin(dialog_card,14)
	content.add_theme_constant_override("separation",10)
	var row := HBoxContainer.new()
	content.add_child(row)
	dialog_title = UI.heading("",22)
	dialog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dialog_title)
	var close_button := UI.button("×", close_dialog,48)
	close_button.name = "CloseCampaignDialog"
	close_button.accessibility_name = "Close and return to campaign"
	close_button.custom_minimum_size.x = 48
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(close_button)
	var scroll := ScrollContainer.new()
	scroll.name = "CampaignDialogScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	UI.keyboard_scroll(scroll,"Campaign details")
	content.add_child(scroll)
	dialog_body = VBoxContainer.new()
	dialog_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_body.add_theme_constant_override("separation",12)
	scroll.add_child(dialog_body)
	dialog_body.minimum_size_changed.connect(func():
		if dialog.visible:
			fit.call_deferred()
	)
	dialog.hide()

func close_dialog() -> void:
	dialog.hide()
	clear_selection()

func open_dialog(title: String, for_socket: bool = false) -> void:
	if not for_socket:
		clear_selection()
	waves_dialog = false
	dialog.z_index = 101
	socket_dialog = for_socket
	dialog_card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 3, 0 if for_socket else 16))
	dialog_body.add_theme_constant_override("separation", 6 if for_socket else 12)
	dialog.color = Color(0, 0, 0, 0) if for_socket else Color(0.03, 0.04, 0.05, 0.8)
	dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE if for_socket else Control.MOUSE_FILTER_STOP
	for child in dialog_body.get_children():
		dialog_body.remove_child(child)
		child.queue_free()
	dialog_title.text = title
	(dialog_body.get_parent() as ScrollContainer).scroll_vertical = 0
	dialog.show()
	dialog.move_to_front()
	fit()

func _process(delta: float) -> void:
	# Only the player's playback control pauses an active battle; overlays do not.
	if page != "battle" or run == null or paused:
		return
	accumulator += minf(delta,0.1) * speed
	while accumulator >= Balance.STEP:
		run.tick(Balance.STEP)
		accumulator -= Balance.STEP
	refresh()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if page == "battle":
			save_progress()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and page == "battle":
		save_progress()

func go_back() -> void:
	if is_instance_valid(app.slot_menu) and app.slot_menu.visible:
		var back: Button = app.slot_menu.find_child("BackButton", true, false)
		if back != null: back.pressed.emit()
		return
	if is_instance_valid(tower_dialog) and tower_dialog.visible:
		tower_dialog.dismiss()
	elif is_instance_valid(tower_move) and tower_move.visible:
		tower_move.cancel()
	elif dialog.visible:
		close_dialog()
	elif page != "map":
		show_map()
	else:
		close()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()

func close() -> void:
	clear_selection()
	if page == "battle":
		save_progress()
	closed.emit()
	queue_free()

func show_balancing_levels() -> void:
	open_dialog("Campaign balancing")
	for index in range(Catalog.COUNT):
		var choose := UI.button("%02d · %s" % [index + 1, Catalog.level(index).name], show_level_balance.bind(index))
		choose.name = "BalanceLevel" + str(index + 1)
		dialog_body.add_child(choose)

func show_level_balance(index: int) -> void:
	open_dialog("Level configuration")
	var editor := preload("res://scripts/campaign/balance_panel.gd").new()
	editor.store = configuration
	editor.index = index
	editor.export_requested.connect(show_level_export.bind(index))
	editor.saved.connect(func(): shared_setups.erase(index))
	dialog_body.add_child(editor)
	var share := UI.button("Save or share configuration", show_campaign_share.bind(index, true))
	share.name = "ShareSavedCampaignConfiguration"
	dialog_body.add_child(share)
	dialog_body.add_child(UI.button("Choose saved or community stats", show_configuration_picker.bind(index, "campaign_stats")))

func index_for_run() -> int:
	return int(run.mission.index)

func configured_run(index: int) -> RefCounted:
	active_overrides = shared_setups.get(index, {}).get("overrides", configuration.overrides(index)).duplicate(true)
	var next := Run.new(index, active_overrides)
	if shared_setups.has(index): VigilSaveSlots.CampaignBuild.apply_loadout(next, shared_setups[index])
	return next

func configuration_menu() -> Control:
	if not is_instance_valid(app.slot_menu):
		app.slot_menu = preload("res://scripts/ui/save_slots_panel.gd").new()
		app.slot_menu.app = app
		app.add_child(app.slot_menu)
	app.slot_menu.show()
	app.slot_menu.move_to_front()
	return app.slot_menu

func show_configuration_picker(index: int, kind: String) -> void:
	var was_paused := paused
	paused = true
	var menu := configuration_menu()
	if is_instance_valid(configuration_picker): configuration_picker.queue_free()
	configuration_picker = preload("res://scripts/ui/configuration_picker.gd").new()
	menu.add_child(configuration_picker)
	configuration_picker.menu = menu
	configuration_picker.kind = kind
	configuration_picker.level = index
	configuration_picker.back = func():
		menu.view_revision += 1
		menu.hide()
		paused = was_paused
	configuration_picker.create = func():
		menu.hide()
		paused = was_paused
		show_level_balance(index)
	configuration_picker.selected = func(entry: Dictionary):
		shared_setups[index] = VigilSaveSlots.CampaignBuild.decode(entry.code)
		menu.view_revision += 1
		menu.hide()
		show_briefing(index)
	configuration_picker.show_page()

func show_campaign_share(index: int, saved: bool = false) -> void:
	var was_paused := paused
	paused = true
	var source: RefCounted = Run.new(index, configuration.overrides(index)) if saved else run
	var rules: Dictionary = configuration.overrides(index) if saved else active_overrides
	var menu := configuration_menu()
	menu.show_export(source.game, {"level": index, "overrides": rules}, func():
		menu.view_revision += 1
		menu.hide()
		paused = was_paused
	)

func show_level_export(index: int) -> void:
	var code := Configuration.export_level(index, configuration.overrides(index))
	open_dialog("Level %d balancing export" % (index + 1))
	dialog_body.add_child(UI.paragraph("Saved configuration with defaults, effective statistics, wave schedules and changes. Copy the code to transfer or inspect it.", 14))
	var export_code := TextEdit.new()
	export_code.name = "CampaignExportCode"
	export_code.text = code
	export_code.editable = false
	export_code.custom_minimum_size.y = 220
	export_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	dialog_body.add_child(export_code)
	var copy := UI.button("Copy export code", func():
		DisplayServer.clipboard_set(code)
		toast("Campaign level export copied.")
	)
	copy.name = "CopyCampaignExport"
	dialog_body.add_child(copy)
	dialog_body.add_child(UI.button("Back to level configuration", show_level_balance.bind(index)))

func show_wave_balance(wave: int) -> void:
	var report := Configuration.wave_reports(run.mission)[wave]
	open_dialog("Wave %d balancing" % (wave + 1))
	for group in report.groups:
		dialog_body.add_child(UI.paragraph("%s × %d · Lane %s
Delay %.2fs · Interval %.2fs
Spawn health %.2f · Speed %.2f · Defeat gold %.2f" % [group.name, group.count, String.chr(65 + group.lane), group.delay_seconds, group.interval_seconds, group.spawn_health, group.move_speed, group.gold_per_defeat], 14))
	dialog_body.add_child(UI.heading("Changes from previous wave", 18))
	if wave == 0:
		dialog_body.add_child(UI.paragraph("Opening wave. These are the level's initial wave values.", 14))
	else:
		var changes: Dictionary = report.changes_from_previous_wave
		for key in changes:
			if key in ["effective_stats", "enemy_counts", "spawn_groups"]: continue
			var change: Dictionary = changes[key]
			dialog_body.add_child(UI.paragraph("%s: %.2f → %.2f (%+.2f)" % [key.replace("_", " ").capitalize(), change.before, change.after, change.delta], 14))
		if changes.has("spawn_groups"):
			dialog_body.add_child(UI.paragraph("Spawn composition, timing or lane assignments changed. Current groups are listed above; exports include both waves.", 14))
		for kind in changes.get("enemy_counts", {}):
			var change: Dictionary = changes.enemy_counts[kind]
			var name: String = Balance.definition("bosses" if Balance.BOSSES.has(kind) else "enemies", kind).name
			dialog_body.add_child(UI.paragraph("%s count: %d → %d (%+d)" % [name, change.before, change.after, change.delta], 14))
		for category in changes.get("effective_stats", {}):
			for kind in changes.effective_stats[category]:
				for stat in changes.effective_stats[category][kind]:
					var change: Dictionary = changes.effective_stats[category][kind][stat]
					dialog_body.add_child(UI.paragraph("%s · %s: %.2f → %.2f" % [Balance.definitions(category)[kind].name, Balance.field_limits(category, kind, stat).label, change.before, change.after], 14))
		if changes.is_empty(): dialog_body.add_child(UI.paragraph("No numeric changes from the previous wave.", 14))
	dialog_body.add_child(UI.button("Back to all waves", show_waves))

func confirm_progress_reset() -> void:
	var popup := preload("res://scripts/ui/shared/confirmation_popup.gd").new()
	popup.name = "CampaignResetConfirmation"
	add_child(popup)
	popup.configure("Reset campaign progress?", "Return to level 1 on this device. Your account, cloud backups, Infinite Worlds, equipment and balancing settings are kept.", "Reset progress", func():
		if not progress.reset_progress():
			popup.show_error(progress.last_error)
			return
		# Discard the old run before any navigation or focus event can save it.
		run = null
		popup.hide()
		show_map()
	)
