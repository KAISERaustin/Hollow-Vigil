extends PopupPanel
## Reusable, content-sized confirmation with modal input and inline errors.

const UI = preload("res://scripts/ui/shared/interface.gd")
var body: VBoxContainer
var message: Label
var confirm: Button

func configure(title: String, description: String, action: String, callback: Callable) -> void:
	exclusive = true
	transient = true
	add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 4, 16))
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	add_child(body)
	var heading := UI.heading(title, 24)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(heading)
	body.add_child(UI.paragraph(description, 14))
	message = UI.paragraph("", 13)
	message.hide()
	body.add_child(message)
	confirm = UI.accent_button(action, callback, UI.DANGER)
	confirm.name = "ConfirmAction"
	body.add_child(confirm)
	var cancel := UI.button("Cancel", hide)
	cancel.name = "CancelConfirmation"
	body.add_child(cancel)
	popup_hide.connect(queue_free)
	var width := mini(380, int(get_parent().size.x) - 48)
	body.custom_minimum_size.x = width - 32
	popup_centered(Vector2i(width, 0))
	call_deferred("fit_content", width)
	cancel.grab_focus()

func fit_content(width: int) -> void:
	reset_size()
	popup_centered(Vector2i(width, int(body.get_combined_minimum_size().y) + 32))

func show_error(details: String) -> void:
	message.text = details
	message.show()
	reset_size()
