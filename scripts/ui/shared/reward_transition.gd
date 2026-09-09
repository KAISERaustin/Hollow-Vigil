extends Control
## Reusable presentation component. Its owner supplies an already-paid reward.
## Animation state belongs to this instance and never changes the economy.
const UI = preload("res://scripts/ui/shared/interface.gd")
const DURATION := 1.4
signal finished
var elapsed := 0.0
var active := false
var dismissed_pointers: Dictionary = {}
var dismissed_frame := -1
var card: PanelContainer
var title: Label
var reward_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 110
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, 24))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	card.add_child(rows)
	title = UI.heading("", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var subtitle := UI.label("Wave cleared", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(subtitle)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UI.surface(UI.GOLD, UI.OUTLINE, 12))
	rows.add_child(badge)
	reward_label = UI.value("", 24)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badge.add_child(reward_label)
	hide()
	set_process(false)

func play(caption: String, amount: float) -> void:
	elapsed = 0.0
	active = true
	title.text = caption
	reward_label.text = "+%s gold" % UI.exact_money(amount)
	show()
	set_process(true)
	_update_visuals()

func cancel() -> void:
	active = false
	elapsed = 0.0
	hide()
	set_process(false)

func dismiss() -> void:
	if not active: return
	cancel()
	finished.emit()

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch): return
	var pointer := "touch_%d" % event.index if event is InputEventScreenTouch else "mouse_%d" % event.button_index
	if not event.pressed and dismissed_pointers.has(pointer):
		dismissed_pointers.erase(pointer)
		get_viewport().set_input_as_handled()
		return
	# Release the captured pointer before suppressing its synthetic duplicate.
	# Phones can deliver the emulated mouse press first; suppressing its release
	# before cleanup leaves mouse_1 captured and blocks later map gestures.
	if event.device == InputEvent.DEVICE_ID_EMULATION and (not dismissed_pointers.is_empty() or dismissed_frame == Engine.get_process_frames()):
		get_viewport().set_input_as_handled()
		return
	if not active or not is_visible_in_tree(): return
	if event.pressed:
		dismissed_frame = Engine.get_process_frames()
		dismissed_pointers[pointer] = true
		get_viewport().set_input_as_handled()
		dismiss()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	if elapsed >= DURATION:
		dismiss()
		return
	_update_visuals()

func _update_visuals() -> void:
	var entrance := smoothstep(0.0, 0.45, elapsed)
	var departure := smoothstep(DURATION - 0.45, DURATION, elapsed)
	modulate.a = entrance * (1.0 - departure)
	card.size = Vector2(minf(340.0, size.x - 32.0), 0)
	card.position = (size - card.size) * 0.5 + Vector2(0, 20 * (1.0 - entrance) - 16 * departure)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.38))
