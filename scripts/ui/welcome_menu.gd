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

func configure(campaign: Callable, infinite: Callable) -> void:
	name = "WelcomeMenu"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 500
	crest = Illustration.new()
	add_child(crest)
	title = UI.heading("Hollow Vigil", 40)
	title.name = "ScreenTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UI.font(750, true))
	title.add_theme_color_override("font_color", Color("211c16"))
	title.add_theme_color_override("font_shadow_color", UI.GOLD)
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	add_child(title)
	subtitle = UI.heading("BUILD  ·  DEFEND  ·  ENDURE", 13)
	var motto_font: FontVariation = UI.font(600, true).duplicate()
	motto_font.spacing_glyph = 1
	subtitle.add_theme_font_override("font", motto_font)
	subtitle.add_theme_color_override("font_color", Color("574329"))
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
	battlefield = Illustration.new()
	battlefield.illustration = "battlefield"
	add_child(battlefield)
	footer_rule = Illustration.new()
	footer_rule.illustration = "rule"
	add_child(footer_rule)
	caption = UI.heading("A quiet world. An endless watch.", 14)
	caption.add_theme_font_override("font", UI.font(500, true))
	caption.add_theme_color_override("font_color", Color("574329"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)
	resized.connect(arrange)
	call_deferred("arrange")

func arrange() -> void:
	var width := size.x
	var height := size.y
	crest.position = Vector2(0, height * 0.035)
	crest.size = Vector2(width, height * 0.22)
	title.add_theme_font_size_override("font_size", mini(42, int(width / 7.6)))
	title.position = Vector2(0, height * 0.25)
	title.size = Vector2(width, 58)
	subtitle.position = Vector2(0, height * 0.25 + 52)
	subtitle.size = Vector2(width, 24)
	var button_width := minf(320, width - 16)
	modes.size = Vector2(button_width, 126)
	modes.position = Vector2((width - button_width) * 0.5, height * 0.5 - 63)
	battlefield.position = Vector2(0, height * 0.66)
	battlefield.size = Vector2(width, height * 0.26)
	caption.position = Vector2(0, height * 0.94)
	caption.size = Vector2(width, 24)
	footer_rule.position = Vector2(0, height * 0.91)
	footer_rule.size = Vector2(width, 12)
