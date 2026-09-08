extends ColorRect

const UI = preload("res://scripts/ui/shared/interface.gd")
const Catalog = preload("res://scripts/campaign/catalog.gd")
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Progress = preload("res://scripts/campaign/progress.gd")
const Board = preload("res://scripts/campaign/board.gd")
const WorldMap = preload("res://scripts/campaign/world_map.gd")
const TowerChoice = preload("res://scripts/ui/towers/tower_choice.gd")
const WaveSummary = preload("res://scripts/ui/shared/wave_summary.gd")
signal closed
var app: VigilApp
var progress := Progress.new()
var configuration := Configuration.new()
var run: RefCounted
var layout: VBoxContainer
var page_scroll: ScrollContainer
var map_navigation: ColorRect
var map_heading: VBoxContainer
var parchment: TextureRect
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
var dialog_actions: VBoxContainer
var dialog_title: Label
var dialog_header: HBoxContainer
var save_notice: Label
var socket_dialog := false
var build_choices: ScrollContainer
var build_selection := preload("res://scripts/ui/towers/build_selection.gd").new()
var waves_dialog := false
var shared_setups: Dictionary = {}
var configuration_picker: Node
var active_overrides: Dictionary = {}
var session := preload("res://scripts/campaign/session.gd").new()
var mode := "survival"
var selected_build := {}
var default_progress: RefCounted
var configuration_base := ""
var active_campaign_slot := -1
var campaign_save := {}
var game_toolbar: Control
var battle_bar: PanelContainer
var battle_bar_margin: MarginContainer
var floating_hud: Control
var reward_transition: Control
var result_pending := false

class SessionProgress extends Progress:
	func flush() -> bool:
		data.sequence += 1
		return true

# Host the same tower components against the mission state.
var game: VigilState:
	get: return run.game if run != null else null
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
		board.build_preview.clear(board)
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
	tower_actions.upgrade_in_dialog = true
	board.add_child(tower_actions)
	tower_actions.upgraded.connect(persist)
	tower_dialog = VigilTowerDialog.new()
	tower_dialog.app = self
	tower_dialog.clear_selection_on_upgrade = true
	tower_dialog.upgraded.connect(build_selection.show_choices)
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
	parchment = UI.fullscreen_parchment()
	add_child(parchment)
	theme = UI.theme()
	if active_campaign_slot < 0: progress.load_progress()
	if is_instance_valid(app) and not app.load_saved_progress:
		configuration.path = app.game.save_path + ".campaign-configuration-test"
	configuration_base = configuration.path
	default_progress = progress
	session.path = configuration_base + ".session"
	if active_campaign_slot < 0:
		session.load_session()
		mode = session.data.mode
		load_context()
	else:
		mode = campaign_save.mode
		progress = SessionProgress.new()
		progress.allow_all = can_author()
		progress.data.completed_levels = int(campaign_save.completed)
	layout = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = UI.SCREEN_PADDING
	layout.offset_top = UI.SCREEN_PADDING
	layout.offset_right = -UI.SCREEN_PADDING
	layout.offset_bottom = -UI.SCREEN_PADDING
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	page_scroll = ScrollContainer.new()
	page_scroll.name = "CampaignPageScroll"
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.follow_focus = true
	UI.keyboard_scroll(page_scroll, "Campaign menus")
	add_child(page_scroll)
	map_navigation = ColorRect.new()
	map_navigation.name = "CampaignMapNavigation"
	map_navigation.color = VigilTerrainArt.ground_color("forest")
	add_child(map_navigation)
	map_heading = UI.margin(map_navigation, UI.SCREEN_PADDING)
	map_navigation.draw.connect(func():
		map_navigation.draw_rect(Rect2(0, map_navigation.size.y - UI.OUTLINE, map_navigation.size.x, UI.OUTLINE), UI.BORDER)
	)
	resized.connect(fit)
	preload("res://scripts/ui/shared/mobile_layout.gd").attach(self)
	_build_dialog()
	reward_transition = preload("res://scripts/ui/shared/reward_transition.gd").new()
	reward_transition.name = "CampaignWaveReward"
	add_child(reward_transition)
	reward_transition.finished.connect(func():
		if page != "battle": return
		refresh()
		if result_pending:
			result_pending = false
			show_result()
	)
	if active_campaign_slot < 0: show_setup()
	else: show_map()
	fit()

