extends RefCounted

# Per-battlefield presentation state; never creates or saves a gameplay tower.
var menu: Control
var signature: Array = []

func open(field: Control, panel: Control) -> void:
	menu = panel
	signature.clear()
	field.queue_redraw()

func clear(field: Control) -> void:
	if menu != null:
		field.camera_framing.cancel()
	menu = null
	signature.clear()
	field.preview_kind = ""
	field.queue_redraw()

static func menu_height(field: Control) -> float:
	# Reserve enough map for every catalog choice, so selecting does not resize
	# the list beneath the player's finger. Short screens scroll the list.
	var radius := 55.0
	for kind in Balance.TOWERS:
		radius = maxf(radius, Balance.Content.tower(kind).stats(1, field.state.tuning).range)
	return maxf(150.0, field.size.y - radius * 2.0 * field.minimum_zoom() - 44.0)

func refresh(field: Control) -> void:
	if not is_instance_valid(menu):
		return
	if not menu.is_visible_in_tree() or field.selected_pad < 0 or field.selected_tower != "":
		clear(field)
		return
	var available := Rect2(Vector2.ZERO, field.size).grow(-10.0)
	available.size.y = minf(available.end.y, menu.global_position.y - field.global_position.y - 10.0) - available.position.y
	var radius: float = field.selected_range()
	if radius <= 0.0 or available.size.y <= 0.0:
		return
	var next := [field.state, field.selected_region, field.selected_pad, field.preview_kind, radius, available]
	if next == signature:
		return
	signature = next
	var center := VigilWorld.pad_position(field.selected_region, field.selected_pad)
	var bounds := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	bounds = bounds.merge(Rect2(center + Vector2(-30, -55), Vector2(60, 75)))
	field.frame_world_rect(bounds, available)

func draw(field: Control) -> void:
	if not is_instance_valid(menu) or not menu.is_visible_in_tree() or field.selected_tower != "" or field.selected_pad < 0 or not Balance.TOWERS.has(field.preview_kind):
		return
	var center: Vector2 = field.screen(VigilWorld.pad_position(field.selected_region, field.selected_pad))
	VigilTerrainArt.sentinel(field, field.preview_kind, center, field.zoom, 1, "")
