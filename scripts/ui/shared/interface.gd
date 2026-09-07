class_name VigilInterface
extends RefCounted

const BG := VigilTerrainArt.BACKDROP
const PANEL := VigilTerrainArt.PAPER
const SURFACE := VigilTerrainArt.ROAD
const BORDER := VigilTerrainArt.INK
const GOLD := VigilTerrainArt.GOLD
const TEXT := VigilTerrainArt.INK
const MUTED := VigilTerrainArt.BACKDROP
const DANGER := VigilTerrainArt.CORAL
const OUTLINE := 4
const RADIUS := 4
const BODY := 16
const CAPTION := 14
const META := 12
const OBJECT_TITLE := 24
const GAP := 12
const PADDING := 16
const TARGET := 48
const TOOLBAR_BUTTON_SIZE := 50
const SANS = preload("res://assets/fonts/NotoSans.ttf")
const SERIF = preload("res://assets/fonts/NotoSerif.ttf")
const text_scale := 1.0
static var fonts: Dictionary = {}

static func font(weight: int = 400, serif: bool = false) -> Font:
	var key := str(weight) + str(serif)
	if not fonts.has(key):
		var f := FontVariation.new()
		f.base_font = SERIF if serif else SANS
		var ts := TextServerManager.get_primary_interface()
		f.variation_opentype = {ts.name_to_tag("wght"): float(weight)}
		f.opentype_features = {ts.name_to_tag("tnum"): 1}
		fonts[key] = f
	return fonts[key]

static func type_size(pixels: int) -> int:
	return ceili(maxi(META, pixels) * text_scale)

static func exact_money(amount: float) -> String:
	return String.num(amount, 0 if is_equal_approx(amount, roundf(amount)) else 2)

static func surface(bg: Color = PANEL, outline: int = OUTLINE, padding: int = PADDING) -> StyleBox:
	var style := box(bg)
	style.set_border_width_all(outline)
	style.set_content_margin_all(padding)
	return style

static func plain() -> StyleBox:
	return surface(Color.TRANSPARENT, 0, 0)

static func fullscreen_parchment() -> TextureRect:
	var paper := TextureRect.new()
	paper.name = "FullscreenParchment"
	paper.texture = preload("res://assets/ui/welcome-parchment.png")
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.add_child(rounded_viewport_frame())
	return paper

static func rounded_viewport_frame(background: Color = PANEL, outline: int = OUTLINE) -> Control:
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var border := surface(Color.TRANSPARENT, outline, 0)
	frame.draw.connect(func():
		# Cover the rectangular viewport's outer corners before drawing its rim.
		# This overlay stays in screen space and leaves map input untouched.
		for corner in [Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1)]:
			var origin: Vector2 = corner * frame.size
			var direction: Vector2 = Vector2.ONE - corner * 2.0
			var points := PackedVector2Array([origin])
			for step in range(17):
				var angle := -PI * 0.5 - PI * 0.5 * step / 16.0
				points.append(origin + direction * (Vector2.ONE + Vector2(cos(angle), sin(angle))) * RADIUS)
			frame.draw_colored_polygon(points, background)
		frame.draw_style_box(border, Rect2(Vector2.ZERO, frame.size))
	)
	frame.resized.connect(frame.queue_redraw)
	return frame

static func chrome() -> StyleBox:
	var style := surface(PANEL, OUTLINE, 0)
	style.set_corner_radius_all(0)
	return style

static func badge(bg: Color = GOLD) -> StyleBox:
	return surface(bg, 2, 8)

static func safe_rect(control: Control) -> Rect2:
	var available := Rect2(Vector2.ZERO, control.size)
	if OS.has_feature("mobile"):
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var window_size := Vector2(DisplayServer.window_get_size())
		var viewport_safe := usable_viewport(control.get_viewport_rect().size, window_size, safe)
		available = Rect2(viewport_safe.position - control.global_position, viewport_safe.size).intersection(available)
	return available

