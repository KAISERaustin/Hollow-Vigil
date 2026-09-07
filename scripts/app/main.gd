class_name VigilApp
extends Control

const UI = preload("res://scripts/ui/shared/interface.gd")
const TowerActions = preload("res://scripts/ui/towers/tower_actions.gd")
const TowerDialog = preload("res://scripts/ui/towers/tower_dialog.gd")
const TowerMove = preload("res://scripts/ui/towers/tower_move.gd")
var slot_menu: Control
var slot_active := true
var active_slot := 0
var audio: Node
var application_paused := false
var application_unfocused := false
var public_builds: Node
var private_backups: Node
var campaign_progress := preload("res://scripts/campaign/progress.gd").new()
var campaign_backup: Node
var cloud: Node
var hud: VigilHUD
var game := VigilState.new()
var field: Battlefield
var panels: VigilPanels
var tower_actions: TowerActions
var tower_dialog: TowerDialog
var tower_move: TowerMove
var toast_label: Label
var toast_timer := 0.0
var return_overlay: ColorRect
var return_card: PanelContainer
var return_amount: Label
var return_close: Button
var pending_return_gold := 0.0
var reset_scrim: ColorRect
var return_opener: Control
var simulation_paused := false
var simulation_speed := 1.0
var campaign: Control
var accumulator := 0.0
var save_timer := 0.0
var hud_timer := 0.0
var balance_save_timer := -1.0
@export var load_saved_progress := true

func _ready() -> void:
	if OS.has_feature("mobile"):
		# Use physical density to keep UI units near device-independent pixels.
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_window().content_scale_size = Vector2i.ZERO
		get_window().content_scale_factor = clampf(DisplayServer.screen_get_dpi() / 160.0, 1.0, 4.0)
	var use_slots := load_saved_progress and game.save_path == "user://vigil.save"
	slot_active = not use_slots
	if load_saved_progress and not use_slots:
		game.load_save()
	Engine.max_fps = 60
	get_tree().auto_accept_quit = false
	theme = UI.theme()
	build_interface()
	audio = preload("res://scripts/audio/audio_director.gd").new()
	audio.app = self
	add_child(audio)
	cloud = preload("res://scripts/cloud/cloud_service.gd").new()
	cloud.game = game
	cloud.enabled = load_saved_progress
	cloud.restore_requested.connect(restore_cloud_progress)
	add_child(cloud)
	if not load_saved_progress:
		campaign_progress.path = game.save_path + ".campaign-test"
	campaign_progress.load_progress()
	campaign_backup = preload("res://scripts/cloud/campaign_backup.gd").new()
	campaign_backup.cloud = cloud
	campaign_backup.progress = campaign_progress
	campaign_backup.restored.connect(func():
		if is_instance_valid(campaign):
			campaign.run = null
			campaign.show_map()
	)
	add_child(campaign_backup)
	public_builds = preload("res://scripts/cloud/public_builds.gd").new()
	public_builds.cloud = cloud
	if not load_saved_progress:
		public_builds.outbox_path = game.save_path + ".public-builds-test"
	public_builds.set_process(load_saved_progress)
	add_child(public_builds)
	if use_slots:
		slot_menu = preload("res://scripts/ui/unified_menu.gd").new()
		slot_menu.app = self
		add_child(slot_menu)
		game.suspended = true
	elif game.offline_award >= 1.0:
		show_return_earnings(game.offline_award)
	if not game.save_error.is_empty():
		toast(game.save_error, 12.0)
	private_backups = preload("res://scripts/cloud/private_backups.gd").new()
	private_backups.app = self
	private_backups.cloud = cloud
	private_backups.enabled = load_saved_progress
	if not load_saved_progress:
		private_backups.slots.base_path = game.save_path + ".unified"
		private_backups.state_path = game.save_path + ".private-backups-test"
	private_backups.campaign_slots.base_path = private_backups.slots.base_path
	add_child(private_backups)

