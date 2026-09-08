extends Translation
## Presentation-only substitution: original strings remain readable to assistive
## technology and game/save identifiers are never changed.
const SYMBOL := "\ue000"
var words := RegEx.new()

func _init() -> void:
	locale = "en"
	words.compile("(?i)\\bgold\\b")

func _get_message(source: StringName, _context: StringName) -> StringName:
	return StringName(words.sub(String(source), SYMBOL, true))

static func coin_font(face: Font) -> FontFile:
	# Match the center of the surrounding font's ascent/descent, at every size.
	# An RGBA bitmap preserves the same ochre/ink coin on light and dark UI.
	var result := FontFile.new()
	result.fixed_size = 64
	result.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	var ascent := face.get_ascent(64)
	var descent := face.get_descent(64)
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><circle cx="32" cy="32" r="29" fill="#e0b568" stroke="black" stroke-width="4"/><circle cx="32" cy="32" r="21" fill="none" stroke="black" stroke-width="2"/><path d="M32 20 L39 32 L32 44 L25 32 Z" fill="black"/></svg>')
	result.set_texture_image(0, Vector2i(64, 0), 0, image)
	result.set_cache_ascent(0, 64, ascent)
	result.set_cache_descent(0, 64, descent)
	result.set_glyph_texture_idx(0, Vector2i(64, 0), 0xe000, 0)
	result.set_glyph_uv_rect(0, Vector2i(64, 0), 0xe000, Rect2(0, 0, 64, 64))
	result.set_glyph_size(0, Vector2i(64, 0), 0xe000, Vector2(64, 64))
	result.set_glyph_offset(0, Vector2i(64, 0), 0xe000, Vector2(0, (descent - ascent) * 0.5 - 32))
	result.set_glyph_advance(0, 64, 0xe000, Vector2(64, 0))
	return result
