class_name VigilHUD
extends VBoxContainer

signal settings_requested
signal pause_requested
signal speed_requested
signal collect_requested

const UI = preload("res://scripts/ui/shared/interface.gd")
const INCOME_REFRESH_MSEC := 1000
var next_income_refresh_msec := 0
var gold_label: Label
var rate_label: Label
var kills_label: Label
var pause_button: Button
var speed_button: Button
var simulation_paused := false
var collect_button: Button
var unclaimed_label: Label
var header_margin: MarginContainer
var footer_margin: MarginContainer
var safe_bottom := 0.0

func fit_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	var screen_size := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if screen_size.x <= 0 or screen_size.y <= 0 or not safe.has_area():
		return
	# Safe-area pixels must be converted to the expanded canvas coordinates.
	var canvas_scale := get_viewport_rect().size / screen_size
	var left := maxf(0.0, safe.position.x) * canvas_scale.x
	var right := maxf(0.0, screen_size.x - safe.end.x) * canvas_scale.x
	var top := maxf(0.0, safe.position.y) * canvas_scale.y
	safe_bottom = maxf(0.0, screen_size.y - safe.end.y) * canvas_scale.y
	for margin in [header_margin, footer_margin]:
		margin.add_theme_constant_override("margin_left", 12 + ceili(left))
		margin.add_theme_constant_override("margin_right", 12 + ceili(right))
	header_margin.add_theme_constant_override("margin_top", 12 + ceili(top))
	footer_margin.add_theme_constant_override("margin_bottom", 12 + ceili(safe_bottom))

func build_header() -> void:
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UI.chrome())
	add_child(top)
	var header := UI.margin(top, 12)
	header_margin = header.get_parent() as MarginContainer
	header.add_theme_constant_override("separation", 8)
	var toolbar := HBoxContainer.new()
	toolbar.name = "HeaderToolbar"
	toolbar.add_theme_constant_override("separation", 12)
	header.add_child(toolbar)
	var settings := UI.button("", func(): settings_requested.emit(), 50)
	settings.name = "SettingsButton"
	settings.tooltip_text = "Settings"
	settings.accessibility_name = "Settings"
	settings.draw.connect(func():
		var center := settings.size * 0.5
		var outline := PackedVector2Array()
		for point in range(32):
			var angle := TAU * float(point) / 32.0 - PI / 32.0
			var radius := 12.0 if point % 4 < 2 else 9.0
			outline.append(center + Vector2.from_angle(angle) * radius)
		outline.append(outline[0])
		settings.draw_polyline(outline, UI.TEXT, 2.0, true)
		settings.draw_arc(center, 4.0, 0.0, TAU, 24, UI.TEXT, 2.0, true)
	)
	settings.custom_minimum_size.x = 50
	settings.size_flags_horizontal = Control.SIZE_FILL
	toolbar.add_child(settings)
	pause_button = UI.button("", func(): pause_requested.emit(), 50)
	pause_button.name = "PauseButton"
	pause_button.custom_minimum_size.x = 50
	pause_button.size_flags_horizontal = Control.SIZE_FILL
	pause_button.draw.connect(func():
		var center := pause_button.size * 0.5
		if simulation_paused:
			pause_button.draw_colored_polygon(PackedVector2Array([center + Vector2(-6, -10), center + Vector2(10, 0), center + Vector2(-6, 10)]), UI.TEXT)
		else:
			for x in [-8, 3]:
				pause_button.draw_rect(Rect2(center + Vector2(x, -10), Vector2(5, 20)), UI.TEXT)
	)
	toolbar.add_child(pause_button)
	speed_button = UI.button("2x", func(): speed_requested.emit(), 50)
	speed_button.name = "SpeedButton"
	speed_button.custom_minimum_size.x = 50
	speed_button.size_flags_horizontal = Control.SIZE_FILL
	speed_button.toggle_mode = true
	toolbar.add_child(speed_button)
	update_time_controls(false, 1.0)
	var territory := Control.new()
	territory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(territory)

