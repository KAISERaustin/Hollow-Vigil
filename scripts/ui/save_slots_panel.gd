extends ColorRect

const UI = preload("res://scripts/ui/shared/interface.gd")
var app: VigilApp
var slots := VigilSaveSlots.new()
var header: HBoxContainer
var footer: VBoxContainer
var content: VBoxContainer
var card: PanelContainer
var scroll: ScrollContainer
var welcome_paper: TextureRect
var message: Label
var upload_revision := -1
var view_revision := 0
func _ready() -> void:
	app.public_builds.changed.connect(func():
		if is_instance_valid(message) and upload_revision == view_revision:
			message.text = app.public_builds.status
	)
	name = "SaveSlots"
	color = UI.BG
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	welcome_paper = UI.fullscreen_parchment()
	add_child(welcome_paper)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.plain())
	add_child(card)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	UI.keyboard_scroll(scroll, "Save slots and setup")
	card.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", UI.GAP)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", UI.GAP)
	layout.add_child(header)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	layout.add_child(content)
	footer = VBoxContainer.new()
	footer.name = "SaveActions"
	footer.add_theme_constant_override("separation", UI.GAP)
	layout.add_child(footer)
	resized.connect(fit)
	preload("res://scripts/ui/shared/mobile_layout.gd").attach(self)

func fit() -> void:
	var safe := UI.safe_rect(app).grow(-UI.SCREEN_PADDING)
	card.size = safe.size
	card.position = safe.position

func clear(title: String, header_action: Button = null) -> void:
	view_revision += 1
	UI.tint_parchment(welcome_paper)
	header.get_parent().add_theme_constant_override("separation", UI.GAP)
	header.show()
	footer.show()
	content.size_flags_vertical = Control.SIZE_FILL
	for container in [header, content, footer]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	scroll.set_deferred("scroll_vertical", 0)
	var heading := UI.heading(title, 28)
	heading.name = "ScreenTitle"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(heading)
	if header_action != null:
		header.add_child(header_action)
	message = UI.paragraph("", 13)
	content.add_child(message)
	call_deferred("fit")

func add_card(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.SURFACE))
	content.add_child(panel)
	var body := UI.margin(panel, 12)
	body.add_theme_constant_override("separation", 10)
	body.add_child(UI.heading(title, 18))
	return body

func style_entry(entry: Control) -> void:
	UI.style_entry(entry)

func add_back(back: Button) -> void:
	UI.configure_back_button(back, back.text)
	header.add_child(back)
	header.move_child(back, 0)