static func usable_viewport(canvas: Vector2, pixels: Vector2, safe: Rect2) -> Rect2:
	var available := Rect2(Vector2.ZERO, canvas)
	if pixels.x <= 0 or pixels.y <= 0: return available
	var factor := canvas / pixels
	if safe.has_area(): available = available.intersection(Rect2(safe.position * factor, safe.size * factor))
	# The native keyboard overlays the UI; it must not resize or clip the menu.
	# Only display safe areas (notches/home indicators) constrain screen layout.
	return available

static func trap_focus(root: Control) -> void:
	var controls: Array[Control] = []
	for node in root.find_children("*", "Control", true, false):
		if node.is_visible_in_tree() and node.focus_mode == Control.FOCUS_ALL and not (node is BaseButton and node.disabled):
			controls.append(node)
	for i in range(controls.size()):
		var before := controls[posmod(i - 1, controls.size())].get_path()
		var after := controls[(i + 1) % controls.size()].get_path()
		controls[i].focus_previous = before
		controls[i].focus_next = after
		controls[i].focus_neighbor_top = before
		controls[i].focus_neighbor_bottom = after
		# Sliders consume left/right for precise value changes.
		controls[i].focus_neighbor_left = controls[i].get_path() if controls[i] is Slider else before
		controls[i].focus_neighbor_right = controls[i].get_path() if controls[i] is Slider else after

static func keyboard_scroll(scroll: ScrollContainer, description: String) -> void:
	# Retain wheel, touch and keyboard scrolling without visible menu rails.
	preload("res://scripts/ui/shared/touch_scroll.gd").attach(scroll)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.add_theme_stylebox_override("focus", focus_box())
	scroll.accessibility_name = description + ". Use arrow keys or Page Up and Page Down to scroll."
	scroll.gui_input.connect(func(event: InputEvent):
		if not event is InputEventKey or not event.pressed:
			return
		match event.keycode:
			KEY_DOWN: scroll.scroll_vertical += 48
			KEY_UP: scroll.scroll_vertical -= 48
			KEY_PAGEDOWN: scroll.scroll_vertical += roundi(scroll.size.y * 0.9)
			KEY_PAGEUP: scroll.scroll_vertical -= roundi(scroll.size.y * 0.9)
			KEY_HOME: scroll.scroll_vertical = 0
			KEY_END: scroll.scroll_vertical = roundi(scroll.get_v_scroll_bar().max_value)
			_: return
		scroll.accept_event()
	)

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = type_size(BODY)
	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Button", font(600))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)
	# Pointer entry must not change icon tint, including toggled buttons.
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox", "MenuButton"]:
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
			t.set_color(state, type, Color.WHITE)
	t.set_stylebox("normal", "Button", box(SURFACE))
	t.set_stylebox("hover", "Button", box(SURFACE))
	t.set_stylebox("pressed", "Button", box(SURFACE))
	t.set_stylebox("hover_pressed", "Button", box(SURFACE))
	t.set_stylebox("disabled", "Button", box(SURFACE))
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox", "MenuButton", "LinkButton", "LineEdit", "TextEdit", "ScrollContainer"]:
		t.set_stylebox("focus", type, focus_box())
	# OptionButton popups are separate windows and need their own theme roles.
	t.set_stylebox("panel", "PopupMenu", surface(PANEL, OUTLINE, 8))
	t.set_stylebox("hover", "PopupMenu", StyleBoxEmpty.new())
	t.set_font("font", "PopupMenu", font(600))
	t.set_font_size("font_size", "PopupMenu", type_size(BODY))
	for state in ["font_color", "font_hover_color", "font_accelerator_color"]:
		t.set_color(state, "PopupMenu", TEXT)
	t.set_color("font_disabled_color", "PopupMenu", MUTED)
	t.set_constant("v_separation", "PopupMenu", maxi(12, TARGET - ceili(font(600).get_height(type_size(BODY)))))
	t.set_stylebox("panel", "PanelContainer", surface(PANEL, OUTLINE, 0))
	for type in ["VScrollBar", "HScrollBar"]:
		var track := box(SURFACE)
		track.set_content_margin_all(3)
		if type == "VScrollBar":
			track.content_margin_left = 7
			track.content_margin_right = 7
		else:
			track.content_margin_top = 7
			track.content_margin_bottom = 7
		track.set_border_width_all(2)
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, focus_box())
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var grabber := box(GOLD)
			grabber.set_content_margin_all(7)
			grabber.set_border_width_all(3)
			t.set_stylebox(state, type, grabber)
		for part in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			t.set_icon(part, type, ImageTexture.new())
	return t