func fit() -> void:
	var safe := UI.safe_rect(self).grow(-UI.SCREEN_PADDING)
	if page == "map":
		var map_safe := UI.safe_rect(self)
		var header_height := UI.TARGET + UI.SCREEN_PADDING * 2 + UI.OUTLINE
		map_navigation.position = map_safe.position
		map_navigation.size = Vector2(map_safe.size.x, header_height)
		page_scroll.position = map_safe.position + Vector2(0, header_height)
		page_scroll.size = Vector2(map_safe.size.x, maxf(0, map_safe.size.y - header_height))
		map_navigation.queue_redraw()
	elif page == "battle":
		layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Terrain reaches every side below the bar; only controls respect insets.
		if is_instance_valid(battle_bar_margin):
			var play_safe := UI.safe_rect(self)
			battle_bar_margin.add_theme_constant_override("margin_left", int(play_safe.position.x) + UI.INSET_PADDING)
			battle_bar_margin.add_theme_constant_override("margin_right", int(size.x - play_safe.end.x) + UI.INSET_PADDING)
			battle_bar_margin.add_theme_constant_override("margin_top", int(play_safe.position.y) + UI.INSET_PADDING)
		if is_instance_valid(floating_hud):
			floating_hud.fit()
			board.overview_padding = floating_hud.overview_padding()
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
			var height := dialog_card.get_combined_minimum_size().y + dialog_body.get_combined_minimum_size().y
			if is_instance_valid(board) and board.size.x > 16 and board.size.y > 16:
				bounds = Rect2(board.global_position - global_position, board.size).grow(-8).intersection(safe)
			dialog_card.size = Vector2(minf(470, bounds.size.x), minf(bounds.size.y, height))
			dialog_card.position = Vector2(bounds.get_center().x - dialog_card.size.x * 0.5, bounds.end.y - dialog_card.size.y)
		else:
			dialog_card.position = safe.position + (safe.size - dialog_card.size) * 0.5

func clear_page(next: String) -> void:
	if is_instance_valid(reward_transition): reward_transition.cancel()
	result_pending = false
	clear_selection()
	clear_tower_ui()
	page = next
	parchment.visible = next not in ["map", "battle"]
	map_navigation.visible = next == "map"
	color = VigilTerrainArt.ground_color(Catalog.CHAPTERS[-1].style) if next == "map" else UI.PANEL
	for child in map_heading.get_children():
		map_heading.remove_child(child)
		child.queue_free()
	layout.add_theme_constant_override("separation", 0 if next in ["map", "battle"] else 10)
	board = null
	floating_hud = null
	battle_bar = null
	battle_bar_margin = null
	for child in layout.get_children():
		layout.remove_child(child)
		child.queue_free()
	var parent: Node = self
	if next != "battle": parent = page_scroll
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

func header(title: String, back: Callable) -> BoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.GAP)
	(map_heading if page == "map" else layout).add_child(row)
	var button := UI.back_button("Back", back)
	button.name = "CampaignBack"
	row.add_child(button)
	var caption := UI.fitted_heading(title, 24) if page == "map" else UI.heading(title, 24)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.clip_text = true
	row.add_child(caption)
	return row

func can_author() -> bool:
	return Balance.Content.catalog().get_node("level/campaign/" + mode).rule("developer_controls", false)

func load_context() -> void:
	selected_build = VigilSaveSlots.CampaignPlaythrough.decode(session.data.selections[mode])
	var identity: String = session.identity(mode)
	configuration = Configuration.new()
	configuration.path = configuration_base + ("" if identity == "default" else "." + identity)
	configuration.load_configuration()
	if mode == "survival" and identity == "default":
		progress = default_progress
	else:
		progress = Progress.new()
		progress.path = default_progress.path + "." + mode + "." + identity
		progress.load_progress()
	progress.allow_all = can_author()
	shared_setups.clear()

func select_campaign(next_mode: String, code: String) -> bool:
	if not session.select_build(next_mode, code):
		toast(session.last_error)
		return false
	run = null
	mode = next_mode
	load_context()
	show_setup()
	return true

