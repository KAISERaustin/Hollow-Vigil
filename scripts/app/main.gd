class_name VigilApp
extends Control

const UI = preload("res://scripts/ui/interface.gd")
const TowerActions = preload("res://scripts/ui/tower_actions.gd")
const TowerDialog = preload("res://scripts/ui/tower_dialog.gd")
const TowerMove = preload("res://scripts/ui/tower_move.gd")
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
	if load_saved_progress:
		game.load_save()
	Engine.max_fps = 30 if game.data.settings.low_power else 60
	get_tree().auto_accept_quit = false
	UI.text_scale = float(game.data.settings.get("text_scale", 1.0))
	UI.reduced_motion = bool(game.data.settings.get("reduced_motion", false))
	theme = UI.theme()
	build_interface()
	if game.offline_award >= 1.0:
		show_return_earnings(game.offline_award)
	if not game.save_error.is_empty():
		toast(game.save_error, 12.0)

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
	hud.settings_requested.connect(panels.show_settings)
	hud.collect_requested.connect(collect_all)
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
	UI.text_scale = float(game.data.settings.get("text_scale", 1.0))
	UI.reduced_motion = bool(game.data.settings.get("reduced_motion", false))
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
	return_card.minimum_size_changed.connect(fit_return_popup)
	return_overlay.hide()

func fit_return_popup() -> void:
	var safe := UI.safe_rect(self).grow(-16)
	return_card.size = Vector2(minf(460.0, safe.size.x), return_card.get_combined_minimum_size().y)
	return_card.position = safe.position + (safe.size - return_card.size) * 0.5

func show_return_earnings(amount: float) -> void:
	if not return_overlay.visible:
		return_opener = get_viewport().gui_get_focus_owner()
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
	if not UI.reduced_motion:
		tween.tween_property(mote, "position:y", mote.position.y - 36.0, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mote, "modulate:a", 0.0, 0.5).set_delay(0.45)
	tween.chain().tween_callback(mote.queue_free)

func toast(message: String, seconds: float = 4.0, color: Color = UI.TEXT) -> void:
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
	if not game.reset_progress():
		toast(game.save_error, 8.0)
		return
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
	Engine.max_fps = 30 if game.data.settings.low_power else 60
	apply_ui_preferences()
	update_hud()
	toast("Progress reset. Your new vigil begins." if game.save_error.is_empty() else game.save_error, 6.0)

func persist() -> void:
	balance_save_timer = -1.0
	game.data.camera = [field.camera.x, field.camera.y, field.zoom]
	if not game.save():
		toast(game.save_error, 8.0)
	update_hud()

func balance_changed() -> void:
	# Coalesce slider drags into one save; closing or suspending also flushes it.
	balance_save_timer = 0.35
	field.queue_redraw()
	update_hud()

func _process(delta: float) -> void:
	if game.suspended:
		return
	if balance_save_timer >= 0.0:
		balance_save_timer -= delta
		if balance_save_timer <= 0.0:
			persist()
	# A large stall is accounted as offline time, never as a burst of active ticks.
	if delta > 2.0:
		game.apply_offline(Time.get_unix_time_from_system())
		persist()
		accumulator = 0.0
		return
	accumulator += minf(delta, 0.25)
	while accumulator >= Balance.STEP:
		game.combat.tick(Balance.STEP)
		accumulator -= Balance.STEP
	field.update_view(delta, accumulator)
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
		persist()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		persist()
		game.suspended = true
		accumulator = 0.0
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if game.suspended:
			var amount := game.apply_offline(Time.get_unix_time_from_system())
			persist()
			game.suspended = false
			if amount >= 1.0:
				show_return_earnings(amount)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		persist()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
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

func _input(event: InputEvent) -> void:
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