static func box(bg: Color, border: Color = BORDER, radius: int = RADIUS) -> StyleBox:
	var style: StyleBox = StyleBoxFlat.new()
	# Semantic accents and tan surfaces share the same paper renderer.
	var gold := Color(bg, 1.0).is_equal_approx(GOLD)
	var danger := Color(bg, 1.0).is_equal_approx(DANGER)
	if bg.a > 0.0 and (gold or danger or (bg.r >= bg.g and bg.g > bg.b and bg.b >= 0.55)):
		style = preload("res://scripts/ui/shared/parchment_style.gd").new()
		if gold or danger:
			style.paper = style.YELLOW_PAPER if gold else style.RED_PAPER
			style.base_color = GOLD if gold else DANGER
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(OUTLINE)
	style.set_corner_radius_all(mini(radius, RADIUS))
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func focus_box() -> StyleBoxEmpty:
	# Focus navigation stays active without drawing a ring on any control.
	return StyleBoxEmpty.new()

static func label(text: String, pixels: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", type_size(pixels))
	l.add_theme_constant_override("line_spacing", 4)
	l.set_meta("ui_font_size", maxi(META, pixels))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func heading(text: String, pixels: int = 30) -> Label:
	var l := label(text, pixels)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font(600 if pixels >= OBJECT_TITLE else 700, pixels >= OBJECT_TITLE))
	return l

static func fitted_heading(text: String, pixels: int = OBJECT_TITLE, minimum: int = BODY) -> Label:
	# Titles share one responsive rule; body copy still wraps at its normal size.
	var l := heading(text, pixels)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.set_meta("fitted_heading_max", pixels)
	l.set_meta("fitted_heading_min", minimum)
	l.resized.connect(fit_heading.bind(l))
	return l

static func fit_heading(l: Label) -> void:
	if l.size.x <= 1:
		return
	var pixels := type_size(int(l.get_meta("fitted_heading_max", OBJECT_TITLE)))
	var minimum := type_size(int(l.get_meta("fitted_heading_min", BODY)))
	var face := l.get_theme_font("font")
	while pixels > minimum and face.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > l.size.x:
		pixels -= 1
	if l.get_theme_font_size("font_size") != pixels:
		l.add_theme_font_size_override("font_size", pixels)
	l.accessibility_name = l.text

static func value(text: String, pixels: int = 24) -> Label:
	var l := label(text, pixels)
	l.add_theme_font_override("font", font(700))
	return l