func show_setup() -> void:
	if run != null and page == "battle": save_progress()
	clear_page("setup")
	header("Campaign", close)
	layout.add_child(UI.paragraph("Choose your campaign build and how you want to play.", 15))
	layout.add_child(UI.heading("1. Campaign build", 18))
	layout.add_child(UI.paragraph(selected_build.get("setup", {}).get("name", "The Last Procession"), 18))
	layout.add_child(UI.paragraph(selected_build.get("setup", {}).get("description", "%d levels across six biomes. Creative keeps your level edits on this device." % Catalog.COUNT), 14))
	var sources := HBoxContainer.new()
	sources.add_theme_constant_override("separation", 8)
	layout.add_child(sources)
	for community in [false, true]:
		var button := UI.button("Community" if community else "My builds", show_playthrough_picker.bind(community))
		button.name = "CampaignCommunity" if community else "CampaignMyBuilds"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sources.add_child(button)
	if not selected_build.is_empty():
		layout.add_child(UI.button("Use the original campaign", func(): select_campaign(mode, "")))
	layout.add_child(UI.rule())
	layout.add_child(UI.heading("2. Choose your mode", 18))
	var modes := preload("res://scripts/ui/shared/mode_picker.gd").new()
	layout.add_child(modes)
	modes.configure(mode, {"creative": "Create your campaign. Edit campaign-wide stats in Menu, then set rewards and spawns in Waves and share the complete build.", "survival": "Play the chosen campaign with its rules locked. Complete levels in order; each build keeps its own progress."})
	modes.selected.connect(func(next: String): select_campaign(next, session.data.selections[mode]))
	if can_author():
		var share := UI.button("Save or share campaign", show_playthrough_share)
		share.name = "ShareCampaignBuild"
		layout.add_child(share)
	var begin := UI.gold_button("Open %s campaign" % mode.capitalize(), show_map)
	begin.name = "OpenCampaignMap"
	begin.disabled = session.blocked or progress.blocked
	layout.add_child(begin)
	if not session.last_error.is_empty(): layout.add_child(UI.paragraph(session.last_error, 14))
	layout.add_child(UI.button("Account & backups", func(): app.show_backups()))
	if not app.public_builds.outbox.is_empty(): layout.add_child(UI.button("Retry public uploads", app.public_builds.flush))

func show_playthrough_picker(community: bool = false) -> void:
	var menu := configuration_menu()
	if is_instance_valid(configuration_picker): configuration_picker.queue_free()
	configuration_picker = preload("res://scripts/ui/configuration_picker.gd").new()
	menu.add_child(configuration_picker)
	configuration_picker.menu = menu
	configuration_picker.kind = "campaign"
	configuration_picker.back = func():
		menu.view_revision += 1
		menu.hide()
	configuration_picker.selected = func(entry: Dictionary):
		if select_campaign(mode, entry.code):
			menu.view_revision += 1
			menu.hide()
	configuration_picker.show_page(community)

func level_setup(index: int) -> Dictionary:
	if active_campaign_slot >= 0:
		var saved: Dictionary = campaign_save.levels.get(str(index), {"overrides": {}}).duplicate(true)
		saved.merge({"version": 1, "setup": {"name": campaign_save.name, "description": ""}, "level": index})
		return saved
	if shared_setups.has(index): return shared_setups[index].duplicate(true)
	var value := VigilSaveSlots.CampaignPlaythrough.level_build(selected_build, index)
	if value.is_empty(): value = {"version": 1, "setup": {"name": "Campaign", "description": ""}, "level": index, "overrides": {}}
	if can_author() and configuration.data.levels.has(str(index)):
		value.overrides = configuration.overrides(index)
	return value

func show_playthrough_share() -> void:
	if not can_author(): return
	var was_paused := paused
	paused = true
	var levels := {}
	for index in Catalog.COUNT:
		var value := level_setup(index)
		levels[str(index)] = {"overrides": value.overrides}
		if value.has("loadout"): levels[str(index)].loadout = value.loadout.duplicate(true)
	var source: RefCounted = run if run != null else Run.new(0, level_setup(0).overrides, mode)
	if run != null:
		var index: int = run.mission.index
		if page == "battle": levels[str(index)].overrides = active_overrides.duplicate(true)
		levels[str(index)].loadout = {}
		for key in ["towers", "next_tower", "relics", "balance"]:
			levels[str(index)].loadout[key] = run.game.data[key]
	var menu := configuration_menu()
	menu.show_export(source.game, {"levels": levels}, func():
		menu.view_revision += 1
		menu.hide()
		paused = was_paused
	)

