extends Control
## One pointer-owned build interaction, shared by Campaign.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Choice = preload("res://scripts/ui/towers/tower_choice.gd")
var layout_owner: Control
var host: Control
var field: Battlefield
var palette: PanelContainer
var banner: PanelContainer
var preview_body: VBoxContainer
var slide: Tween
var reveal := 1.0
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
	z_index = 0
	palette = PanelContainer.new()
	var drawer_style := StyleBoxEmpty.new()
	palette.add_theme_stylebox_override("panel", drawer_style)
	add_child(palette)
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, UI.CARD_PADDING))
	add_child(banner)
	move_child(banner, 0)
	preview_body = VBoxContainer.new()
	preview_body.add_theme_constant_override("separation", UI.CARD_GAP)
	banner.add_child(preview_body)
	preview_body.minimum_size_changed.connect(func(): fit.call_deferred())
	resized.connect(fit)
	palette.minimum_size_changed.connect(func(): fit.call_deferred())
	banner.minimum_size_changed.connect(func(): fit.call_deferred())
	open()
	field.resized.connect(fit)
	fit.call_deferred()

func _process(_delta: float) -> void:
	visible = field.is_visible_in_tree()
	# Keep the tower strip in place while the completed battlefield is shown.
	var can_build := not allowed_to_build.is_valid() or bool(allowed_to_build.call())
	for button in palette.find_children("Build_*", "Button", true, false):
		button.disabled = not can_build or field.state.data.balance < Balance.definition("towers", button.get_meta("tower_kind"), field.state.tuning).cost

func fit() -> void:
	var safe := UI.safe_rect(self)
	var style := palette.get_theme_stylebox("panel")
	# The outside gutters match the spacing between tower cards.
	style.content_margin_left = UI.CARD_GAP
	style.content_margin_right = UI.CARD_GAP
	style.content_margin_top = 0
	style.content_margin_bottom = size.y - safe.end.y
	palette.size = Vector2(safe.size.x, 0)
	banner.size = Vector2(maxf(1, safe.size.x - UI.CARD_GAP * 2), 0)
	palette.position = Vector2(safe.position.x, size.y - palette.size.y)
	if is_instance_valid(layout_owner):
		layout_owner.offset_bottom = -palette.size.y
	banner.position = Vector2(safe.position.x + UI.CARD_GAP, palette.position.y - (banner.size.y + UI.GAP) * reveal)

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
	var cards := Choice.build_list(field.state.tuning, arm, "", field.state.data.balance, "Build_", true)
	body.add_child(cards)
	for button in cards.get_node("Cards").get_children():
		var tower_kind: String = button.get_meta("tower_kind")
		button.accessibility_description = "Drag upward to place on clear ground"
		button.gui_input.connect(func(event: InputEvent): card_input(event, tower_kind, button))
	palette.show()
	palette.reset_size()
	fit.call_deferred()

func arm(value: String) -> void:
	if allowed_to_build.is_valid() and not allowed_to_build.call(): return
	var active_pointer := pointer
	host.clear_selection() if host.has_method("clear_selection") else host.panels.close_sheet()
	pointer = active_pointer
	kind = value
	for child in preview_body.get_children():
		if child.name == "TowerDetails":
			preview_body.remove_child(child)
			child.queue_free()
	preview_body.add_child(Choice.build_preview(kind, field.state.tuning))
	preview_body.move_child(preview_body.get_child(-1), 0)
	var portrait: Control = preview_body.find_child("BuildPortrait", true, false)
	portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.accessibility_description = "Drag onto clear ground to build"
	portrait.gui_input.connect(func(event: InputEvent): card_input(event, value, portrait))
	banner.reset_size()
	candidate = ""
	banner.show()
	if slide != null: slide.kill()
	reveal = 0.0
	slide = create_tween()
	slide.tween_method(func(value: float):
		reveal = value
		fit()
	, 0.0, 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dragging = false
	valid = false
	queue_redraw()
	fit()
	fit.call_deferred()

func card_input(event: InputEvent, value: String, button: Control) -> void:
	if allowed_to_build.is_valid() and not allowed_to_build.call(): return
	if button is Button and button.disabled: return
	if event is InputEventScreenTouch and event.pressed and candidate.is_empty():
		candidate = value
		pointer = event.index
		origin = button.global_position + event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		candidate = value
		pointer = -1
		# Use the press in the same coordinate space as subsequent motion events.
		# Polling the cursor can return a newer/stale position during GUI dispatch.
		origin = button.global_position + event.position

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel") and not kind.is_empty():
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
	if not dragging and palette.get_global_rect().has_point(pos): return
	# Keep portrait drags inside the card; consume outside dismissal before world input.
	if not dragging and banner.get_global_rect().has_point(pos): return
	if not dragging:
		if down: cancel()
		get_viewport().set_input_as_handled()
		return
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
	valid = valid and not palette.get_global_rect().has_point(screen_point)
	valid = valid and field.state.economy.can_place(kind, location.region, location.pad)
	valid = valid and field.state.data.balance >= Balance.definition("towers", kind, field.state.tuning).cost
	if allowed_to_build.is_valid(): valid = valid and allowed_to_build.call()
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
	if is_instance_valid(palette): palette.show()
	if slide != null: slide.kill()
	if is_instance_valid(banner): banner.hide()
	show()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: cancel()

func _draw() -> void:
	if kind.is_empty() or not dragging: return
	var at := field.global_position - global_position + field.screen(point)
	var tint := Color("368149") if valid else Color("cc3030")
	draw_set_transform(at, 0, Vector2.ONE * field.zoom)
	# Use the same level-one stats as the tower being built, including save tuning.
	var radius: float = Balance.stats(kind, 1, field.state.tuning).range
	draw_arc(Vector2.ZERO, radius, 0, TAU, 72, VigilTerrainArt.GOLD, 1.5 / field.zoom, true)
	# Composite artwork sets its own transform for mounted parts such as the bow.
	draw_set_transform(Vector2.ZERO)
	VigilTerrainArt.sentinel(self, kind, at, field.zoom, 1, "")
	draw_set_transform(at, 0, Vector2.ONE * field.zoom)
	# Align the placement indicator's bottom with the tower plinth at y = 12.
	var placement_center := Vector2(0, -8)
	draw_arc(placement_center, 20, 0, TAU, 48, tint, 3.0 / field.zoom, true)
	if not valid:
		draw_line(placement_center + Vector2(-9, -9), placement_center + Vector2(9, 9), tint, 3.0 / field.zoom, true)
		draw_line(placement_center + Vector2(9, -9), placement_center + Vector2(-9, 9), tint, 3.0 / field.zoom, true)
	draw_set_transform(Vector2.ZERO)
