extends Control

const UI = preload("res://scripts/ui/shared/interface.gd")
const Illustration = preload("res://scripts/ui/shared/welcome_art.gd")
var title: Label
var hero_space: Control
var modes: VBoxContainer
var subtitle: Label
var footer_rule: Control

func configure(campaign: Callable, settings: Callable = Callable()) -> void:
	name = "WelcomeMenu"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 520
	hero_space = Control.new()
	hero_space.name = "HeroClearance"
	hero_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero_space)
	title = UI.heading("PICKARD", 44)
	title.name = "ScreenTitle"
	title.accessibility_name = "Pickard"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_font: FontVariation = UI.font(600, true).duplicate()
	title_font.spacing_glyph = 4
	title.add_theme_font_override("font", title_font)
	title.add_theme_color_override("font_color", UI.PANEL)
	add_child(title)
	subtitle = UI.label("THE KNIGHT", 12, UI.PANEL)
	var motto_font: FontVariation = UI.font(600).duplicate()
	motto_font.spacing_glyph = 3
	subtitle.add_theme_font_override("font", motto_font)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)
	footer_rule = Illustration.new()
	footer_rule.illustration = "rule"
	add_child(footer_rule)
	modes = VBoxContainer.new()
	modes.add_theme_constant_override("separation", 14)
	add_child(modes)
	var campaign_button := UI.gold_button("Campaign", campaign, 56)
	campaign_button.name = "OpenCampaign"
	campaign_button.accessibility_description = "Join Pickard the knight in the Campaign."
	modes.add_child(campaign_button)
	if settings.is_valid():
		var settings_button := UI.gold_button("Settings", settings, 56)
		settings_button.name = "MainSettings"
		modes.add_child(settings_button)
	resized.connect(arrange, CONNECT_DEFERRED)
	modes.minimum_size_changed.connect(arrange, CONNECT_DEFERRED)
	call_deferred("arrange")

func arrange() -> void:
	var width := size.x
	title.add_theme_font_size_override("font_size", clampi(int(width / 7.5), 32, 52))
	var title_height := title.get_minimum_size().y
	var buttons_height := modes.get_combined_minimum_size().y
	# The viewport owns the illustration; this safe-area overlay owns live UI.
	custom_minimum_size.y = 520
	var top := 0.0 if size.y < 650 else size.y * 0.025
	title.position = Vector2(0, top)
	title.size = Vector2(width, title_height)
	subtitle.position = Vector2(0, title.get_rect().end.y)
	subtitle.size = Vector2(width, 20)
	footer_rule.position = Vector2(0, subtitle.get_rect().end.y + 8)
	footer_rule.size = Vector2(width, 16)
	var button_width := minf(320, width - 16)
	modes.size = Vector2(button_width, buttons_height)
	modes.position = Vector2((width - button_width) * 0.5, roundf(size.y - buttons_height - 8))
	hero_space.position = Vector2(0, footer_rule.get_rect().end.y + 8)
	hero_space.size = Vector2(width, maxf(0, modes.position.y - hero_space.position.y - 8))