func show_map() -> void:
	if run != null and page == "battle":
		save_progress()
	clear_page("map")
	if active_campaign_slot >= 0:
		persist_slot()
		var heading := header(campaign_save.name, app.slot_menu.open_saved_games)
		var back: Button = heading.get_child(0)
		back.accessibility_name = "Back to saved games"
		back.name = "CampaignSavedGames"
		var menu := UI.button("Menu", app.show_game_menu)
		menu.name = "CampaignMapMenu"
		menu.accessibility_name = "Campaign menu"
		menu.custom_minimum_size.x = 76
		menu.autowrap_mode = TextServer.AUTOWRAP_OFF
		menu.size_flags_horizontal = Control.SIZE_SHRINK_END
		menu.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		heading.add_child(menu)
	else:
		var heading := header("The Last Procession", show_setup)
		var menu := UI.button("Menu", app.show_game_menu)
		menu.name = "CampaignMapMenu"
		heading.add_child(menu)
	var cleared := int(progress.data.completed_levels)
	var world := WorldMap.new()
	world.progress = progress
	world.level_picked.connect(show_briefing)
	layout.add_child(world)
	page_scroll.queue_sort.call_deferred()
	if active_campaign_slot >= 0:
		return
	var footer := UI.margin(layout, UI.SCREEN_PADDING)
	footer.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_constant_override("separation", UI.GAP)
	var reset := UI.button("Reset campaign progress", confirm_progress_reset)
	reset.name = "ResetCampaignProgress"
	reset.visible = not can_author()
	footer.add_child(reset)
	var backups := UI.button("Account & backups", func(): app.show_backups())
	backups.name = "CampaignBackups"
	footer.add_child(backups)
	save_notice = UI.paragraph(progress.last_error, 12)
	save_notice.visible = not progress.last_error.is_empty()
	footer.add_child(save_notice)
	if cleared == Catalog.COUNT:
		footer.add_child(UI.paragraph("Every sanctuary burns again. Replay any level to perfect your vigil.", 15))

func show_briefing(index: int) -> void:
	if not progress.unlocked(index):
		return
	clear_page("briefing")
	run = configured_run(index)
	header("%02d · %s" % [index+1, run.mission.name], show_map)
	add_board(false)
	var stats := HBoxContainer.new()
	stats.name = "CampaignLevelStats"
	stats.add_theme_constant_override("separation", 8)
	layout.add_child(stats)
	stats.add_child(UI.stat_card("Waves", str(run.mission.waves.size())))
	stats.add_child(UI.stat_card("Starting gold", UI.exact_money(run.mission.gold)))
	stats.add_child(UI.stat_card(Configuration.Fields.CONFIGURATION_FIELDS.flame.label, str(run.mission.flame)))
	if shared_setups.has(index):
		layout.add_child(UI.paragraph(shared_setups[index].setup.name + "\n" + shared_setups[index].setup.description, 14))
		layout.add_child(UI.button("Use my level defaults", func():
			shared_setups.erase(index)
			show_briefing(index)
		))
	var actions := HBoxContainer.new()
	actions.name = "CampaignLevelActions"
	actions.add_theme_constant_override("separation", UI.GAP)
	layout.add_child(actions)
	var details := UI.button("Preview waves", show_waves, 52)
	details.name = "PreviewCampaignWaves"
	actions.add_child(details)
	var start := UI.gold_button("Resume level" if active_campaign_slot >= 0 and campaign_save.checkpoint.get("level", -1) == index else "Begin level", start_mission.bind(index), 52)
	start.name = "BeginCampaignMission"
	actions.add_child(start)

func start_mission(index: int) -> void:
	if not progress.unlocked(index):
		return
	# Resume only after confirmation on the level information screen.
	if active_campaign_slot >= 0 and campaign_save.checkpoint.get("level", -1) == index:
		run = Run.from_checkpoint(campaign_save.checkpoint)
		if run != null:
			active_overrides = run.rules.duplicate(true)
			connect_run()
			show_battle(true)
			if run.phase == "victory": show_result()
			return
	run = configured_run(index)
	connect_run()
	show_battle()
	save_progress()

func connect_run() -> void:
	run.wave_cleared.connect(func(number: int, reward: float):
		if page != "battle": return
		clear_selection()
		dialog.hide()
		reward_transition.play("Wave %d won!" % number, reward)
	)
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

