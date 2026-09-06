extends ColorRect

const UI = preload("res://scripts/ui/shared/interface.gd")
const Catalog = preload("res://scripts/campaign/catalog.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Progress = preload("res://scripts/campaign/progress.gd")
const Board = preload("res://scripts/campaign/board.gd")
const WorldMap = preload("res://scripts/campaign/world_map.gd")
signal closed
var app: VigilApp
var progress := Progress.new()
var run: RefCounted
var layout: VBoxContainer
var board: Control
var status: Label
var gold: Label
var wave_button: Button
var pause_button: Button
var page := "map"
var paused := false
var speed := 1.0
var accumulator := 0.0
var selected := -1
var dialog: ColorRect
var dialog_card: PanelContainer
var dialog_body: VBoxContainer
var dialog_title: Label
var save_notice: Label
var socket_dialog := false

func _ready() -> void:
	name = "Campaign"
	color = UI.PANEL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	progress.load_progress()
	layout = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 12
	layout.offset_top = 12
	layout.offset_right = -12
	layout.offset_bottom = -12
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	resized.connect(fit)
	_build_dialog()
	show_map()
	fit()

func fit() -> void:
	var safe := UI.safe_rect(self).grow(-12)
	layout.offset_left = safe.position.x
	layout.offset_top = safe.position.y
	layout.offset_right = safe.end.x - size.x
	layout.offset_bottom = safe.end.y - size.y
	if is_instance_valid(dialog_card):
		dialog_card.size = Vector2(minf(470, safe.size.x), minf(490, safe.size.y))
		if socket_dialog:
			dialog_card.size.y = minf(340, safe.size.y * 0.44)
			dialog_card.position = Vector2(safe.get_center().x - dialog_card.size.x * 0.5, safe.end.y - dialog_card.size.y)
		else:
			dialog_card.position = safe.position + (safe.size - dialog_card.size) * 0.5

func clear_page(next: String) -> void:
	page = next
	board = null
	for child in layout.get_children():
		layout.remove_child(child)
		child.queue_free()
	dialog.hide()
	accumulator = 0.0

func header(title: String, back: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	layout.add_child(row)
	var button := UI.button("←", back, 48)
	button.name = "CampaignBack"
	button.custom_minimum_size.x = 48
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.accessibility_name = "Back"
	row.add_child(button)
	var caption := UI.heading(title, 24)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)

func show_map() -> void:
	if run != null and page == "battle":
		save_progress()
	clear_page("map")
	header("The Last Procession", close)
	var cleared := int(progress.data.completed_levels)
	layout.add_child(UI.paragraph("%d / %d levels completed" % [cleared, Catalog.COUNT], 13))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	UI.keyboard_scroll(scroll, "Campaign world map")
	layout.add_child(scroll)
	var world := WorldMap.new()
	world.progress = progress
	world.level_picked.connect(show_briefing)
	scroll.add_child(world)
	if cleared < Catalog.COUNT and not progress.blocked:
		var next := UI.gold_button("Play level %d" % (cleared + 1), start_mission.bind(cleared), 48)
		next.name = "ContinueCampaign"
		layout.add_child(next)
	var backups := UI.button("Account & backups", func(): app.show_backups())
	backups.name = "CampaignBackups"
	layout.add_child(backups)
	save_notice = UI.paragraph(progress.last_error if not progress.last_error.is_empty() else "Completed levels save on this device. Unfinished levels restart. Cloud backups are uploaded only when you choose Upload.", 12)
	layout.add_child(save_notice)
	if cleared == 20:
		layout.add_child(UI.paragraph("Dawn reaches the capital. Every sanctuary burns again. Replay any level to perfect your vigil.", 15))

func show_briefing(index: int) -> void:
	if not progress.unlocked(index):
		return
	clear_page("briefing")
	run = Run.new(index)
	header("%02d · %s" % [index+1, run.mission.name], show_map)
	layout.add_child(UI.paragraph(Catalog.CHAPTERS[index/5].story, 14))
	add_board(false)
	layout.add_child(UI.paragraph(run.mission.brief, 15))
	layout.add_child(UI.paragraph("%d waves  ·  %d starting gold  ·  20 flame" % [run.mission.waves.size(), run.mission.gold], 13))
	var details := UI.button("Preview waves & rules", show_waves, 48)
	layout.add_child(details)
	var start := UI.gold_button("Begin mission", start_mission.bind(index), 50)
	start.name = "BeginCampaignMission"
	layout.add_child(start)

func start_mission(index: int) -> void:
	if not progress.unlocked(index):
		return
	run = Run.new(index)
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
		run.game.combat.sound_requested.connect(func(cue, _position): app.audio.play(cue))
		run.game.economy.sound_requested.connect(func(cue, _position): app.audio.play(cue))

func show_battle() -> void:
	clear_page("battle")
	paused = false
	speed = 1.0
	selected = -1
	header("%02d · %s" % [run.mission.index+1,run.mission.name], show_map)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	layout.add_child(row)
	gold = UI.value("", 21)
	gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gold)
	pause_button = UI.button("Pause", func():
		paused = not paused
		pause_button.text = "Play" if paused else "Pause"
	, 44)
	pause_button.name = "CampaignPause"
	row.add_child(pause_button)
	var fast := UI.button("2×", func(): speed = 1.0 if speed == 2.0 else 2.0, 44)
	fast.toggle_mode = true
	fast.name = "CampaignSpeed"
	row.add_child(fast)
	status = UI.paragraph("", 14)
	status.name = "CampaignStatus"
	layout.add_child(status)
	add_board(true)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	layout.add_child(controls)
	controls.add_child(UI.button("−", func(): board.set_zoom(board.zoom / 1.25, board.size * 0.5), 44))
	controls.add_child(UI.button("+", func(): board.set_zoom(board.zoom * 1.25, board.size * 0.5), 44))
	controls.add_child(UI.button("Fit", func(): board.reset_view(), 44))
	controls.add_child(UI.button("Waves", show_waves, 44))
	wave_button = UI.gold_button("", begin_wave, 50)
	wave_button.name = "StartCampaignWave"
	layout.add_child(wave_button)
	save_notice = UI.paragraph("Drag to explore · Pinch to zoom · Tap a socket", 12)
	layout.add_child(save_notice)
	refresh()