func build_interface() -> void:
	panels = VigilPanels.new()
	panels.app = self
	var backdrop := ColorRect.new()
	backdrop.color = UI.BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	hud = VigilHUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_theme_constant_override("separation", 0)
	hud.settings_requested.connect(show_game_menu)
	hud.collect_requested.connect(collect_all)
	hud.pause_requested.connect(toggle_pause)
	hud.speed_requested.connect(toggle_speed)
	add_child(hud)
	hud.build_header()
	# Notifications float near the footer instead of reserving empty header space.
	toast_label = UI.label("", 14, UI.TEXT)
	toast_label.custom_minimum_size.y = 36
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_stylebox_override("normal", UI.surface(UI.PANEL, 2, 12))
	toast_label.modulate.a = 0.0
	field = Battlefield.new()
	field.state = game
	field.camera = Vector2(game.data.camera[0], game.data.camera[1])
	field.zoom = game.data.camera[2]
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size.y = 250
	hud.add_child(field)
	field.add_child(toast_label)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_left = 12
	toast_label.offset_right = -12
	toast_label.offset_top = -72
	toast_label.offset_bottom = -12
	field.picked.connect(panels.select_pad)
	field.expansion_picked.connect(panels.show_expansion)
	field.entrance_picked.connect(panels.show_entrance)
	field.earnings_picked.connect(collect_one)
	field.core_picked.connect(panels.show_core)
	field.empty_picked.connect(panels.close_sheet)
	tower_actions = TowerActions.new()
	tower_actions.field = field
	field.add_child(tower_actions)
	tower_actions.action_requested.connect(func(action): tower_dialog.open_action(action))
	tower_actions.upgraded.connect(persist)
	tower_move = TowerMove.new()
	tower_move.app = self
	field.add_child(tower_move)
	field.relocation_picked.connect(tower_move.place)
	hud.build_footer()
	panels.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panels.offset_left = 12
	panels.offset_right = -12
	panels.offset_bottom = -184
	panels.offset_top = -484
	panels.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 4, 0))
	reset_scrim = ColorRect.new()
	reset_scrim.color = Color(UI.BORDER, 0.65)
	reset_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reset_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	reset_scrim.hide()
	add_child(reset_scrim)
	add_child(panels)
	panels.visibility_changed.connect(func(): reset_scrim.visible = panels.visible and panels.mode == "reset")
	tower_dialog = TowerDialog.new()
	tower_dialog.app = self
	add_child(tower_dialog)
	build_return_popup()
	get_viewport().size_changed.connect(fit_display)
	fit_display()
	update_hud()

func fit_display() -> void:
	hud.fit_safe_area()
	panels.offset_bottom = -184 - hud.safe_bottom
	panels.offset_top = -484 - hud.safe_bottom
	panels.call_deferred("fit_sheet")

func apply_ui_preferences() -> void:
	theme = UI.theme()
	for node in find_children("*", "Control", true, false):
		if node.has_meta("ui_font_size"):
			node.add_theme_font_size_override("font_size", UI.type_size(node.get_meta("ui_font_size")))
		elif node is Button:
			node.remove_theme_font_size_override("font_size")
	hud.queue_sort()
	tower_dialog.call_deferred("fit_dialog")
	call_deferred("fit_return_popup")

