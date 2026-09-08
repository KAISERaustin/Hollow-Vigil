extends SceneTree
const Reports = preload("res://scripts/cloud/bug_reports.gd")
var checks := 0
var failures := 0

class Network extends Node:
	var calls: Array = []
	var response := {"ok": false, "code": 0, "data": null}
	func configured() -> bool: return true
	func _request(path: String, body: Dictionary, authenticated: bool) -> Dictionary:
		calls.append({"path": path, "body": body, "authenticated": authenticated})
		await get_tree().process_frame
		return response

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func run() -> void:
	var network := Network.new()
	root.add_child(network)
	var reports := Reports.new()
	reports.cloud = network
	root.add_child(reports)
	check(not await reports.upload() and network.calls.is_empty(), "Blank input never uploads")
	reports.title = "   "
	reports.description = "Steps"
	check(not await reports.upload(), "Whitespace title rejected")
	reports.title = "Title"
	reports.description = "x".repeat(5001)
	check(not await reports.upload(), "Oversized description rejected")
	reports.description = " Steps\nExpected outcome "
	reports.upload()
	check(reports.busy, "Busy while request pending")
	check(not await reports.upload() and network.calls.size() == 1, "Duplicate taps make one request")
	await process_frame
	check(not reports.busy and reports.title == "Title", "Offline failure retains draft")
	var first_id: String = network.calls[0].body.id
	check(not network.calls[0].authenticated and network.calls[0].path == "/rest/v1/bug_reports", "Works without sign-in using existing backend")
	check(network.calls[0].body.size() == 5, "Payload contains only explicit fields")
	await reports.upload()
	check(network.calls[1].body.id == first_id, "Retry keeps request identity")
	reports.title = "Changed title"
	await reports.upload()
	check(network.calls[2].body.id != first_id, "Changed draft gets new identity")
	network.response = {"ok": false, "code": 409, "data": {"code": "23505"}}
	check(await reports.upload(), "Previously accepted retry confirms success")
	check(reports.title.is_empty() and reports.description.is_empty() and reports.pending.is_empty(), "Confirmed upload clears draft")
	reports.title = "Another report"
	reports.description = "Description"
	network.response = {"ok": true, "code": 201, "data": null}
	check(await reports.upload(), "Created response succeeds")
	var other := Reports.new()
	check(other.pending.is_empty() and other.title.is_empty() and not other.busy, "Instances have separate state")
	other.free()
	reports.free()
	network.free()
	print("Bug reports: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
