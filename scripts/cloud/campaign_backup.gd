extends Node

signal changed
signal restored
const Codec = preload("res://scripts/cloud/cloud_codec.gd")
const Progress = preload("res://scripts/campaign/progress.gd")
var cloud: Node
var progress: Progress
var status := "Campaign saves on this device. Upload a backup only when you choose."
var remote: Dictionary = {}
var remote_owner := ""
var conflict: Dictionary = {}
var state: Dictionary = {}

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path()) == OK:
		var saved: Variant = cfg.get_value("backup", "state", {})
		if saved is Dictionary and Codec.valid_uuid(saved.get("player_id")) and progress.number(saved.get("revision"), 0, 1e15, true):
			state = saved
			if state.has("pending") and not valid_pending(state.pending): state.erase("pending")
	cloud.changed.connect(account_changed)

func valid_pending(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3 or not Codec.valid_uuid(value.get("mutation")) or not progress.number(value.get("expected_revision"), 0, 1e15, true): return false
	var payload: Variant = value.get("payload")
	return payload is Dictionary and payload.size() == 3 and payload.get("format") == 1 and payload.get("catalog_version") == 1 and progress.number(payload.get("completed_levels"), 0, Progress.Catalog.COUNT, true)

func account_changed() -> void:
	if remote_owner != cloud.player_id:
		remote.clear()
		remote_owner = ""
		status = "Campaign progress is local. Upload or restore only when you choose."
	if conflict.get("player_id", "") != cloud.player_id: conflict.clear()
	changed.emit()

func _path() -> String:
	return progress.path + ".cloud-backup"

func _save_state() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("backup", "state", state)
	return cfg.save(_path() + ".tmp") == OK and DirAccess.rename_absolute(_path() + ".tmp", _path()) == OK

func _say(message: String) -> void:
	status = message
	changed.emit()

func _valid(value: Variant) -> bool:
	return value is Dictionary and value.get("format") == 1 and value.get("catalog_version") == 1 and progress.number(value.get("completed_levels"), 0, Progress.Catalog.COUNT, true) and progress.number(value.get("revision"), 1, 1e15, true)

# These methods have no timer or sign-in callbacks. Only UI actions call them.
func refresh() -> void:
	if cloud.busy or not cloud.signed_in(): return
	remote = {}
	remote_owner = ""
	cloud.busy = true
	_say("Reading campaign backup…")
	var actor: String = cloud.player_id
	var epoch: int = cloud.generation
	var result: Dictionary = await cloud._rpc("read_campaign_backup", {})
	if epoch != cloud.generation or actor != cloud.player_id: return
	cloud.busy = false
	if result.ok and (result.data == null or _valid(result.data)):
		remote = {} if result.data == null else result.data
		remote_owner = actor
		_say("No campaign backup has been uploaded to this account." if remote.is_empty() else "Cloud backup: %d completed levels. Restore only when you choose." % int(remote.completed_levels))
	else:
		_say("Couldn't read the campaign backup. Your local progress is unchanged.")

func upload(replace: bool = false) -> void:
	if cloud.busy or not cloud.signed_in() or progress.blocked: return
	var actor: String = cloud.player_id
	if state.get("player_id") != actor:
		state = {"player_id": actor, "revision": 0}
	if replace:
		if conflict.get("player_id") != actor: return
		state.revision = conflict.revision
		state.erase("pending")
		conflict.clear()
	elif conflict.get("player_id") == actor:
		_say("Choose whether to replace the cloud campaign or restore it.")
		return
	if not state.has("pending"):
		if not progress.flush():
			_say(progress.last_error)
			return
		state.pending = {"payload": {"format": 1, "catalog_version": 1, "completed_levels": int(progress.data.completed_levels)}, "expected_revision": int(state.get("revision", 0)), "mutation": Codec.uuid()}
	if not _save_state():
		_say("Couldn't record the upload attempt. Nothing was uploaded.")
		return
	var pending: Dictionary = state.pending
	cloud.busy = true
	var epoch: int = cloud.generation
	_say("Uploading campaign backup…")
	var result: Dictionary = await cloud._rpc("publish_campaign_backup", pending)
	if epoch != cloud.generation or actor != cloud.player_id: return
	cloud.busy = false
	if result.ok and result.data is Dictionary and result.data.get("status") == "ok" and progress.number(result.data.get("revision"), 1, 1e15, true):
		state.revision = int(result.data.revision)
		state.erase("pending")
		if not _save_state():
			state.pending = pending
			_say("Uploaded, but local confirmation failed. Choose Upload again to confirm safely.")
			return
		remote = pending.payload.duplicate(true)
		remote.revision = state.revision
		remote_owner = actor
		_say("Campaign backup uploaded: %d completed levels. Future progress stays local until you upload again." % int(remote.completed_levels))
	elif result.ok and result.data is Dictionary and result.data.get("status") == "conflict":
		conflict = {"player_id": actor, "revision": int(result.data.revision)}
		_say("This account has a different campaign backup. Choose which progress to keep.")
	else:
		_say("Campaign upload failed. No background retry will run. Choose Upload again when ready.")

func restore() -> void:
	if cloud.busy or not cloud.signed_in(): return
	# Re-read on the explicit restore action instead of trusting stale UI data.
	await refresh()
	if remote_owner != cloud.player_id or remote.is_empty() or not _valid(remote): return
	if not progress.restore_completed_levels(int(remote.completed_levels)):
		_say(progress.last_error)
		return
	state = {"player_id": cloud.player_id, "revision": int(remote.revision)}
	conflict.clear()
	var saved := _save_state()
	restored.emit()
	_say("Campaign restored. Unfinished levels start from the beginning." if saved else "Campaign restored locally; backup confirmation could not be saved. Future uploads may need a conflict choice.")
