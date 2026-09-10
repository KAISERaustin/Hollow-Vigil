extends Node
## Explicit, private feedback uploads. Draft and request identity belong to this instance.
signal changed
const Codec = preload("res://scripts/cloud/cloud_codec.gd")
const MAX_TITLE := 120
const MAX_DESCRIPTION := 5000
var cloud: Node
var title := ""
var description := ""
var busy := false
var status := ""
var pending := {}

func update_draft(report_title: String, report_description: String) -> void:
	if busy: return
	title = report_title
	description = report_description
	status = ""
	changed.emit()

static func validation_error(report_title: String, report_description: String) -> String:
	if report_title.strip_edges().is_empty() or report_title.length() > MAX_TITLE:
		return "Enter a title with 1–120 characters."
	if report_description.strip_edges().is_empty() or report_description.length() > MAX_DESCRIPTION:
		return "Enter a description with 1–5,000 characters."
	return ""

func upload() -> bool:
	if busy: return false
	status = validation_error(title, description)
	if not status.is_empty():
		changed.emit()
		return false
	if not cloud.configured():
		status = "Bug reports are unavailable right now. Your draft is kept here."
		changed.emit()
		return false
	var payload := {"title": title.strip_edges(), "description": description.strip_edges(),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "unknown")), "platform": OS.get_name()}
	# Keep the same unpredictable ID after a timeout, until the draft changes.
	var previous := pending.duplicate()
	previous.erase("id")
	if previous != payload:
		pending = payload
		pending["id"] = Codec.uuid()
	busy = true
	status = "Uploading bug report…"
	changed.emit()
	# Reporting also works when account sign-in itself is broken. No account,
	# saved game, device identifier, or log is attached to the report.
	var result: Dictionary = await cloud._request("/rest/v1/bug_reports", pending.duplicate(true), false)
	busy = false
	var data: Variant = result.get("data")
	var already_reported: bool = int(result.get("code", 0)) == 409 and data is Dictionary and data.get("code") == "23505"
	if result.get("ok", false) or already_reported:
		title = ""
		description = ""
		pending.clear()
		status = "Bug report uploaded. Thank you!"
	else:
		status = "Couldn't upload. Your draft is kept here. Check your connection and try Upload again."
	changed.emit()
	return result.get("ok", false) or duplicate
