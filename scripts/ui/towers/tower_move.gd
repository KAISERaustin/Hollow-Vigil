extends PanelContainer

const UI = preload("res://scripts/ui/shared/interface.gd")
## Active mode host: game, field, controls, persistence and feedback.
var app: Control
var prompt: Label
var cancel_button: Button
var source: Dictionary = {}
var quoted_cost := 0.0
var quoted_seconds := 0.0

func _ready() -> void:
	name = "TowerMove"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_left = 12
	offset_right = -12
	offset_top = 12
	add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 3, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	prompt = UI.label("", 14)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(prompt)
	cancel_button = UI.button("Cancel", cancel, 48)
	cancel_button.name = "CancelTowerMove"
	cancel_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	cancel_button.custom_minimum_size.x = 92
	cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cancel_button)
	minimum_size_changed.connect(func(): call_deferred("fit_prompt"))
	app.field.resized.connect(func(): call_deferred("fit_prompt"))
	hide()

func fit_prompt() -> void:
	if visible:
		# Wrapped text reports a tall minimum before its first width is assigned.
		# Let containers settle, then shrink again when those metrics change.
		size.y = 0

func begin(id: String, level: int, cost: float, seconds: float) -> void:
	if not app.game.data.towers.has(id):
		return
	var tower: Dictionary = app.game.data.towers[id]
	if tower.level != level or tower.get("rebuild_remaining", 0.0) > 0.0 or app.game.data.balance < cost:
		return
	if cost != Balance.move_cost(tower, app.game.tuning) or seconds != Balance.rebuild_seconds(tower, app.game.tuning):
		app.toast("The move price changed. Choose Move again.")
		return
	source = tower.duplicate(true)
	quoted_cost = cost
	quoted_seconds = seconds
	app.field.moving_tower = id
	app.tower_actions.blocked = true
	app.tower_actions.refresh()
	prompt.text = "Tap an empty socket to move.\n%s gold · Rebuild %s" % [UI.exact_money(cost), Balance.rebuild_time_text(seconds)]
	show()
	call_deferred("fit_prompt")
	cancel_button.grab_focus()
	app.field.queue_redraw()

func cancel() -> void:
	var was_moving: bool = app.field.moving_tower != ""
	app.field.moving_tower = ""
	source.clear()
	hide()
	if was_moving:
		cancel_button.release_focus()
		app.tower_actions.blocked = false
		app.tower_actions.refresh()
		if app.tower_actions.visible:
			app.tower_actions.buttons.move.grab_focus()
		app.field.queue_redraw()

func place(region: String, pad: int) -> void:
	if source.is_empty() or app.field.moving_tower != source.id:
		return
	var id: String = source.id
	var tower: Dictionary = app.game.data.towers.get(id, {})
	if tower.is_empty():
		cancel()
		return
	if tower.level != source.level or tower.region != source.region or tower.pad != source.pad or Balance.move_cost(tower, app.game.tuning) != quoted_cost or Balance.rebuild_seconds(tower, app.game.tuning) != quoted_seconds:
		cancel()
		app.toast("This tower changed. Choose Move again.")
		return
	if app.game.economy.tower_at(region, pad) != "":
		app.toast("Choose an empty socket in your territory.")
		return
	if not app.game.economy.relocate(id, region, pad, int(source.level)):
		app.toast("Unable to move. Check your gold and choose an empty socket.")
		return
	cancel()
	app.panels.selection_region = region
	app.panels.selection_pad = pad
	app.panels.selection_tower = id
	app.field.selected_region = region
	app.field.selected_pad = pad
	app.field.selected_tower = id
	app.panels.show_tower()
	app.persist()
	app.toast("Rebuilding · " + Balance.rebuild_time_text(tower.rebuild_remaining))