func add_board(interactive: bool) -> void:
	board = Board.new()
	board.name = "CampaignBattlefield"
	board.run = run
	board.interactive = interactive
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size.y = 140
	board.socket_picked.connect(show_socket)
	board.empty_picked.connect(func():
		if socket_dialog:
			selected = -1
			dialog.hide()
	)
	layout.add_child(board)

func begin_wave() -> void:
	if run.start_wave():
		paused = false
		pause_button.text = "Pause"
		save_progress()
		refresh()

func refresh() -> void:
	if page != "battle":
		return
	gold.text = "%s gold" % Balance.money(run.game.data.balance)
	var shown_wave := mini(run.wave+1, run.mission.waves.size())
	status.text = "Flame %d / 20   ·   Wave %d / %d%s" % [run.health, shown_wave, run.mission.waves.size(), " · Prepare" if run.phase == "planning" else ""]
	wave_button.disabled = run.phase != "planning"
	wave_button.text = "Start wave %d" % (run.wave+1) if run.phase == "planning" else "%d enemies remaining" % (run.game.combat.enemies.size() + run.schedule.size() - run.next_spawn)
	if run.phase in ["victory", "defeat"]:
		wave_button.text = "Sanctuary restored" if run.phase == "victory" else "The flame went out"
	board.selected_tower = run.tower_at(selected) if selected >= 0 else ""
	board.simulation_rate = speed
	board.update_view(0, accumulator)

func save_progress() -> void:
	if run == null:
		return
	var ok: bool = progress.save_run(run)
	if is_instance_valid(save_notice) and not ok:
		save_notice.text = progress.last_error

func show_waves() -> void:
	open_dialog("Waves & rules")
	dialog_body.add_child(UI.paragraph("Fresh gold and towers every level. Bounties go straight to your gold. Start each wave when ready; building and upgrading also work during battle.", 14))
	dialog_body.add_child(UI.paragraph("Protect 20 flame. A Hollow, Wraith or Keeper costs 1; a Revenant or Shade costs 2; a Sentinel costs 3. A boss reaching the sanctuary ends the mission.", 14))
	dialog_body.add_child(UI.paragraph("Each cleared wave grants %d gold. Only completed levels are saved. Leaving an unfinished level means restarting that level." % run.mission.reward, 14))
	for index in range(run.mission.waves.size()):
		dialog_body.add_child(UI.heading("Wave %d%s" % [index+1, " · Cleared" if index < run.wave else ""], 18))
		dialog_body.add_child(UI.paragraph(Catalog.wave_text(run.mission, index), 14))

