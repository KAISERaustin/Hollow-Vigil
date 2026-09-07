extends RefCounted
## Explicit clipboard action shared by code/link forms on touch and desktop.
const UI = preload("res://scripts/ui/shared/interface.gd")

static func paste_button(entry: LineEdit) -> Button:
	var button := UI.button("Paste code", func():
		if not entry.editable: return
		entry.select_all()
		entry.menu_option(LineEdit.MENU_PASTE)
	)
	button.name = "PasteSignInCode"
	button.accessibility_name = "Paste sign-in code or link from clipboard"
	# Keep the field's keyboard and selection stable while the action is tapped.
	button.focus_mode = Control.FOCUS_NONE
	return button
