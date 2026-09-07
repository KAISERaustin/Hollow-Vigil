extends PopupPanel
## Reusable, content-sized confirmation with modal input and inline errors.

const UI = preload("res://scripts/ui/shared/interface.gd")
var body: VBoxContainer
var message: Label
var confirm: Button
var scroll: ScrollContainer
var details: VBoxContainer
var popup_width := 380

func configure(heading_text: String, description: String, action: String, callback: Callable) -> void:
	exclusive = true
	transient = true
	add_theme_stylebox_override("panel", UI.surface(UI.PANEL, UI.OUTLINE, 16))
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	add_child(body)
	var heading := UI.heading(heading_text, 24)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(heading)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	UI.keyboard_scroll(scroll, "Confirmation details")
	body.add_child(scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 14)
	scroll.add_child(details)
	details.add_child(UI.paragraph(description, 14))
	message = UI.paragraph("", 13)
	message.hide()
	details.add_child(message)
	confirm = UI.accent_button(action, callback, UI.DANGER)
	confirm.name = "ConfirmAction"
	body.add_child(confirm)
	var cancel := UI.button("Cancel", hide)
	cancel.name = "CancelConfirmation"
	body.add_child(cancel)
	popup_hide.connect(queue_free)
	popup_width = mini(380, int(get_parent().size.x) - 48)
	body.custom_minimum_size.x = popup_width - 32
	popup_centered(Vector2i(popup_width, 0))
	call_deferred("fit_content", popup_width)
	get_parent().resized.connect(func(): fit_content.call_deferred(popup_width))
	details.minimum_size_changed.connect(func(): fit_content.call_deferred(popup_width))
	cancel.grab_focus()

func fit_content(width: int) -> void:
	if not visible: return
	var parent := get_parent() as Control
	var safe := UI.safe_rect(parent).grow(-12)
	width = mini(width, int(safe.size.x))
	body.custom_minimum_size.x = width - 32
	scroll.custom_minimum_size.y = 0
	var chrome := body.get_combined_minimum_size().y + 32
	scroll.custom_minimum_size.y = minf(details.get_combined_minimum_size().y, maxf(0, safe.size.y - chrome))
	size = Vector2i(width, int(chrome + scroll.custom_minimum_size.y))
	position = Vector2i(parent.global_position + safe.get_center() - Vector2(size) * 0.5)

func show_error(error_text: String) -> void:
	message.text = error_text
	message.show()
	fit_content.call_deferred(popup_width)
