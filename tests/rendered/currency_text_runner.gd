extends SceneTree
const UI = preload("res://scripts/ui/shared/interface.gd")
const Currency = preload("res://scripts/ui/shared/currency_text.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var panel := PanelContainer.new()
	panel.theme = UI.theme()
	panel.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, 12))
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	panel.add_child(column)
	for pixels in [14, 16, 18, 24, 30]:
		var label := UI.label("60 gold · Gold / sec · 120 GOLD", pixels)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		column.add_child(label)
	column.add_child(UI.button("Build Ashneedle · 60 gold", func(): pass))
	column.add_child(UI.paragraph("Starting gold and lives apply when starting this level. Keep gold for upgrades. Gold per cleared wave is the default reward."))
	var live := UI.value("0 gold")
	column.add_child(live)
	live.text = "Collected 1,250 gold"
	assert(TranslationServer.translate("60 gold · GOLD · Gold") == "60 " + Currency.SYMBOL + " · " + Currency.SYMBOL + " · " + Currency.SYMBOL)
	assert(TranslationServer.translate("golden marigold starting_gold") == "golden marigold starting_gold")
	assert(UI.font().has_char(0xe000))
	var cards := preload("res://scripts/ui/towers/tower_choice.gd").build_list({}, func(_kind): pass, "", 1000)
	column.add_child(cards)
	for button in cards.get_node("Cards").get_children():
		var kind: String = button.get_meta("tower_kind")
		var price := UI.label(UI.exact_money(Balance.TOWERS[kind].cost) + " gold", 14)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.get_child(0).get_child(0).add_child(price)
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/currency-%dx%d.png" % [dimensions.x, dimensions.y])
	print("CURRENCY_TEXT_PASS: replacements, word boundaries, dynamic text and three portrait renders")
	quit(0)