func build_return_popup() -> void:
	return_overlay = ColorRect.new()
	return_overlay.name = "ReturnOverlay"
	return_overlay.color = Color(UI.BORDER, 0.65)
	return_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(return_overlay)
	return_card = PanelContainer.new()
	return_card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 4, 0))
	return_overlay.add_child(return_card)
	var content := UI.margin(return_card, 16)
	content.add_theme_constant_override("separation", 12)
	var title := UI.heading("Welcome back", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var message := UI.label("Your vigil stood watch while you were away.", 14, UI.MUTED)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(message)
	content.add_child(UI.rule())
	return_amount = UI.value("", 24)
	return_amount.add_theme_color_override("font_color", UI.TEXT)
	return_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(return_amount)
	var hint := UI.paragraph("Added to your unclaimed earnings.", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)
	return_close = UI.gold_button("Close", close_return_popup, 48)
	return_close.name = "CloseReturnPopup"
	content.add_child(return_close)
	return_close.focus_neighbor_top = return_close.get_path()
	return_close.focus_neighbor_bottom = return_close.get_path()
	return_close.focus_neighbor_left = return_close.get_path()
	return_close.focus_neighbor_right = return_close.get_path()
	return_close.focus_next = return_close.get_path()
	return_close.focus_previous = return_close.get_path()
	resized.connect(fit_return_popup)
	preload("res://scripts/ui/shared/mobile_layout.gd").attach(self)
	return_card.minimum_size_changed.connect(fit_return_popup)
	return_overlay.hide()

func fit_return_popup() -> void:
	var safe := UI.safe_rect(self).grow(-16)
	return_card.size = Vector2(minf(460.0, safe.size.x), return_card.get_combined_minimum_size().y)
	return_card.position = safe.position + (safe.size - return_card.size) * 0.5

func show_return_earnings(amount: float) -> void:
	if not return_overlay.visible:
		return_opener = get_viewport().gui_get_focus_owner()
	if is_instance_valid(audio):
		audio.play("menu_return")
	pending_return_gold += amount
	return_amount.text = Balance.money(pending_return_gold) + " gold"
	toast_timer = 0.0
	toast_label.modulate.a = 0.0
	field.mouse_down = false
	field.touches.clear()
	return_overlay.show()
	return_overlay.move_to_front()
	fit_return_popup()
	return_close.grab_focus()

func close_return_popup() -> void:
	return_overlay.hide()
	pending_return_gold = 0.0
	return_close.release_focus()
	if is_instance_valid(return_opener) and return_opener.is_visible_in_tree():
		return_opener.grab_focus()

func collect_one(id: String, quiet_if_empty: bool = false) -> void:
	var amount := game.economy.collect(id)
	if amount > 0.0:
		persist()
		collection_effect(amount)
	elif not quiet_if_empty:
		toast("This tower has no unclaimed gold yet.")

func collect_all() -> void:
	var amount := game.economy.collect()
	if amount >= 0.01:
		persist()
		collection_effect(amount)
	else:
		toast("Your sentinels are earning. Gold will gather here.")

func collection_effect(amount: float) -> void:
	audio.play("menu_collect")
	# The transaction is complete before this purely visual effect is created.
	update_hud()
	var mote := UI.value("+" + Balance.money(amount) + " gold", 18)
	mote.name = "CollectionPopup"
	mote.add_theme_stylebox_override("normal", UI.badge(UI.GOLD))
	add_child(mote)
	# Collection feedback belongs below all overlays, even when simulation is paused.
	move_child(mote, reset_scrim.get_index())
	mote.size = mote.get_combined_minimum_size()
	mote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var earnings := hud.unclaimed_label.get_parent().get_parent() as Control
	var anchor := earnings.get_global_rect()
	var caption := hud.unclaimed_label.get_parent().get_child(0) as Label
	var caption_width := caption.get_theme_font("font").get_string_size(
		caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size("font_size")
	).x
	var caption_center := caption.global_position.x + caption_width * 0.5
	mote.position = Vector2(
		clampf(caption_center - mote.size.x * 0.5, 12.0, size.x - mote.size.x - 12.0),
		anchor.position.y - mote.size.y - 8.0
	)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mote, "position:y", mote.position.y - 36.0, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mote, "modulate:a", 0.0, 0.5).set_delay(0.45)
	tween.chain().tween_callback(mote.queue_free)

func toast(message: String, seconds: float = 4.0, color: Color = UI.TEXT) -> void:
	if is_instance_valid(audio):
		audio.play("menu_notice")
	toast_label.text = message
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	toast_timer = seconds

func update_hud() -> void:
	hud.update_values(game)
	panels.refresh_affordability()
	if is_instance_valid(tower_dialog):
		tower_dialog.refresh()

func reset_progress() -> void:
	if cloud.busy:
		toast("Wait for the current backup operation before resetting this game.")
		return
	if not game.reset_progress():
		toast(game.save_error, 8.0)
		return
	reset_time_controls()
	audio.bind_game()
	audio.play("menu_reset")
	panels.close_sheet()
	panels.selection_region = "0,0"
	panels.selection_pad = -1
	panels.selection_tower = ""
	field.selected_region = "0,0"
	field.camera = Vector2.ZERO
	field.zoom = 1.0
	field.touches.clear()
	field.mouse_down = false
	field.dragged = false
	field.queue_redraw()
	return_overlay.hide()
	pending_return_gold = 0.0
	accumulator = 0.0
	save_timer = 0.0
	hud_timer = 0.0
	Engine.max_fps = 60
	apply_ui_preferences()
	update_hud()
	toast("Progress reset. Your new vigil begins." if game.save_error.is_empty() else game.save_error, 6.0)

func persist() -> void:
	if not slot_active:
		return
	balance_save_timer = -1.0
	game.data.camera = [field.camera.x, field.camera.y, field.zoom]
	if not game.save():
		toast(game.save_error, 8.0)
	else: queue_private_backup()
	update_hud()