func show_battle(start_paused: bool = false) -> void:
	clear_page("battle")
	# Restored waves are ready to replay, but playback waits for the player.
	paused = start_paused
	observed_phase = run.phase
	battle_bar = PanelContainer.new()
	battle_bar.name = "CampaignControlBar"
	var chrome := UI.chrome()
	chrome.set_border_width_all(0)
	chrome.border_width_bottom = UI.OUTLINE
	battle_bar.add_theme_stylebox_override("panel", chrome)
	layout.add_child(battle_bar)
	var bar_content := UI.margin(battle_bar, UI.INSET_PADDING)
	battle_bar_margin = bar_content.get_parent()
	game_toolbar = preload("res://scripts/ui/shared/game_toolbar.gd").new()
	bar_content.add_child(game_toolbar)
	game_toolbar.configure(func():
		paused = not paused
		update_time_controls()
	, func():
		speed = game_toolbar.next_speed(speed)
		update_time_controls()
	, go_back, "", "Back to level information")
	pause_button = game_toolbar.pause_button
	speed_button = game_toolbar.speed_button
	update_time_controls()
	var waves := UI.toolbar_action("Waves", show_waves)
	waves.name = "CampaignWaves"
	waves.custom_minimum_size.x = 60
	waves.size_flags_horizontal = Control.SIZE_FILL
	wave_button = UI.toolbar_action("Start wave", begin_wave, true)
	wave_button.custom_minimum_size.x = 96
	wave_button.name = "StartCampaignWave"
	var toolbar_actions: Array[Control] = [waves, wave_button]
	game_toolbar.append_actions(toolbar_actions)
	add_board(true)
	floating_hud = preload("res://scripts/ui/shared/floating_game_hud.gd").new()
	board.add_child(floating_hud)
	floating_hud.title.text = run.mission.name
	floating_hud.title.name = "CampaignTitle"
	gold = floating_hud.left_value
	gold.name = "CampaignGold"
	status = floating_hud.right_value
	status.name = "CampaignStatus"
	save_notice = floating_hud.notice
	build_tower_ui()
	refresh()
	call_deferred("frame_battle")

func frame_battle() -> void:
	if page != "battle" or not is_instance_valid(board): return
	fit()
	board.reset_view()

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
	if not interactive:
		var frame := UI.rounded_viewport_frame(UI.PANEL)
		frame.name = "CampaignMapBorder"
		frame.z_index = 100
		board.add_child(frame)

func begin_wave() -> void:
	if reward_transition.active: return
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
	game_toolbar.update_speed_button(speed_button, speed)
	if is_instance_valid(wave_button) and wave_button.is_inside_tree(): refresh()

func refresh() -> void:
	if page != "battle":
		return
	gold.text = "%s gold" % Balance.money(run.game.data.balance)
	var shown_wave := mini(run.wave+1, run.mission.waves.size())
	var can_start: bool = run.phase == "planning"
	status.text = "Wave %d / %d" % [shown_wave, run.mission.waves.size()]
	wave_button.disabled = not can_start or reward_transition.active
	var enemies_remaining: int = run.game.combat.enemies.size() + run.schedule.size() - run.next_spawn
	if can_start and not reward_transition.active:
		enemies_remaining = 0
		for group in run.mission.waves[run.wave]:
			enemies_remaining += int(group[1])
	var remaining := "%d enemies remaining" % enemies_remaining
	wave_button.text = "Start wave" if can_start else "In progress"
	wave_button.accessibility_name = "Start wave %d" % (run.wave + 1) if can_start else remaining
	floating_hud.detail.text = remaining
	floating_hud.fit()
	if run.phase in ["victory", "defeat"]:
		wave_button.text = "Restored" if run.phase == "victory" else "Defeated"
		wave_button.accessibility_name = "Sanctuary restored" if run.phase == "victory" else "Core integrity depleted"
	if reward_transition.active:
		status.text = "Wave %d / %d" % [run.wave, run.mission.waves.size()]
		wave_button.text = "Cleared"
		wave_button.accessibility_name = "Wave cleared"
	if observed_phase != run.phase:
		observed_phase = run.phase
		clear_selection()
	elif board.selected_tower != "" and not run.game.data.towers.has(board.selected_tower):
		clear_selection()
	if is_instance_valid(tower_dialog):
		tower_dialog.refresh()
	if dialog.visible and socket_dialog and not board.preview_kind.is_empty():
		var build := dialog_actions.get_node_or_null("CampaignBuildConfirm") as Button
		if build != null:
			build.disabled = game.data.balance < Balance.definition("towers", board.preview_kind, game.tuning).cost
	board.simulation_rate = speed
	board.update_view(0, accumulator)

func save_progress() -> void:
	if active_campaign_slot >= 0:
		persist_slot()
		return
	if run == null:
		return
	var ok: bool = progress.save_run(run)
	if is_instance_valid(save_notice) and not ok:
		save_notice.text = progress.last_error
		save_notice.show()

