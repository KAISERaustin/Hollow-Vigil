extends Control

const UI = preload("res://scripts/ui/shared/interface.gd")
const Illustration = preload("res://scripts/ui/shared/welcome_art.gd")
var title: Label
var crest: Control
var battlefield: Control
var modes: VBoxContainer
var subtitle: Label
var caption: Label
var footer_rule: Control

func configure(campaign: Callable, infinite: Callable, settings: Callable = Callable()) -> void:
	name = "WelcomeMenu"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A book-cover composition; the whole page remains reachable on short screens.
	custom_minimum_size.y = 560
	crest = Illustration.new()
	crest.illustration = "seal"
	add_child(crest)
	title = UI.heading("Hollow\nVigil", 56)
	title.name = "ScreenTitle"
	title.accessibility_name = "Hollow Vigil"
	title.uppercase = true
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_font: FontVariation = UI.font(600, true).duplicate()
	title_font.spacing_glyph = 4
	title.add_theme_font_override("font", title_font)
	title.add_theme_color_override("font_color", UI.PANEL)
	title.add_theme_constant_override("line_spacing", -16)
	add_child(title)
	subtitle = UI.label("KEEP THE LAST LIGHT BURNING", 12, UI.PANEL)
	var motto_font: FontVariation = UI.font(600).duplicate()
	motto_font.spacing_glyph = 1
	subtitle.add_theme_font_override("font", motto_font)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)
	modes = VBoxContainer.new()
	modes.add_theme_constant_override("separation", 14)
	add_child(modes)
	var campaign_button := UI.gold_button("Campaign", campaign, 56)
	campaign_button.name = "OpenCampaign"
	campaign_button.accessibility_description = "Follow the campaign through the world of Hollow Vigil."
	modes.add_child(campaign_button)
	var infinite_button := UI.gold_button("Infinite", infinite, 56)
	infinite_button.name = "OpenInfinite"
	infinite_button.accessibility_description = "Open your saved worlds or begin a new one."
	modes.add_child(infinite_button)
	if settings.is_valid():
		var settings_button := UI.gold_button("Settings", settings, 56)
		settings_button.name = "MainSettings"
		modes.add_child(settings_button)
	battlefield = Illustration.new()
	battlefield.illustration = "landscape"
	add_child(battlefield)
	footer_rule = Illustration.new()
	footer_rule.illustration = "rule"
	add_child(footer_rule)
	caption = UI.label("BUILD   /   DEFEND   /   ENDURE", 12, UI.PANEL)
	caption.add_theme_font_override("font", motto_font)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)
	# Container minimums settle after the first resize, especially on cold startup.
	# Reflow when the button stack settles as well as when the viewport changes.
	resized.connect(arrange, CONNECT_DEFERRED)
	modes.minimum_size_changed.connect(arrange, CONNECT_DEFERRED)
	call_deferred("arrange")

func arrange() -> void:
	var width := size.x
	if width >= 680 and get_viewport_rect().size.y < 540:
		arrange_landscape()
		return
	var height := size.y
	title.add_theme_font_size_override("font_size", clampi(int(width / 6.5), 44, 64))
	var title_height := title.get_minimum_size().y
	var buttons_height := modes.get_combined_minimum_size().y
	# Wide, short viewports scroll the full cover, including its footer.
	custom_minimum_size.y = maxf(560, title_height + buttons_height + 256)
	var landscape_height := clampf(height - title_height - buttons_height - 156, 100, 300)
	var composition_height := title_height + landscape_height + buttons_height + 140
	var top := maxf(0, (height - composition_height) * 0.5)
	crest.position = Vector2(0, top)
	crest.size = Vector2(width, 20)
	title.position = Vector2(0, top + 28)
	title.size = Vector2(width, title_height)
	subtitle.position = Vector2(0, title.get_rect().end.y + 4)
	subtitle.size = Vector2(width, 20)
	battlefield.position = Vector2(0, subtitle.get_rect().end.y + 12)
	battlefield.size = Vector2(width, landscape_height)
	var button_width := minf(320, width - 16)
	modes.size = Vector2(button_width, buttons_height)
	modes.position = Vector2((width - button_width) * 0.5, roundf(battlefield.get_rect().end.y + 20))
	footer_rule.position = Vector2(0, modes.get_rect().end.y + 16)
	footer_rule.size = Vector2(width, 12)
	caption.position = Vector2(0, footer_rule.get_rect().end.y + 8)
	caption.size = Vector2(width, 20)

func arrange_landscape() -> void:
	custom_minimum_size.y = 320
	var identity_width := size.x - 344
	title.add_theme_font_size_override("font_size", 40)
	var title_height := title.get_minimum_size().y
	var art_height := clampf(size.y - title_height - 96, 100, 144)
	var top := maxf(0, (size.y - title_height - art_height - 64) * 0.5)
	crest.position = Vector2(0, top)
	crest.size = Vector2(identity_width, 20)
	title.position = Vector2(0, top + 28)
	title.size = Vector2(identity_width, title_height)
	subtitle.position = Vector2(0, title.get_rect().end.y + 4)
	subtitle.size = Vector2(identity_width, 20)
	battlefield.position = Vector2(0, subtitle.get_rect().end.y + 12)
	battlefield.size = Vector2(identity_width, art_height)
	var buttons_height := modes.get_combined_minimum_size().y
	modes.position = Vector2(size.x - 320, roundf((size.y - buttons_height - 56) * 0.5))
	modes.size = Vector2(320, buttons_height)
	footer_rule.position = Vector2(modes.position.x, modes.get_rect().end.y + 16)
	footer_rule.size = Vector2(320, 12)
	caption.position = Vector2(modes.position.x, footer_rule.get_rect().end.y + 8)
	caption.size = Vector2(320, 20)
