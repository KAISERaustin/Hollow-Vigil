class_name VigilInterface
extends RefCounted

const BG := VigilTerrainArt.BACKDROP
const PANEL := VigilTerrainArt.PAPER
const MAIN_MENU_BACKGROUND := Color("283b36")
const SURFACE := VigilTerrainArt.ROAD
const ADDED_RULES := Color("95AA83")
const SAVED_GAMES_PAPER := Color("#B8C4C6")
const BORDER := VigilTerrainArt.INK
const GOLD := VigilTerrainArt.GOLD
const TEXT := VigilTerrainArt.INK
const MUTED := VigilTerrainArt.BACKDROP
const DANGER := VigilTerrainArt.CORAL
## All UI enclosure borders and dividers share this width. See docs/UI_STYLE_GUIDE.md.
const OUTLINE := 3
const RADIUS := 4
const BODY := 16
const CAPTION := 14
const META := 12
const OBJECT_TITLE := 24
const GAP := 12
const CARD_GAP := 8
const CARD_PADDING := 12
const INSET_PADDING := 8
const PADDING := 16
const SCREEN_PADDING := 12
const TARGET := 48
const TOOLBAR_BUTTON_SIZE := 50
const SANS = preload("res://assets/fonts/NotoSans.ttf")
const SERIF = preload("res://assets/fonts/NotoSerif.ttf")
const text_scale := 1.0
static var fonts: Dictionary = {}
static var currency_translation: Translation

static func font(weight: int = 400, serif: bool = false) -> Font:
	var key := str(weight) + str(serif)
	if not fonts.has(key):
		var f := FontVariation.new()
		f.base_font = SERIF if serif else SANS
		var ts := TextServerManager.get_primary_interface()
		f.variation_opentype = {ts.name_to_tag("wght"): float(weight)}
		f.opentype_features = {ts.name_to_tag("tnum"): 1}
		f.fallbacks = [(preload("res://assets/fonts/VigilCoinSerif.ttf") if serif else preload("res://assets/fonts/VigilCoinSans.ttf"))]
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

## Passive content cards share the standard ink rim and let scroll drags through.
static func info_card(content: Control, background: Color = PANEL, padding: int = INSET_PADDING, outline: int = OUTLINE) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", surface(background, outline, padding))
	panel.add_child(content)
	return panel

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

static func tint_parchment(paper: TextureRect, background: Color = PANEL) -> void:
	# Tint the paper and its corner fill together; black frame ink stays black.
	paper.modulate = Color(background.r / PANEL.r, background.g / PANEL.g, background.b / PANEL.b, background.a)

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
	return surface(bg, OUTLINE, INSET_PADDING)

static func safe_rect(control: Control) -> Rect2:
	var available := Rect2(Vector2.ZERO, control.size)
	if OS.has_feature("mobile"):
		var viewport_safe := safe_viewport(control)
		available = Rect2(viewport_safe.position - control.global_position, viewport_safe.size).intersection(available)
	return available

## Popups use the owning viewport's safe area, independently of opener size.
static func safe_viewport(control: Control) -> Rect2:
	var canvas := control.get_viewport_rect().size
	if not OS.has_feature("mobile"): return Rect2(Vector2.ZERO, canvas)
	return usable_viewport(canvas, Vector2(DisplayServer.window_get_size()), Rect2(DisplayServer.get_display_safe_area()))

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