func persist_slot() -> bool:
	if active_campaign_slot < 0: return true
	if run != null and page == "battle":
		if not progress.save_run(run): return false
		campaign_save.completed = int(progress.data.completed_levels)
		campaign_save.checkpoint = run.checkpoint()
	var ok: bool = app.slot_menu.campaign_slots.save_slot(active_campaign_slot, campaign_save)
	if not ok and is_instance_valid(save_notice):
		save_notice.text = app.slot_menu.campaign_slots.error
		save_notice.show()
	if ok and app.has_method("queue_private_backup"): app.queue_private_backup()
	return ok

func session_levels() -> Dictionary:
	var result := {}
	for index in Catalog.COUNT:
		var setup := level_setup(index)
		result[str(index)] = {"overrides": setup.overrides.duplicate(true)}
		if setup.has("loadout"): result[str(index)].loadout = setup.loadout.duplicate(true)
	return result

func show_waves() -> void:
	open_dialog("Waves")
	waves_dialog = true
	dialog.z_index = 101
	fit()
	if can_author():
		var rules := UI.button("Edit rules", show_campaign_rules)
		rules.name = "WavesEditRules"
		dialog_body.add_child(rules)
	var preview := VBoxContainer.new()
	preview.name = "WaveSummaries"
	preview.add_theme_constant_override("separation", 8)
	dialog_body.add_child(preview)
	var reports := Configuration.wave_reports(run.mission)
	for index in range(run.mission.waves.size()):
		var report: Dictionary = reports[index]
		var state := "Cleared" if index < run.wave else ""
		if index == run.wave and run.phase in ["planning", "wave"]:
			state = "In progress" if run.phase == "wave" else "Up next"
		var edit := Callable()
		if can_author():
			edit = show_level_balance.bind(int(run.mission.index), index)
		preview.add_child(WaveSummary.card(report, state, show_wave_balance.bind(index), edit))
	if can_author() and active_campaign_slot < 0:
		var share := UI.button("Share campaign", show_playthrough_share)
		share.name = "ShareCampaignConfiguration"
		dialog_actions.add_child(share)

func show_campaign_rules() -> void:
	if not can_author(): return
	close_dialog()
	var menu := configuration_menu()
	menu.open_game_menu()
	menu.show_campaign_content_rules(menu.resume_game)

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
	build_selection.bind_game(game)
	var confirm := UI.gold_button("", func():
		if board.preview_kind.is_empty() or not dialog_actions.is_visible_in_tree():
			return
		if run.build(socket, board.preview_kind):
			build_selection.show_choices()
			board.build_preview.clear(board)
			board.select_socket(socket)
			dialog.hide()
	)
	confirm.name = "CampaignBuildConfirm"
	var choices := TowerChoice.build_list(run.game.tuning, func(kind: String):
		select_build_preview(kind, confirm)
	, build_selection.kind, INF, "CampaignBuild_")
	build_choices = choices
	dialog_body.add_child(choices)
	dialog_actions.add_child(confirm)
	add_dialog_back("Back to towers", show_build_choices)
	dialog_header.get_node("BackButton").name = "BackToTowers"
	dialog_header.get_node("BackToTowers").hide()
	board.preview_kind = build_selection.kind
	if build_selection.details_open:
		select_build_preview(build_selection.kind, confirm)
	else:
		board.build_preview.open(board, dialog_card)
	fit.call_deferred()

func select_build_preview(kind: String, confirm: Button) -> void:
	build_selection.select(kind)
	board.preview_kind = kind
	var definition := Balance.definition("towers", kind, game.tuning)
	confirm.text = "Build %s · %s gold" % [definition.name, UI.exact_money(definition.cost)]
	confirm.disabled = game.data.balance < definition.cost
	TowerChoice.show_details(build_choices, game.tuning, kind)
	dialog_title.text = definition.name
	var back := dialog_header.get_node("BackToTowers") as Button
	back.show()
	back.grab_focus()
	dialog_actions.show()
	(dialog_body.get_parent() as ScrollContainer).scroll_vertical = 0
	board.build_preview.open(board, dialog_card)
	fit.call_deferred()
	board.queue_redraw()

func show_build_choices() -> void:
	build_selection.show_choices()
	var kind: String = build_selection.kind
	TowerChoice.clear_details(build_choices)
	dialog_header.get_node("BackToTowers").hide()
	dialog_actions.hide()
	dialog_title.text = "Build a tower"
	board.build_preview.clear(board)
	(dialog_body.get_parent() as ScrollContainer).scroll_vertical = 0
	build_choices.get_node("Cards/CampaignBuild_" + kind).grab_focus()
	fit.call_deferred()