func balance_changed() -> void:
	# Coalesce slider drags into one save; closing or suspending also flushes it.
	balance_save_timer = 0.35
	field.queue_redraw()
	update_hud()

func toggle_pause() -> void:
	simulation_paused = not simulation_paused
	refresh_time_controls()

func toggle_speed() -> void:
	simulation_speed = preload("res://scripts/ui/shared/game_toolbar.gd").next_speed(simulation_speed)
	refresh_time_controls()

func refresh_time_controls() -> void:
	field.simulation_rate = 0.0 if simulation_paused else simulation_speed
	hud.update_time_controls(simulation_paused, simulation_speed)

func reset_time_controls() -> void:
	simulation_paused = false
	simulation_speed = 1.0
	refresh_time_controls()

func _process(delta: float) -> void:
	if game.suspended:
		return
	if balance_save_timer >= 0.0:
		balance_save_timer -= delta
		if balance_save_timer <= 0.0:
			persist()
	# A large stall is accounted as offline time, never as a burst of active ticks.
	if delta > 2.0 and not simulation_paused:
		game.apply_offline(Time.get_unix_time_from_system())
		persist()
		accumulator = 0.0
		return
	var simulation_delta := 0.0 if simulation_paused else minf(delta, 0.25) * simulation_speed
	accumulator += simulation_delta
	while accumulator >= Balance.STEP:
		game.combat.tick(Balance.STEP)
		accumulator -= Balance.STEP
	if not game.combat.relic_drops.is_empty():
		var names: PackedStringArray = []
		for relic_kind in game.combat.relic_drops:
			names.append(preload("res://scripts/gameplay/progression/relics.gd").DEFINITIONS[relic_kind].name)
		game.combat.relic_drops.clear()
		persist()
		if game.save_error.is_empty():
			var reward_title := "Relic found: " + names[0] if names.size() == 1 else "%d boss relics found" % names.size()
			toast(reward_title + "\nSelect a tower → Equipment to equip.", 8.0)
	field.update_view(simulation_delta, accumulator)
	# Advance the live watermark so a subsequent suspension cannot overlap active play.
	game.data.last_accounted = maxf(game.data.last_accounted, Time.get_unix_time_from_system())
	save_timer += delta
	hud_timer += delta
	if hud_timer >= 0.15:
		update_hud()
		hud_timer = 0.0
	if save_timer >= 10.0:
		persist()
		save_timer = 0.0
	toast_timer = maxf(0.0, toast_timer - delta)
	toast_label.modulate.a = clampf(toast_timer / 0.35, 0.0, 1.0)

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(campaign) and campaign.page == "battle":
			campaign.save_progress()
		persist()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		application_paused = true
		audio.set_suspended(true)
		persist()
		game.suspended = true
		accumulator = 0.0
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		application_paused = false
		audio.set_suspended(application_unfocused)
		if is_instance_valid(campaign):
			return
		if not slot_active or (is_instance_valid(slot_menu) and slot_menu.visible):
			return
		if game.suspended:
			var amount := game.apply_offline(Time.get_unix_time_from_system())
			persist()
			game.suspended = false
			if amount >= 1.0:
				show_return_earnings(amount)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		application_unfocused = true
		audio.set_suspended(true)
		persist()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_unfocused = false
		audio.set_suspended(application_paused)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for popup in get_viewport().get_embedded_subwindows():
			if popup is Popup and popup.visible:
				popup.hide()
				return
		# Android Back follows the same topmost navigation owner as on-screen Back.
		if is_instance_valid(slot_menu) and slot_menu.visible:
			slot_menu.go_back()
			return
		if is_instance_valid(campaign):
			campaign.go_back()
			return
		if return_overlay.visible:
			close_return_popup()
		elif tower_dialog.visible:
			tower_dialog.dismiss()
		elif tower_move.visible:
			tower_move.cancel()
		elif panels.visible:
			if panels.mode in ["reset", "developer"]:
				panels.show_settings()
			else:
				panels.close_sheet()
		else:
			show_game_menu()

func _input(event: InputEvent) -> void:
	if is_instance_valid(campaign):
		return
	if is_instance_valid(slot_menu) and slot_menu.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if return_overlay.visible:
			close_return_popup()
		elif tower_dialog.visible:
			tower_dialog.dismiss()
		elif tower_move.visible:
			tower_move.cancel()
		elif panels.visible:
			if panels.mode in ["reset", "developer"]:
				panels.show_settings()
			else:
				panels.close_sheet()
		else:
			return
		get_viewport().set_input_as_handled()