static func button(text: String, action: Callable, height: float = 48, highlight_selection: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = maxf(TARGET, height)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.accessibility_name = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	var pressed := box(GOLD if highlight_selection else SURFACE)
	pressed.content_margin_top += 1
	pressed.content_margin_bottom -= 1
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("focus", focus_box())
	b.draw.connect(func():
		if b.toggle_mode and b.button_pressed and not highlight_selection:
			b.draw_line(Vector2(12, b.size.y - 8), Vector2(b.size.x - 12, b.size.y - 8), BORDER, 2)
	)
	return b

static func close_button(action: Callable, height: float = 48) -> Button:
	var close := button("", action, height)
	close.accessibility_name = "Close"
	close.custom_minimum_size = Vector2.ONE * maxf(TARGET, height)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.draw.connect(func():
		var center := close.size * 0.5
		close.draw_line(center - Vector2(8, 8), center + Vector2(8, 8), TEXT, 3)
		close.draw_line(center - Vector2(8, -8), center + Vector2(8, -8), TEXT, 3)
	)
	return close

static func toggle_button(enabled: bool, action: Callable) -> Button:
	var control := button("On" if enabled else "Off", func(): pass)
	control.toggle_mode = true
	control.button_pressed = enabled
	control.toggled.connect(func(active: bool):
		control.text = "On" if active else "Off"
		action.call(active)
	)
	return control

static func playback_button(action: Callable, fast_forward: bool = false) -> Button:
	var control := button("", action, TOOLBAR_BUTTON_SIZE)
	control.custom_minimum_size = Vector2.ONE * TOOLBAR_BUTTON_SIZE
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.draw.connect(func():
		var center := control.size * 0.5
		if fast_forward:
			for x in [-8, 0]:
				control.draw_colored_polygon(PackedVector2Array([center + Vector2(x, -6), center + Vector2(x + 8, 0), center + Vector2(x, 6)]), TEXT)
		elif control.get_meta("paused", false):
			control.draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -7), center + Vector2(6, 0), center + Vector2(-4, 7)]), TEXT)
		else:
			for x in [-6, 2]:
				control.draw_rect(Rect2(center + Vector2(x, -7), Vector2(4, 14)), TEXT)
	)
	return control

static func back_button(back_label: String, action: Callable) -> Button:
	var back := button("", action)
	back.name = "BackButton"
	back.accessibility_name = back_label
	back.accessibility_description = back_label
	back.custom_minimum_size.x = TARGET
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.draw.connect(func():
		var center := back.size * 0.5
		back.draw_line(center - Vector2(8, 0), center + Vector2(8, 0), TEXT, 3)
		back.draw_polyline(PackedVector2Array([center + Vector2(0, -8), center - Vector2(8, 0), center + Vector2(0, 8)]), TEXT, 3)
	)
	return back

static func gold_button(text: String, action: Callable, height: float = 50) -> Button:
	return accent_button(text, action, GOLD, height)

static func enemy_preview(kind: String) -> Control:
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(40, 44)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.draw.connect(func():
		VigilEnemyArt.draw(preview, kind, preview.size * 0.5 + Vector2(0, 4), 1.0)
	)
	preview.resized.connect(preview.queue_redraw)
	return preview

static func action_row(title: String, action: BaseButton, action_text: String = "", preview: Control = null, subtitle: String = "") -> HBoxContainer:
	# Only the trailing control handles taps. Text and row gaps pass drags to
	# the surrounding ScrollContainer, including when the action is disabled.
	var row := HBoxContainer.new()
	row.set_meta("scroll_action_row", true)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 64
	row.add_theme_constant_override("separation", GAP)
	row.draw.connect(func():
		row.draw_line(Vector2(0, row.size.y - 1), Vector2(row.size.x, row.size.y - 1), BORDER, 2)
	)
	if preview != null:
		row.add_child(preview)
	var description := paragraph(title, BODY)
	description.add_theme_color_override("font_color", TEXT)
	description.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if subtitle.is_empty():
		row.add_child(description)
	else:
		var copy := VBoxContainer.new()
		copy.mouse_filter = Control.MOUSE_FILTER_PASS
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		copy.add_theme_constant_override("separation", 2)
		copy.add_child(description)
		copy.add_child(paragraph(subtitle, 13))
		row.add_child(copy)
	action.accessibility_name = title
	action.custom_minimum_size = Vector2(88, TARGET)
	action.size_flags_horizontal = Control.SIZE_SHRINK_END
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if action is Button:
		action.text = action_text
		action.autowrap_mode = TextServer.AUTOWRAP_OFF
		if action.toggle_mode and action_text == "Select":
			action.text = "Selected" if action.button_pressed else "Select"
			action.toggled.connect(func(selected: bool): action.text = "Selected" if selected else "Select")
	row.add_child(action)
	return row