func show_result() -> void:
	if reward_transition.active:
		result_pending = true
		save_progress()
		return
	clear_selection()
	save_progress()
	var won: bool = run.phase == "victory"
	open_dialog("Sanctuary restored" if won else "Core integrity depleted")
	if won:
		dialog_body.add_child(UI.paragraph("Core integrity remaining: %d. Level completed. Your progress is saved on this device." % run.health,15))
		if run.mission.index == Catalog.COUNT - 1:
			dialog_body.add_child(UI.paragraph("The Matriarch rests. From the forest to the funeral boughs, every sanctuary burns again. The last procession has reached the dawn.",18))
		else:
			var next := UI.gold_button("Next level", start_mission.bind(run.mission.index+1),48)
			next.name = "NextCampaignLevel"
			dialog_body.add_child(next)
	else:
		dialog_body.add_child(UI.paragraph("Restart this level with its original gold and core integrity. Previously completed levels remain saved.",15))
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
	dialog_card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, 0))
	dialog.add_child(dialog_card)
	var content := UI.margin(dialog_card, UI.SCREEN_PADDING)
	content.add_theme_constant_override("separation",10)
	var row := HBoxContainer.new()
	dialog_header = row
	row.add_theme_constant_override("separation", UI.GAP)
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
	dialog_actions = VBoxContainer.new()
	content.add_child(dialog_actions)
	dialog_actions.hide()
	dialog_body.minimum_size_changed.connect(func():
		if dialog.visible:
			fit.call_deferred()
	)
	dialog.hide()

func close_dialog() -> void:
	dialog.hide()
	clear_selection()

func open_dialog(title: String, for_socket: bool = false) -> void:
	var previous_build_back := dialog_header.get_node_or_null("BackToTowers")
	if previous_build_back != null:
		dialog_header.remove_child(previous_build_back)
		previous_build_back.queue_free()
	var previous_back := dialog_header.get_node_or_null("BackButton")
	if previous_back != null:
		dialog_header.remove_child(previous_back)
		previous_back.queue_free()
	for child in dialog_actions.get_children():
		dialog_actions.remove_child(child)
		child.queue_free()
	dialog_actions.hide()
	if not for_socket:
		clear_selection()
	waves_dialog = false
	dialog.z_index = 101
	socket_dialog = for_socket
	dialog_card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, 0))
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

func add_dialog_back(label: String, action: Callable) -> void:
	var back := UI.back_button(label, action)
	dialog_header.add_child(back)
	dialog_header.move_child(back, 0)
	fit.call_deferred()

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
		app.slot_menu.go_back()
		return
	if is_instance_valid(tower_dialog) and tower_dialog.visible:
		tower_dialog.go_back()
	elif is_instance_valid(tower_move) and tower_move.visible:
		tower_move.cancel()
	elif dialog.visible:
		var back := dialog_header.get_node_or_null("BackToTowers") as Button
		if back == null: back = dialog_header.get_node_or_null("BackButton") as Button
		if back != null and back.visible: back.pressed.emit()
		else: close_dialog()
	elif page == "battle":
		var index := index_for_run()
		save_progress()
		show_briefing(index)
	elif active_campaign_slot >= 0 and page == "map":
		app.slot_menu.open_saved_games()
	elif page == "map":
		show_setup()
	elif page != "setup":
		show_map()
	else:
		close()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		app.navigate_back()
		get_viewport().set_input_as_handled()

func close(save_before_close: bool = true) -> void:
	clear_selection()
	if save_before_close and page == "battle":
		save_progress()
	closed.emit()
	queue_free()

func show_level_balance(index: int, wave_index: int = -1) -> void:
	if not can_author() or wave_index < 0: return
	if active_campaign_slot >= 0:
		close_dialog()
		app.show_game_menu()
		var return_to: Callable = app.slot_menu.resume_game
		if wave_index >= 0:
			return_to = func():
				app.slot_menu.resume_game()
				show_waves()
		app.slot_menu.show_campaign_rules(index, wave_index, return_to)
		return
	var rules: Dictionary = level_setup(index).overrides
	if not configuration.save_level(index, rules):
		toast(configuration.last_error)
		return
	open_dialog("Edit wave %d" % (wave_index + 1))
	var editor := preload("res://scripts/campaign/balance_panel.gd").new()
	editor.store = configuration
	editor.index = index
	editor.initial_scope = wave_index
	if run != null and run.mission.index == index and page == "battle" and run.editable(): editor.live_run = run
	editor.apply_changes = save_configuration
	if wave_index >= 0: editor.saved.connect(show_waves)
	dialog_body.add_child(editor)