func restore_cloud_progress(snapshot: Dictionary, _world_id: String, _revision: int) -> void:
	if cloud.backup_slot >= 0 and (not slot_active or cloud.backup_slot != active_slot):
		var target: VigilState = cloud.game
		var target_archive := target.save_path + ".before-cloud-" + preload("res://scripts/cloud/cloud_codec.gd").uuid()
		var sequence := 0
		for suffix in ["", ".tmp", ".bak"]:
			var candidate := target.storage.read_candidate(target.save_path + suffix)
			sequence = maxi(sequence, int(candidate.get("sequence", 0)))
			if FileAccess.file_exists(target.save_path + suffix) and DirAccess.copy_absolute(target.save_path + suffix, target_archive + suffix) != OK:
				cloud.restore_completed(false)
				return
		snapshot.sequence = sequence + 1
		var restored := target.storage.write(target.save_path, snapshot)
		if restored and is_instance_valid(slot_menu) and slot_menu.visible:
			slot_menu.show_slots()
		cloud.restore_completed(restored)
		return
	# Archive first, then use the same validated, atomic local save machinery.
	var archive := game.save_path + ".before-cloud-" + preload("res://scripts/cloud/cloud_codec.gd").uuid() + ".save"
	if not game.storage.write(archive, game.snapshot()):
		cloud.restore_completed(false)
		return
	# The codec validates the saved mode and rules. Restore them with the world.
	snapshot.sequence = game.data.sequence + 1
	for suffix in ["", ".tmp", ".bak"]:
		var candidate := game.storage.read_candidate(game.save_path + suffix)
		if not candidate.is_empty():
			snapshot.sequence = maxf(snapshot.sequence, candidate.sequence + 1)
	if not game.storage.write(game.save_path, snapshot):
		cloud.restore_completed(false)
		return
	if not game.load_save():
		cloud.restore_completed(false)
		return
	audio.bind_game()
	panels.close_sheet()
	field.selected_tower = ""
	field.selected_region = "0,0"
	field.selected_pad = -1
	field.camera = Vector2(game.data.camera[0], game.data.camera[1])
	field.zoom = game.data.camera[2]
	field.touches.clear()
	field.mouse_down = false
	accumulator = 0.0
	pending_return_gold = 0.0
	return_overlay.hide()
	field.queue_redraw()
	update_hud()
	cloud.restore_completed(true)
	if game.offline_award >= 1.0:
		show_return_earnings(game.offline_award)

func show_save_slots(exporting: bool = false) -> bool:
	if cloud.busy:
		toast("Finish the current cloud operation before changing saves.")
		return false
	persist()
	if not game.save_error.is_empty():
		return false
	panels.close_sheet()
	return_overlay.hide()
	pending_return_gold = 0.0
	game.suspended = true
	if not is_instance_valid(slot_menu):
		slot_menu = preload("res://scripts/ui/unified_menu.gd").new()
		slot_menu.app = self
		add_child(slot_menu)
	slot_menu.show()
	slot_menu.move_to_front()
	if exporting:
		slot_menu.show_export()
	else:
		slot_menu.show_slots()

	return true

func show_public_builds() -> void:
	if show_save_slots():
		slot_menu.show_public_builds()

func show_campaign() -> void:
	if is_instance_valid(campaign):
		campaign.move_to_front()
		return
	persist()
	panels.close_sheet()
	tower_dialog.dismiss()
	if tower_move.visible:
		tower_move.cancel()
	return_overlay.hide()
	game.suspended = true
	hud.hide()
	campaign = preload("res://scripts/campaign/screen.gd").new()
	campaign.app = self
	campaign.progress = campaign_progress
	if not load_saved_progress:
		campaign.progress.path = game.save_path + ".campaign-test"
	campaign.closed.connect(func():
		hud.show()
		game.suspended = not slot_active or (is_instance_valid(slot_menu) and slot_menu.visible)
		accumulator = 0.0
		campaign = null
	)
	add_child(campaign)

func open_slot(slot: int) -> void:
	var next := VigilState.new()
	next.save_path = slot_menu.slots.path_for(slot)
	if not next.load_save():
		slot_menu.message.text = next.save_error
		return
	activate_slot(next, slot)

