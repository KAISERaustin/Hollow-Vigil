extends VBoxContainer
## Reusable report editor; the service owns the draft and request lifecycle.
const UI = preload("res://scripts/ui/shared/interface.gd")
var service: Node
var title_field: LineEdit
var description_field: TextEdit
var upload_button: Button
var feedback: Label

func _ready() -> void:
	add_theme_constant_override("separation", UI.GAP)
	add_child(UI.paragraph("Tell us what happened and how to reproduce it. Your report is sent privately to the developer."))
	title_field = LineEdit.new()
	title_field.name = "BugReportTitle"
	title_field.max_length = service.MAX_TITLE
	title_field.text = service.title
	title_field.placeholder_text = "Brief summary"
	style_field(title_field)
	title_field.text_changed.connect(func(value: String): service.update_draft(value, service.description))
	add_child(UI.form_field("Title", title_field))
	description_field = TextEdit.new()
	description_field.name = "BugReportDescription"
	description_field.text = service.description
	description_field.placeholder_text = "What happened? What did you expect?"
	description_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description_field.custom_minimum_size.y = 200
	style_field(description_field)
	description_field.text_changed.connect(func(): service.update_draft(service.title, description_field.text))
	add_child(UI.form_field("Description · up to 5,000 characters", description_field))
	add_child(UI.paragraph("Includes the app version and platform. No sign-in required.", 14))
	feedback = UI.paragraph("")
	feedback.name = "BugReportStatus"
	add_child(feedback)
	service.changed.connect(refresh)
	refresh()

func style_field(field: Control) -> void:
	field.custom_minimum_size.y = maxf(field.custom_minimum_size.y, UI.TARGET)
	UI.style_entry(field)
	field.add_theme_font_size_override("font_size", UI.type_size(16))

func refresh() -> void:
	title_field.editable = not service.busy
	description_field.editable = not service.busy
	if title_field.text != service.title: title_field.text = service.title
	if description_field.text != service.description: description_field.text = service.description
	upload_button.disabled = service.busy
	upload_button.text = "Uploading…" if service.busy else "Upload"
	feedback.text = service.status
	feedback.visible = not service.status.is_empty()
	if feedback.visible: call_deferred("reveal_feedback")

func reveal_feedback() -> void:
	await get_tree().process_frame
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(feedback)
			return
		ancestor = ancestor.get_parent()