func update_time_controls(paused: bool, speed: float) -> void:
	simulation_paused = paused
	pause_button.tooltip_text = "Play" if paused else "Pause"
	pause_button.accessibility_name = "Resume game" if paused else "Pause game"
	pause_button.queue_redraw()
	speed_button.set_pressed_no_signal(speed == 2.0)
	speed_button.tooltip_text = "Return to normal speed" if speed == 2.0 else "Double game speed"
	speed_button.accessibility_name = "Game speed: 2×. Switch to 1×" if speed == 2.0 else "Game speed: 1×. Switch to 2×"

func build_footer() -> void:
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", UI.chrome())
	add_child(bottom)
	var footer := UI.margin(bottom, 12)
	footer_margin = footer.get_parent() as MarginContainer
	footer.add_theme_constant_override("separation", 12)
	var earning_row := HBoxContainer.new()
	earning_row.name = "FooterActions"
	earning_row.add_theme_constant_override("separation", 12)
	footer.add_child(earning_row)
	var stats := HBoxContainer.new()
	stats.name = "FooterStats"
	stats.add_theme_constant_override("separation", 12)
	footer.add_child(stats)
	gold_label = stat_block(stats, "Gold", "180", UI.TEXT)
	rate_label = stat_block(stats, "Gold / sec", "0", UI.TEXT)
	kills_label = stat_block(stats, "Kills", "0", UI.TEXT)
	var reserve_card := PanelContainer.new()
	reserve_card.name = "UnclaimedEarningsCard"
	reserve_card.custom_minimum_size.y = 48
	reserve_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reserve_style := UI.plain()
	reserve_style.content_margin_top = 4
	reserve_style.content_margin_bottom = 4
	reserve_card.add_theme_stylebox_override("panel", reserve_style)
	earning_row.add_child(reserve_card)
	var reserve_box := VBoxContainer.new()
	reserve_box.add_theme_constant_override("separation", 0)
	reserve_box.alignment = BoxContainer.ALIGNMENT_CENTER
	reserve_card.add_child(reserve_box)
	var reserve_title := UI.label("Unclaimed earnings", 12, UI.MUTED)
	reserve_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reserve_box.add_child(reserve_title)
	unclaimed_label = UI.value("0 gold", 24)
	unclaimed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unclaimed_label.add_theme_color_override("font_color", UI.TEXT)
	reserve_box.add_child(unclaimed_label)
	collect_button = UI.gold_button("Collect all", func(): collect_requested.emit(), 52)
	collect_button.size_flags_horizontal = Control.SIZE_FILL
	collect_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	collect_button.custom_minimum_size.x = 128
	earning_row.add_child(collect_button)

func update_values(game: VigilState) -> void:
	gold_label.text = Balance.money(game.data.balance)
	# Hold the rounded rate for a full real-time second between updates.
	var now_msec := Time.get_ticks_msec()
	if now_msec >= next_income_refresh_msec:
		rate_label.text = str(roundi(game.combat.income_rate()))
		next_income_refresh_msec = now_msec + INCOME_REFRESH_MSEC
	kills_label.text = Balance.money(game.data.kills)
	unclaimed_label.text = Balance.money(game.economy.unclaimed()) + " gold"
	collect_button.text = "Collect all" if not game.data.automation else "Steward active"
	collect_button.disabled = game.economy.unclaimed() < 0.01
	unclaimed_label.tooltip_text = "No earnings yet" if collect_button.disabled else "Gold ready to collect"
	var caption := unclaimed_label.get_parent().get_child(0) as Label
	caption.text = "Unclaimed earnings"

func stat_block(parent: Node, title: String, value: String, color: Color) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.plain())
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	panel.add_child(stack)
	stack.add_child(UI.label(title, 12, UI.MUTED))
	var value_label := UI.value(value, 24)
	value_label.add_theme_color_override("font_color", color)
	stack.add_child(value_label)
	return value_label
