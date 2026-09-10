extends Node

signal changed
const Codec = preload("res://scripts/cloud/cloud_codec.gd")
var cloud: Node
var outbox_path := "user://vigil-public-builds.cfg"
var outbox: Array = []
var busy := false
var status := ""

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(outbox_path) == OK:
		var saved: Variant = config.get_value("builds", "outbox", [])
		if saved is Array:
			outbox = saved

# Publication attempts are explicit too; sign-in/reconnection never drains this file.
func _process(_delta: float) -> void:
	pass

func _save() -> bool:
	var config := ConfigFile.new()
	config.set_value("builds", "outbox", outbox)
	return config.save(outbox_path + ".tmp") == OK and DirAccess.rename_absolute(outbox_path + ".tmp", outbox_path) == OK

func queue_export(code: String) -> bool:
	var slots := VigilSaveSlots.new()
	var snapshot := slots.reusable_entry(slots.shared_entry(code))
	if snapshot.is_empty():
		status = "This configuration could not be published."
		return false
	outbox.append({"id": Codec.uuid(), "owner": cloud.player_id, "configuration": JSON.parse_string(snapshot.code), "created_at": Time.get_datetime_string_from_system(true) + "Z"})
	if not _save():
		outbox.pop_back()
		status = "Saved locally, but couldn't queue the public upload. Please export again."
		return false
	status = "Public upload prepared. Choose Upload to send it." if cloud.signed_in() else "Saved locally. Sign in, set your name, then choose Retry public uploads."
	changed.emit()
	return true

func flush() -> void:
	if busy or cloud.busy or not cloud.signed_in():
		return
	if cloud.display_name.is_empty():
		status = "Public upload pending. Set your name in Settings → Account & cloud saves."
		changed.emit()
		return
	busy = true
	cloud.busy = true
	var epoch: int = cloud.generation
	# Refresh account metadata in the JWT before the server snapshots the author name.
	cloud.expires_at = 0.0
	var account_id: String = cloud.player_id
	for item in outbox.duplicate():
		var slots := VigilSaveSlots.new()
		var entry := slots.reusable_entry(slots.shared_entry(JSON.stringify(item.get("configuration", {}))))
		if entry.is_empty(): continue
		if item.owner != "" and item.owner != account_id:
			continue
		item.configuration = JSON.parse_string(entry.code)
		# Bind an offline export before the first request, so account changes cannot republish it.
		if item.owner == "":
			item.owner = account_id
			if not _save():
				break
		var result: Dictionary = await cloud._rpc("publish_reusable_build", {"build_id": item.id, "configuration": item.configuration, "exported_at": item.created_at})
		if cloud.player_id != account_id:
			break
		if not result.ok:
			status = "Public upload pending. Check your connection and account name, then choose Retry public uploads."
			break
		outbox.erase(item)
		if not _save():
			outbox.append(item)
			status = "Published; choose Retry public uploads to confirm safely."
			break
		status = "Configuration published to Community."
	busy = false
	if cloud.generation == epoch:
		cloud.busy = false
	changed.emit()

func list_page(page: int) -> Dictionary:
	return await cloud._request("/rest/v1/rpc/list_public_builds", {"page_number": maxi(0, page)}, false)

func read_build(id: String) -> Dictionary:
	if not Codec.valid_uuid(id):
		return {}
	var result: Dictionary = await cloud._request("/rest/v1/rpc/read_public_build", {"build_id": id}, false)
	if not result.ok or not result.data is Dictionary:
		return {}
	var code := JSON.stringify(result.data.get("configuration"))
	return VigilSaveSlots.new().shared_entry(code)

func list_configurations(page: int, kind: String, level: int = -1) -> Dictionary:
	if kind == "all": return await cloud._request("/rest/v1/rpc/list_build_library", {"page_number": maxi(0, page)}, false)
	return await cloud._request("/rest/v1/rpc/list_shared_configurations", {"page_number": maxi(0, page), "content_kind": kind, "level_index": level}, false)
