extends Control
## One pointer-owned build interaction, shared by Campaign and Infinite.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Choice = preload("res://scripts/ui/towers/tower_choice.gd")
var host: Control
var field: Battlefield
var palette: PanelContainer
var prompt: Label
var banner: PanelContainer
var preview_body: VBoxContainer
var kind := ""
var candidate := ""
var pointer := -2
var origin := Vector2.ZERO
var point := Vector2.ZERO
var dragging := false
var valid := false
var allowed_to_build: Callable

func _ready() -> void:
	name = "GroundBuild"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 110
	palette = PanelContainer.new()
	palette.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, UI.CARD_PADDING))
	add_child(palette)
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, UI.CARD_PADDING))
	add_child(banner)
	preview_body = VBoxContainer.new()
	preview_body.add_theme_constant_override("separation", UI.CARD_GAP)
	banner.add_child(preview_body)
	preview_body.minimum_size_changed.connect(func(): fit.call_deferred())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI.GAP)
	preview_body.add_child(row)
	prompt = UI.paragraph("", 14)
	prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(prompt)
	var cancel_button := UI.button("Cancel", cancel)
	cancel_button.custom_minimum_size.x = 88
	cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(cancel_button)
	resized.connect(fit)
	palette.minimum_size_changed.connect(func(): fit.call_deferred())
	banner.minimum_size_changed.connect(func(): fit.call_deferred())
	cancel()
	var build_button := UI.button("Build", open)
	build_button.name = "OpenGroundBuild"
	field.add_child(build_button)
	build_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	build_button.offset_left = 12
	build_button.offset_right = 100
	build_button.offset_top = -60
	build_button.offset_bottom = -12

func fit() -> void:
	var safe := UI.safe_rect(self)
	for panel in [palette, banner]:
		panel.size = Vector2(maxf(1, safe.size.x - 24), 0)
	palette.position = Vector2(safe.position.x + 12, safe.end.y - palette.size.y - 12)
	banner.position = safe.position + Vector2(12, 12)

func open() -> void:
	if allowed_to_build.is_valid() and not allowed_to_build.call(): return
	cancel()
	host.clear_selection() if host.has_method("clear_selection") else host.panels.close_sheet()
	show()
	for child in palette.get_children():
		palette.remove_child(child)
		child.queue_free()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", UI.GAP)
	palette.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := UI.heading("Build a tower", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(UI.button("Close", cancel))
	body.add_child(UI.paragraph("Drag a tower upward onto clear ground. Swipe sideways to browse.", 14))
	var cards := Choice.build_list(field.state.tuning, arm, "", field.state.data.balance)
	body.add_child(cards)
	for button in cards.get_node("Cards").get_children():
		var tower_kind: String = button.get_meta("tower_kind")
		button.accessibility_description = "Drag upward to place on clear ground"
		button.gui_input.connect(func(event: InputEvent): card_input(event, tower_kind, button))
		var price := UI.label(UI.exact_money(Balance.definition("towers", tower_kind, field.state.tuning).cost) + " gold", 14)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.get_child(0).get_child(0).add_child(price)
	palette.show()
	palette.reset_size()
	fit.call_deferred()

func arm(value: String) -> void:
	kind = value
	for child in preview_body.get_children():
		if child.name == "TowerDetails":
			preview_body.remove_child(child)
			child.queue_free()
	preview_body.add_child(Choice.build_preview(kind, field.state.tuning))
	banner.reset_size()
	candidate = ""
	palette.hide()
	banner.show()
	point = field.world(field.size * 0.5)
	refresh()
	fit()
	fit.call_deferred()

func card_input(event: InputEvent, value: String, button: Button) -> void:
	if button.disabled: return
	if event is InputEventScreenTouch and event.pressed and candidate.is_empty():
		candidate = value
		pointer = event.index
		origin = button.global_position + event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		candidate = value
		pointer = -1
		origin = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
		return
	var pos := Vector2.ZERO
	var id := -2
	var down := false
	var up := false
	var motion := false
	if event is InputEventScreenTouch:
		pos = event.position
		id = event.index
		down = event.pressed
		up = not down
		if event.canceled:
			cancel()
			return
	elif event is InputEventScreenDrag:
		pos = event.position
		id = event.index
		motion = true
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		pos = event.position
		id = -1
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			down = event.pressed
			up = not down
		elif event is InputEventMouseMotion: motion = true
	if id == -2: return
	if dragging and id != pointer:
		get_viewport().set_input_as_handled()
		return
	if not candidate.is_empty() and id == pointer:
		if motion and pos.y < origin.y - 12 and absf(pos.y - origin.y) > absf(pos.x - origin.x):
			arm(candidate)
			dragging = true
		elif motion and absf(pos.x - origin.x) > 16:
			candidate = ""
		elif up:
			candidate = ""
	if kind.is_empty(): return
	# Cancel remains a real button. All other input belongs to placement.
	if down and banner.get_global_rect().has_point(pos): return
	if down and not dragging:
		pointer = id
		dragging = true
	if id == pointer and (motion or down or up):
		point = field.world(pos - field.global_position)
		refresh()
		if up and dragging:
			dragging = false
			if valid:
				var location := VigilWorld.ground_location(point)
				var built := field.state.economy.build(kind, location.region, location.pad)
				if not built.is_empty():
					host.persist()
					cancel()
				else: refresh()
	get_viewport().set_input_as_handled()

func refresh() -> void:
	var location := VigilWorld.ground_location(point)
	point = VigilWorld.pad_position(location.region, location.pad)
	var screen_point := field.global_position + field.screen(point)
	valid = field.get_global_rect().has_point(screen_point) and not banner.get_global_rect().has_point(screen_point)
	valid = valid and field.state.economy.can_place(kind, location.region, location.pad)
	valid = valid and not field.state.economy.needs_first_property()
	valid = valid and field.state.data.balance >= Balance.definition("towers", kind, field.state.tuning).cost
	if allowed_to_build.is_valid(): valid = valid and allowed_to_build.call()
	prompt.text = "Release to build" if valid else "Cannot build here. Drag to clear ground."
	if field.state.economy.needs_first_property(): prompt.text = "Buy your first property before building."
	elif field.state.data.balance < Balance.definition("towers", kind, field.state.tuning).cost: prompt.text = "Not enough gold."
	queue_redraw()

func cancel() -> void:
	kind = ""
	candidate = ""
	dragging = false
	pointer = -2
	if is_instance_valid(field):
		field.touches.clear()
		field.mouse_down = false
		field.gesture_consumed = true
	if is_instance_valid(palette): palette.hide()
	if is_instance_valid(banner): banner.hide()
	hide()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: cancel()

func _draw() -> void:
	if kind.is_empty(): return
	var at := field.global_position - global_position + field.screen(point)
	var tint := Color("368149") if valid else Color("cc3030")
	draw_set_transform(at, 0, Vector2.ONE * field.zoom)
	VigilTerrainArt.sentinel(self, kind, Vector2.ZERO, 1.0, 1, "")
	draw_arc(Vector2.ZERO, 20, 0, TAU, 48, tint, 3.0 / field.zoom, true)
	if not valid:
		draw_line(Vector2(-9, -9), Vector2(9, 9), tint, 3.0 / field.zoom, true)
		draw_line(Vector2(9, -9), Vector2(-9, 9), tint, 3.0 / field.zoom, true)
	draw_set_transform(Vector2.ZERO)