func save_campaign_tuning(changes: Dictionary) -> bool:
	if not can_author() or not Balance.valid_tuning(changes) or changes.has("session"): return false
	if changes.is_empty(): return true
	var levels := Configuration.with_campaign_tuning(session_levels(), changes)
	if active_campaign_slot >= 0:
		var next := campaign_save.duplicate(true)
		next.levels = levels
		if run != null and page == "battle": next.checkpoint = run.checkpoint()
		if not next.checkpoint.is_empty():
			next.checkpoint.rules = levels[str(int(next.checkpoint.level))].overrides.duplicate(true)
		if not app.slot_menu.campaign_slots.save_slot(active_campaign_slot, next): return false
		campaign_save = next
		app.queue_private_backup()
	else:
		var overrides := {}
		for key in levels: overrides[key] = levels[key].overrides
		if not configuration.save_levels(overrides): return false
		for index in shared_setups:
			shared_setups[index].overrides = levels[str(index)].overrides.duplicate(true)
	if run != null:
		if not run.wave_checkpoint.is_empty():
			run.wave_checkpoint.rules = levels[str(int(run.mission.index))].overrides.duplicate(true)
		refresh_configuration(int(run.mission.index), levels[str(int(run.mission.index))].overrides)
	return true

func index_for_run() -> int:
	return int(run.mission.index)

func configured_run(index: int) -> RefCounted:
	var setup := level_setup(index)
	active_overrides = setup.overrides.duplicate(true)
	var next := Run.new(index, active_overrides, mode)
	VigilSaveSlots.CampaignBuild.apply_loadout(next, setup)
	return next

func save_configuration(index: int, rules: Dictionary) -> bool:
	if not can_author() or not Configuration.valid_level(index, rules): return false
	var live: bool = run != null and run.mission.index == index and page == "battle" and run.editable()
	if active_campaign_slot >= 0:
		var previous: Dictionary = campaign_save.levels.get(str(index), {"overrides": {}}).duplicate(true)
		var next := previous.duplicate(true)
		next.overrides = rules.duplicate(true)
		if live and run.phase == "wave" and Configuration.resolve(index, rules).waves[run.wave].size() < run.mission.waves[run.wave].size(): return false
		campaign_save.levels[str(index)] = next
		if not persist_slot():
			campaign_save.levels[str(index)] = previous
			return false
		refresh_configuration(index, rules)
		return true
	if live and run.phase == "wave" and Configuration.resolve(index, rules).waves[run.wave].size() < run.mission.waves[run.wave].size():
		configuration.last_error = "Keep active wave groups in place; change their remaining counts instead."
		return false
	if not configuration.save_level(index, rules): return false
	shared_setups.erase(index)
	refresh_configuration(index, rules)
	return true

func refresh_configuration(index: int, rules: Dictionary) -> void:
	if run == null or run.mission.index != index: return
	if page == "briefing":
		# Rebuild the preview and starting values from the saved configuration.
		show_briefing(index)
	elif page == "battle" and run.editable():
		run.apply_configuration(rules)
		active_overrides = rules.duplicate(true)

func configuration_menu() -> Control:
	if not is_instance_valid(app.slot_menu):
		app.slot_menu = preload("res://scripts/ui/unified_menu.gd").new()
		app.slot_menu.app = app
		app.add_child(app.slot_menu)
	app.slot_menu.show()
	app.slot_menu.move_to_front()
	return app.slot_menu

func show_configuration_picker(index: int, kind: String) -> void:
	if not can_author(): return
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
		menu.open_game_menu()
		menu.open_rules()
	configuration_picker.selected = func(entry: Dictionary):
		shared_setups[index] = VigilSaveSlots.CampaignBuild.decode(entry.code)
		menu.view_revision += 1
		menu.hide()
		show_briefing(index)
	configuration_picker.show_page()

func show_campaign_share(index: int, saved: bool = false) -> void:
	if not can_author(): return
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
	add_dialog_back("Back to Waves", show_waves)

func show_wave_balance(wave: int) -> void:
	var report := Configuration.wave_reports(run.mission)[wave]
	open_dialog("Wave %d balancing" % (wave + 1))
	dialog_body.add_child(preload("res://scripts/ui/shared/wave_balance.gd").content(report))
	add_dialog_back("Back to all waves", show_waves)

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
