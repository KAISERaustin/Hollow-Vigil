extends Node
## Public release feed. Paging and request state belong to this service instance.
signal changed
const PAGE_SIZE := 30
var cloud: Node
var entries: Array = []
var busy := false
var has_more := false
var status := ""
var cursor := {}

func refresh() -> void:
	await load_page(true)

func load_page(reset: bool = false) -> void:
	if busy or (not reset and not has_more): return
	busy = true
	status = "Loading changes…"
	changed.emit()
	var body := {} if reset else {"before_date": cursor.get("change_date"), "before_created_at": cursor.get("created_at"), "before_id": cursor.get("id")}
	var result: Dictionary = {"ok": false}
	if cloud.configured():
		result = await cloud._request("/rest/v1/rpc/read_change_log", body, false)
	busy = false
	var data: Variant = result.get("data")
	if not result.get("ok", false) or not valid_page(data):
		status = "Couldn't load changes. Check your connection and try again."
		changed.emit()
		return
	if reset: entries.clear()
	has_more = data.size() > PAGE_SIZE
	for entry in data.slice(0, PAGE_SIZE):
		entries.append(entry)
	if not entries.is_empty(): cursor = entries.back()
	status = "No changes posted yet." if entries.is_empty() else ""
	changed.emit()

static func valid_page(data: Variant) -> bool:
	if not data is Array or data.size() > PAGE_SIZE + 1: return false
	for entry in data:
		if not entry is Dictionary: return false
		if not entry.get("summary") is String or entry.summary.strip_edges().is_empty() or entry.summary.length() > 300: return false
		if not entry.get("change_date") is String or entry.change_date.length() != 10: return false
		if not entry.get("id") is String: return false
		if not entry.get("created_at") is String: return false
	return true
