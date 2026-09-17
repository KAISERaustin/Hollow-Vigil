extends PopupPanel
## One illustrated lesson, with fixed dismissal controls and scrolling content.
const UI = preload("res://scripts/ui/shared/interface.gd")
const Portrait = preload("res://scripts/ui/shared/content_portrait.gd")
signal acknowledged(skip_all: bool)
signal canceled
var body: VBoxContainer
var details: VBoxContainer
var scroll: ScrollContainer
var confirm: Button

func configure(lesson: Dictionary) -> void:
	name = "TutorialPopup"
	exclusive = true
	transient = true
	theme = UI.theme()
	UI.popup_scrim(self)
	add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, 11))
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 11)
	add_child(body)
	body.add_child(UI.paragraph("FIELD GUIDE", 14))
	var heading := UI.heading(lesson.title, 24)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(heading)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	UI.keyboard_scroll(scroll, "Tutorial instructions")
	body.add_child(scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 11)
	scroll.add_child(details)
	details.add_child(UI.paragraph(lesson.body, 18))
	for entry in lesson.rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 11)
		row.add_child(Portrait.preview(entry.category, entry.kind, int(entry.get("tier", 1))))
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_child(UI.paragraph(entry.name, 18))
		copy.add_child(UI.paragraph(entry.text, 16))
		row.add_child(copy)
		details.add_child(UI.info_card(row, UI.INSET, 8))
	confirm = UI.gold_button("Got it", func(): acknowledged.emit(false))
	confirm.name = "TutorialGotIt"
	body.add_child(confirm)
	var skip := UI.button("Skip all tips", func(): acknowledged.emit(true))
	skip.name = "TutorialSkipAll"
	body.add_child(skip)
	close_requested.connect(func(): canceled.emit())
	get_parent().resized.connect(fit_content)
	details.minimum_size_changed.connect(func(): fit_content.call_deferred())
	popup_centered(Vector2i(320, 400))
	fit_content.call_deferred()
	confirm.grab_focus()

func fit_content() -> void:
	if not visible: return
	var parent := get_parent() as Control
	var safe := UI.safe_rect(parent).grow(-12)
	var width := mini(400, int(safe.size.x))
	body.custom_minimum_size.x = width - 22
	scroll.custom_minimum_size.y = 0
	var chrome := body.get_combined_minimum_size().y + 22
	scroll.custom_minimum_size.y = minf(details.get_combined_minimum_size().y, maxf(0, safe.size.y - chrome))
	size = Vector2i(width, int(chrome + scroll.custom_minimum_size.y))
	position = Vector2i(parent.global_position + safe.get_center() - Vector2(size) * 0.5)
