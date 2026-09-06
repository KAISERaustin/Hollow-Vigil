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
const TITLE := 30
const OBJECT_TITLE := 24
const GAP := 12
const PADDING := 16
const TARGET := 48
const SANS = preload("res://assets/fonts/NotoSans.ttf")
const SERIF = preload("res://assets/fonts/NotoSerif.ttf")
static var text_scale := 1.0
static var reduced_motion := false
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

static func exact_money(value: float) -> String:
	return String.num(value, 0 if is_equal_approx(value, roundf(value)) else 2)

static func surface(bg: Color = PANEL, outline: int = OUTLINE, padding: int = PADDING) -> StyleBoxFlat:
	var style := box(bg)
	style.set_border_width_all(outline)
	style.set_content_margin_all(padding)
	return style

static func plain() -> StyleBoxFlat:
	return surface(Color.TRANSPARENT, 0, 0)

static func content_box() -> StyleBoxFlat:
	return surface(SURFACE, 2, 12)

static func chrome() -> StyleBoxFlat:
	var style := surface(PANEL, OUTLINE, 0)
	style.set_corner_radius_all(0)
	return style

static func badge(bg: Color = GOLD) -> StyleBoxFlat:
	return surface(bg, 2, 8)

static func safe_rect(control: Control) -> Rect2:
	var available := Rect2(Vector2.ZERO, control.size)
	if OS.has_feature("mobile"):
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var window_size := Vector2(DisplayServer.window_get_size())
		if safe.has_area() and window_size.x > 0 and window_size.y > 0:
			var factor := control.get_viewport_rect().size / window_size
			available = Rect2(safe.position * factor, safe.size * factor).intersection(available)
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
	t.set_stylebox("normal", "Button", box(SURFACE))
	t.set_stylebox("hover", "Button", box(SURFACE))
	t.set_stylebox("pressed", "Button", box(SURFACE))
	t.set_stylebox("hover_pressed", "Button", box(SURFACE))
	t.set_stylebox("disabled", "Button", box(SURFACE))
	t.set_stylebox("focus", "Button", focus_box())
	# OptionButton popups are separate windows and need their own theme roles.
	t.set_stylebox("panel", "PopupMenu", surface(PANEL, OUTLINE, 8))
	t.set_stylebox("hover", "PopupMenu", box(GOLD))
	t.set_font("font", "PopupMenu", font(600))
	t.set_font_size("font_size", "PopupMenu", type_size(BODY))
	for state in ["font_color", "font_hover_color", "font_accelerator_color"]:
		t.set_color(state, "PopupMenu", TEXT)
	t.set_color("font_disabled_color", "PopupMenu", MUTED)
	t.set_constant("v_separation", "PopupMenu", maxi(12, TARGET - ceili(font(600).get_height(type_size(BODY)))))
	t.set_stylebox("panel", "PanelContainer", surface(PANEL, OUTLINE, 0))
	t.set_stylebox("panel", "TooltipPanel", surface(PANEL, 2, 12))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("font_shadow_color", "TooltipLabel", Color.TRANSPARENT)
	t.set_font_size("font_size", "TooltipLabel", type_size(CAPTION))
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
			var grabber := box(PANEL if state == "grabber_highlight" else GOLD)
			grabber.set_content_margin_all(7)
			grabber.set_border_width_all(3)
			t.set_stylebox(state, type, grabber)
		for part in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			t.set_icon(part, type, ImageTexture.new())
	return t

static func box(bg: Color, border: Color = BORDER, radius: int = RADIUS) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(OUTLINE)
	style.set_corner_radius_all(mini(radius, RADIUS))
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func focus_box() -> StyleBoxFlat:
	# An inset ink ring keeps keyboard focus clear without replacing the black border.
	var style := box(Color.TRANSPARENT)
	style.set_border_width_all(2)
	style.set_expand_margin_all(-6)
	style.set_content_margin_all(0)
	return style

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

static func value(text: String, pixels: int = 24) -> Label:
	var l := label(text, pixels)
	l.add_theme_font_override("font", font(700))
	return l

static func button(text: String, action: Callable, height: float = 48) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = maxf(TARGET, height)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.accessibility_name = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	var pressed := box(SURFACE)
	pressed.content_margin_top += 1
	pressed.content_margin_bottom -= 1
	b.add_theme_stylebox_override("pressed", pressed)
	b.draw.connect(func():
		if not b.disabled and (b.is_hovered() or b.button_pressed):
			b.draw_rect(Rect2(Vector2(6, 6), b.size - Vector2(12, 12)), BORDER, false, 2)
		if b.toggle_mode and b.button_pressed:
			b.draw_line(Vector2(12, b.size.y - 8), Vector2(b.size.x - 12, b.size.y - 8), BORDER, 2)
	)
	return b

static func gold_button(text: String, action: Callable, height: float = 50) -> Button:
	return accent_button(text, action, GOLD, height)

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