static func number_row(title: String, number: SpinBox, preview: Button = null, illustration: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_meta("scroll_number_row", true)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", GAP)
	row.custom_minimum_size.y = 120
	row.draw.connect(func(): row.draw_line(Vector2(0, row.size.y - 1), Vector2(row.size.x, row.size.y - 1), BORDER, 2))
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", GAP)
	var identity := HBoxContainer.new()
	identity.mouse_filter = Control.MOUSE_FILTER_PASS
	identity.add_theme_constant_override("separation", GAP)
	if illustration != null:
		identity.add_child(illustration)
	var caption := paragraph(title, BODY)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(caption)
	copy.add_child(identity)
	row.add_child(copy)
	if preview != null:
		preview.size_flags_horizontal = Control.SIZE_SHRINK_END
		identity.add_child(preview)
	var controls: BoxContainer
	if preview != null:
		controls = HBoxContainer.new()
	else:
		controls = VBoxContainer.new()
	controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.custom_minimum_size.x = 112
	controls.add_theme_constant_override("separation", 8)
	if preview != null:
		copy.add_child(controls)
	else:
		row.add_child(controls)
	number.custom_minimum_size = Vector2(112, TARGET)
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	number.select_all_on_focus = true
	# Use large explicit +/- controls instead of the built-in tiny arrows.
	number.add_theme_constant_override("buttons_width", 0)
	number.add_theme_constant_override("set_min_buttons_width_from_icons", 0)
	number.add_theme_constant_override("field_and_buttons_separation", 0)
	var entry := number.get_line_edit()
	entry.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	entry.accessibility_name = number.accessibility_name
	entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry.add_theme_stylebox_override("normal", box(SURFACE))
	entry.add_theme_stylebox_override("focus", focus_box())
	entry.add_theme_color_override("font_color", TEXT)
	entry.add_theme_color_override("caret_color", TEXT)
	entry.add_theme_font_size_override("font_size", type_size(CAPTION))
	controls.add_child(number)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	controls.add_child(buttons)
	var minus := button("−", func(): number.apply(); number.value -= number.step)
	var plus := button("+", func(): number.apply(); number.value += number.step)
	minus.name = str(number.name) + "Decrease"
	plus.name = str(number.name) + "Increase"
	minus.accessibility_name = "Decrease " + number.accessibility_name
	plus.accessibility_name = "Increase " + number.accessibility_name
	minus.custom_minimum_size.x = TARGET
	plus.custom_minimum_size.x = TARGET
	buttons.add_child(minus)
	buttons.add_child(plus)
	var refresh := func(_value: float):
		minus.disabled = number.value <= number.min_value
		plus.disabled = number.value >= number.max_value
	number.value_changed.connect(refresh)
	refresh.call(number.value)
	return row

static func accent_button(text: String, action: Callable, accent: Color, height: float = 48) -> Button:
	var b := button(text, action, height)
	b.add_theme_stylebox_override("normal", box(accent))
	b.add_theme_stylebox_override("hover", box(accent))
	var pressed := box(accent)
	pressed.content_margin_top += 1
	pressed.content_margin_bottom -= 1
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	return b

static func paragraph(text: String, pixels: int = 14) -> Label:
	var l := label(text, maxi(CAPTION, pixels), MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func form_field(caption: String, editor: Control) -> VBoxContainer:
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 6)
	field.add_child(heading(caption, 18))
	field.add_child(editor)
	return field

static func rule() -> HSeparator:
	var r := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = BORDER
	style.thickness = 2
	r.add_theme_stylebox_override("separator", style)
	r.custom_minimum_size.y = 2
	return r

static func margin(parent: Node, padding: int = 16) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, padding)
	parent.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", GAP)
	m.add_child(v)
	return v
