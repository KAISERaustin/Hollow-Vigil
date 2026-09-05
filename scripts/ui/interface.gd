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

static func font(weight: int = 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "sans-serif"])
	f.font_weight = weight
	return f

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Button", font(600))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("normal", "Button", box(SURFACE))
	t.set_stylebox("hover", "Button", box(PANEL))
	t.set_stylebox("pressed", "Button", box(GOLD))
	t.set_stylebox("hover_pressed", "Button", box(GOLD))
	t.set_stylebox("disabled", "Button", box(SURFACE))
	t.set_stylebox("focus", "Button", focus_box())
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("font_shadow_color", "TooltipLabel", Color.TRANSPARENT)
	t.set_font_size("font_size", "TooltipLabel", 13)
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
	l.add_theme_font_size_override("font_size", pixels)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func heading(text: String, pixels: int = 30) -> Label:
	var l := label(text, pixels)
	l.add_theme_font_override("font", font(700))
	return l

static func button(text: String, action: Callable, height: float = 48) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = height
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	return b

static func gold_button(text: String, action: Callable, height: float = 50) -> Button:
	return accent_button(text, action, GOLD, height)

static func accent_button(text: String, action: Callable, accent: Color, height: float = 48) -> Button:
	var b := button(text, action, height)
	b.add_theme_stylebox_override("normal", box(accent))
	b.add_theme_stylebox_override("hover", box(PANEL))
	b.add_theme_stylebox_override("pressed", box(accent))
	return b

static func paragraph(text: String, pixels: int = 14) -> Label:
	var l := label(text, pixels, MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func rule() -> HSeparator:
	var r := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = BORDER
	style.thickness = 3
	r.add_theme_stylebox_override("separator", style)
	r.custom_minimum_size.y = 3
	return r

static func margin(parent: Node, padding: int = 16) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, padding)
	parent.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	return v