func show_socket(socket: int) -> void:
	if not run.editable():
		return
	selected = socket
	board.selected = socket
	board.selected_region = Catalog.socket(socket).region
	board.selected_pad = Catalog.socket(socket).pad
	board.selected_tower = run.tower_at(socket)
	var id: String = run.tower_at(socket)
	open_dialog("Build a tower" if id.is_empty() else "Manage tower", true)
	if id.is_empty():
		for kind in Balance.TOWERS:
			var stats := Balance.definition("towers", kind, run.game.tuning)
			dialog_body.add_child(UI.paragraph(stats.description, 13))
			var button := UI.button("%s · %d gold" % [stats.name,stats.cost], func():
				if run.build(socket, kind):
					dialog.hide()
			, 48)
			button.name = "CampaignBuild_" + kind
			button.disabled = run.game.data.balance < stats.cost
			dialog_body.add_child(button)
		return
	var tower: Dictionary = run.game.data.towers[id]
	var stats := Balance.tower_stats(tower, run.game.tuning)
	var title: String = stats.name
	dialog_body.add_child(UI.heading("%s · Level %d" % [title,tower.level], 20))
	dialog_body.add_child(UI.paragraph("%s damage · %ss between attacks · %s reach" % [String.num(stats.damage,1),String.num(stats.period,2),String.num(stats.range,0)], 14))
	if tower.level < Balance.MAX_TOWER_LEVEL:
		var branches: Array = Balance.BRANCHES[tower.kind].keys() if tower.level == 3 else [""]
		for branch in branches:
			var cost := Balance.upgrade_cost(tower, run.game.tuning, branch)
			if branch != "":
				dialog_body.add_child(UI.paragraph(Balance.tower_description(Balance.stats(tower.kind, 4, run.game.tuning, branch)),13))
			var caption: String = Balance.BRANCHES[tower.kind][branch].name if branch != "" else "Upgrade to level %d" % (tower.level + 1)
			var button := UI.button("%s · %d gold" % [caption,cost], func():
				if run.upgrade(socket,branch):
					show_socket(socket)
			,48)
			button.name = "CampaignUpgrade_" + branch
			button.disabled = run.game.data.balance < cost
			dialog_body.add_child(button)
	dialog_body.add_child(UI.heading("Target priority",16))
	var targets := OptionButton.new()
	targets.name = "CampaignTarget"
	targets.custom_minimum_size.y = 48
	for mode in Balance.TARGET_MODES:
		targets.add_item(Balance.TARGET_MODES[mode])
	targets.select(Balance.TARGET_MODES.keys().find(tower.target_mode))
	targets.item_selected.connect(func(index): run.target(socket,Balance.TARGET_MODES.keys()[index]))
	dialog_body.add_child(targets)
	var sell := UI.button("Sell · refund %d gold" % Balance.sell_refund(tower, run.game.tuning), func():
		if run.sell(socket):
			dialog.hide()
	,48)
	sell.name = "CampaignSell"
	dialog_body.add_child(sell)

func show_result() -> void:
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
	dialog.color = Color(0.03,0.04,0.05,0.8)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dialog)
	dialog_card = PanelContainer.new()
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
	var close_button := UI.button("×",func(): dialog.hide(),48)
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
	dialog.hide()

func open_dialog(title: String, for_socket: bool = false) -> void:
	socket_dialog = for_socket
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
	if page != "battle" or run == null or paused or dialog.visible:
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
		paused = true
		if page == "battle":
			save_progress()
			pause_button.text = "Play"
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and page == "battle":
		save_progress()

func go_back() -> void:
	if dialog.visible:
		dialog.hide()
	elif page != "map":
		show_map()
	else:
		close()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()

func close() -> void:
	if page == "battle":
		save_progress()
	closed.emit()
	queue_free()