func activate_slot(next: VigilState, slot: int) -> void:
	panels.close_sheet()
	game = next
	game.suspended = false
	hud.show()
	reset_time_controls()
	slot_active = true
	active_slot = slot
	field.state = game
	field.set_unrestricted_camera(false)
	field.selected_region = "0,0"
	field.selected_tower = ""
	field.selected_pad = -1
	field.camera = Vector2(game.data.camera[0], game.data.camera[1])
	field.zoom = game.data.camera[2]
	field.touches.clear()
	field.mouse_down = false
	field.dragged = false
	cloud.game = game
	cloud.backup_slot = slot
	cloud.conflict.clear()
	cloud.include_audio = game.data.get("cloud", {}).get("include_audio", false)
	cloud._load_pending()
	if cloud.signed_in():
		cloud._say("Signed in. Saved games and My builds back up automatically. Open Backups to see this game's status.")
	audio.bind_game()
	accumulator = 0.0
	save_timer = 0.0
	balance_save_timer = -1.0
	pending_return_gold = 0.0
	return_overlay.hide()
	slot_menu.hide()
	apply_ui_preferences()
	update_hud()
	field.queue_redraw()
	if game.offline_award >= 1.0:
		show_return_earnings(game.offline_award)

# This view is reachable from Campaign or the save picker, without starting a world.
func show_backups() -> void:
	if is_instance_valid(slot_menu) and slot_menu.has_method("show_backups"):
		slot_menu.show_backups(slot_menu.open_game_menu if slot_menu.held else slot_menu.show_home)
		return
	panels.show_cloud_saves()
	panels.move_to_front()

class StoredBackup extends VigilState:
	# Backing up an inactive slot must not account offline income or advance time.
	func snapshot(_now: float = -1.0) -> Dictionary:
		return data.duplicate(true)

func backup_game(slot: int, allow_empty: bool = false) -> VigilState:
	if slot < 0 or slot >= VigilSaveSlots.COUNT: return null
	if slot_active and slot == active_slot: return game
	var slots := slot_menu.slots as VigilSaveSlots if is_instance_valid(slot_menu) else VigilSaveSlots.new()
	if not is_instance_valid(slot_menu) and not load_saved_progress:
		slots.base_path = game.save_path + ".slots"
	var saved := slots.summary(slot)
	if saved.is_empty() and not allow_empty: return null
	var target := StoredBackup.new()
	target.save_path = slots.path_for(slot)
	if not saved.is_empty(): target.data = saved
	return target

func upload_infinite_backup(slot: int, replace: bool = false) -> void:
	if cloud.busy: return
	var target := backup_game(slot)
	if target == null:
		cloud._say("This slot has no readable save to upload.")
		return
	if cloud.backup_slot != slot: cloud.conflict.clear()
	cloud.backup_slot = slot
	cloud.game = target
	cloud._load_pending()
	if replace: await cloud.keep_local()
	else: await cloud.start_backup()
	cloud.game = game
	cloud.changed.emit()

func show_game_menu() -> void:
	if not is_instance_valid(slot_menu):
		slot_menu = preload("res://scripts/ui/unified_menu.gd").new()
		slot_menu.app = self
		add_child(slot_menu)
	slot_menu.open_game_menu()

func queue_private_backup() -> void:
	if is_instance_valid(private_backups): private_backups.queue_backup()

func open_campaign_slot(slot: int, value: Dictionary) -> void:
	if is_instance_valid(campaign): return
	panels.close_sheet()
	tower_dialog.dismiss()
	return_overlay.hide()
	game.suspended = true
	slot_active = false
	hud.hide()
	campaign = preload("res://scripts/campaign/screen.gd").new()
	campaign.app = self
	campaign.active_campaign_slot = slot
	campaign.campaign_save = value.duplicate(true)
	campaign.closed.connect(func():
		campaign = null
		hud.show()
		game.suspended = true
		slot_menu.show_home("campaign")
	)
	add_child(campaign)
	slot_menu.hide()

func restore_infinite_backup(slot: int, world_id: String) -> void:
	if cloud.busy: return
	var target := backup_game(slot, true)
	if target == null: return
	cloud.backup_slot = slot
	cloud.game = target
	await cloud.restore_world(world_id)
	cloud.game = game
	cloud.changed.emit()
