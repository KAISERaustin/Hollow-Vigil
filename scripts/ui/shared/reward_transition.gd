extends Control
## Reusable presentation component. Its owner supplies an already-paid reward.
## Animation state belongs to this instance and never changes the economy.
const UI = preload("res://scripts/ui/shared/interface.gd")
const DURATION := 2.8
signal finished
var elapsed := 0.0
var active := false
var card: PanelContainer
var title: Label
var reward_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 110
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 4, 24))
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
	badge.add_theme_stylebox_override("panel", UI.surface(UI.GOLD, 2, 12))
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

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	if elapsed >= DURATION:
		cancel()
		finished.emit()
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
	var travel := smoothstep(0.0, DURATION, elapsed)
	for side in [-1.0, 1.0]:
		var center := Vector2(size.x * 0.5 + side * lerpf(size.x * 0.65, size.x * 0.25, travel), size.y * 0.5 + side * 138)
		_cloud(center, minf(size.x / 390.0, 1.4))

func _cloud(center: Vector2, scale_factor: float) -> void:
	var points := PackedVector2Array()
	# A single outlined scalloped silhouette, using the game's flat palette.
	for i in range(65):
		var angle := TAU * float(i) / 64.0
		var scallop := 1.0 + 0.12 * cos(angle * 8.0)
		points.append(center + Vector2(cos(angle) * 124, sin(angle) * 36) * scallop * scale_factor)
	draw_colored_polygon(points, UI.PANEL)
	draw_polyline(points, UI.BORDER, 3.0, true)
