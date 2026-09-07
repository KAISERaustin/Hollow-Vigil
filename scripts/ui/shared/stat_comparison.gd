extends RefCounted
## A reusable, passive current/previous value card. The owner supplies the values.

const UI = preload("res://scripts/ui/shared/interface.gd")

static func card(caption: String, change: Dictionary, unit: String = "") -> PanelContainer:
	var body := UI.stat(caption, number(change.after, unit))
	body.add_child(UI.paragraph("Was " + number(change.before, unit), UI.CAPTION))
	var difference := UI.heading(signed(change.delta, unit) + " change", UI.CAPTION)
	body.add_child(difference)
	var panel := UI.info_card(body)
	panel.accessibility_name = "%s: %s, previously %s, change %s" % [caption, number(change.after, unit), number(change.before, unit), signed(change.delta, unit)]
	return panel

static func number(amount: float, unit: String = "") -> String:
	return UI.exact_money(amount) + unit

static func signed(amount: float, unit: String = "") -> String:
	return ("+" if amount > 0 else "−" if amount < 0 else "") + number(absf(amount), unit)