static func keyboard_scroll(scroll: ScrollContainer, description: String, horizontal: bool = false) -> void:
	# Retain wheel, touch and keyboard scrolling without visible menu rails.
	preload("res://scripts/ui/shared/touch_scroll.gd").attach(scroll)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if horizontal else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if horizontal:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.add_theme_stylebox_override("focus", focus_box())
	scroll.accessibility_name = description + ". Use arrow keys or Page Up and Page Down to scroll."
	scroll.gui_input.connect(func(event: InputEvent):
		if not event is InputEventKey or not event.pressed:
			return
		if horizontal:
			match event.keycode:
				KEY_RIGHT: scroll.scroll_horizontal += 160
				KEY_LEFT: scroll.scroll_horizontal -= 160
				KEY_PAGEDOWN: scroll.scroll_horizontal += roundi(scroll.size.x * 0.9)
				KEY_PAGEUP: scroll.scroll_horizontal -= roundi(scroll.size.x * 0.9)
				KEY_HOME: scroll.scroll_horizontal = 0
				KEY_END: scroll.scroll_horizontal = roundi(scroll.get_h_scroll_bar().max_value)
				_: return
			scroll.accept_event()
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
	if currency_translation == null:
		currency_translation = preload("res://scripts/ui/shared/currency_text.gd").new()
		TranslationServer.add_translation(currency_translation)
		# Unregister the scripted presentation hook before the engine tears down
		# scripts; native shutdown messages must not call a released script.
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.root.tree_exiting.connect(func(): TranslationServer.remove_translation(currency_translation), CONNECT_ONE_SHOT)
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
		track.set_border_width_all(OUTLINE)
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, focus_box())
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var grabber := box(GOLD)
			grabber.set_content_margin_all(7)
			grabber.set_border_width_all(OUTLINE)
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
	while pixels > minimum and face.get_string_size(TranslationServer.translate(l.text), HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > l.size.x:
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
			b.draw_line(Vector2(12, b.size.y - 8), Vector2(b.size.x - 12, b.size.y - 8), BORDER, OUTLINE)
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

static func refresh_button(action: Callable, description: String = "Refresh") -> Button:
	var refresh := button("", action)
	refresh.accessibility_name = description
	refresh.accessibility_description = description
	refresh.custom_minimum_size = Vector2.ONE * TARGET
	refresh.size_flags_horizontal = Control.SIZE_SHRINK_END
	refresh.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	refresh.draw.connect(func():
		var center := refresh.size * 0.5
		var ink := MUTED if refresh.disabled else TEXT
		refresh.draw_arc(center, 10, PI * 0.25, PI * 1.9, 32, ink, OUTLINE, true)
		var tip := center + Vector2.from_angle(PI * 1.9) * 10
		refresh.draw_polyline(PackedVector2Array([tip + Vector2(-7, -2), tip, tip + Vector2(2, -7)]), ink, OUTLINE, true)
	)
	return refresh

## Dense gameplay bars keep full touch targets with compact text and insets.
static func toolbar_action(text: String, action: Callable, primary: bool = false) -> Button:
	var control := gold_button(text, action, TARGET) if primary else button(text, action)
	control.add_theme_font_size_override("font_size", type_size(CAPTION))
	control.autowrap_mode = TextServer.AUTOWRAP_OFF
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := box(GOLD if primary and state != "disabled" else SURFACE)
		style.content_margin_left = INSET_PADDING
		style.content_margin_right = INSET_PADDING
		if state in ["pressed", "hover_pressed"]:
			style.content_margin_top += 1
			style.content_margin_bottom -= 1
		control.add_theme_stylebox_override(state, style)
	return control

static func info_button(action: Callable, accessible_name: String = "Information") -> Button:
	var control := toolbar_action("", action)
	control.custom_minimum_size = Vector2.ONE * TARGET
	control.accessibility_name = accessible_name
	control.draw.connect(func():
		var center := control.size * 0.5
		var ink := MUTED if control.disabled else TEXT
		control.draw_arc(center, 10.5, 0, TAU, 48, ink, OUTLINE, true)
		control.draw_circle(center + Vector2(0, -5), 1.5, ink, true, -1, true)
		control.draw_line(center + Vector2(0, -1), center + Vector2(0, 6), ink, OUTLINE, true)
	)
	return control

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
	configure_back_button(back, back_label)
	return back

static func configure_back_button(back: Button, back_label: String) -> void:
	preload("res://scripts/ui/shared/back_navigation.gd").protect(back)
	# All navigation hosts share the map's arrow, target and internal padding.
	# Align to the top even when a title or adjacent playback control is taller.
	back.name = "BackButton"
	back.text = "←"
	back.accessibility_name = back_label
	back.accessibility_description = back_label
	back.custom_minimum_size = Vector2.ONE * TARGET
	back.autowrap_mode = TextServer.AUTOWRAP_OFF
	back.clip_text = true
	back.add_theme_font_override("font", font(600))
	back.add_theme_font_size_override("font_size", BODY)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		back.add_theme_stylebox_override(state, box(SURFACE))
	back.add_theme_stylebox_override("focus", focus_box())

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
		row.draw_line(Vector2(0, row.size.y - 1), Vector2(row.size.x, row.size.y - 1), BORDER, OUTLINE)
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
	row.custom_minimum_size.y = TARGET + GAP * 2
	row.draw.connect(func(): row.draw_line(Vector2(0, row.size.y - 1), Vector2(row.size.x, row.size.y - 1), BORDER, OUTLINE))
	if illustration != null:
		illustration.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(illustration)
	var caption := paragraph(title.replace("\n", " · "), BODY)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	if preview != null:
		preview.size_flags_horizontal = Control.SIZE_SHRINK_END
		preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(preview)
	number.custom_minimum_size = Vector2(112, TARGET)
	number.size_flags_horizontal = Control.SIZE_SHRINK_END
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	number.select_all_on_focus = true
	# Keep direct numeric entry without increment/decrement buttons.
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
	row.add_child(number)
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

static func stat(caption: String, text: String, pixels: int = 18) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	var number := value(text, pixels)
	number.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(number)
	column.add_child(paragraph(caption, CAPTION))
	return column

static func stat_card(caption: String, text: String, pixels: int = 24) -> PanelContainer:
	var column := stat(caption, text, pixels)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry: Label in column.get_children():
		entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return info_card(column, SURFACE)

static func rule() -> HSeparator:
	var r := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = BORDER
	style.thickness = OUTLINE
	r.add_theme_stylebox_override("separator", style)
	r.custom_minimum_size.y = OUTLINE
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

static func style_entry(entry: Control) -> void:
	for state in ["normal", "read_only"]:
		entry.add_theme_stylebox_override(state, box(SURFACE))
	entry.add_theme_stylebox_override("focus", focus_box())
	entry.add_theme_color_override("font_color", TEXT)
	entry.add_theme_color_override("font_readonly_color", TEXT)
	entry.add_theme_color_override("font_placeholder_color", MUTED)
	entry.add_theme_color_override("caret_color", TEXT)
	entry.add_theme_font_size_override("font_size", type_size(14))
