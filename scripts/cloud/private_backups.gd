extends Node
## Explicit account-private uploads and recovery. No timers, queues or automatic retries.
signal changed
const Codec = preload("res://scripts/cloud/cloud_codec.gd")
const CampaignSlots = preload("res://scripts/persistence/campaign_slots.gd")
var app: Control
var cloud: Node
var slots := VigilSaveSlots.new()
var campaign_slots := CampaignSlots.new()
var state_path := "user://vigil-private-backups.cfg"
var state := {}
var remote_games: Array = []
var conflicts := {}
var busy := false
var status := "Saved on this device. Cloud uploads are manual."
var last_account := ""
var deleted_builds := {}
var hidden_builds := {}

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(state_path) == OK:
		var saved: Variant = config.get_value("backups", "accounts", {})
		if saved is Dictionary: state = saved
		var hidden: Variant = config.get_value("backups", "hidden_builds", {})
		if hidden is Dictionary: hidden_builds = hidden

# Called only by explicit account/library actions, never by frame polling.
func refresh_account() -> void:
	if cloud.player_id == last_account: return
	last_account = cloud.player_id
	remote_games.clear()
	conflicts.clear()
	status = "Saved on this device. Cloud uploads are manual."

static func fingerprint(snapshot: Dictionary) -> String:
	# Parse once to normalize StringName keys and JSON numeric representations.
	return JSON.stringify(JSON.parse_string(JSON.stringify(snapshot)), "", true).sha256_text()

func _account() -> Dictionary:
	refresh_account()
	if not state.has(cloud.player_id): state[cloud.player_id] = {"games": {}, "builds": {}}
	return state[cloud.player_id]

func _save_state() -> bool:
	var config := ConfigFile.new()
	config.set_value("backups", "accounts", state)
	config.set_value("backups", "hidden_builds", hidden_builds)
	return config.save(state_path + ".tmp") == OK and DirAccess.rename_absolute(state_path + ".tmp", state_path) == OK

func local_games() -> Array:
	var result := []
	for type in ["campaign"]:
		for slot in 3:
			var snapshot: Dictionary = campaign_slots.summary(slot)
			if snapshot.is_empty(): continue
			result.append({"game_type": type, "slot": slot, "snapshot": snapshot, "hash": fingerprint(snapshot)})
	return result

func unreadable_games() -> int:
	var count := 0
	for slot in 3:
		if campaign_slots.occupied(slot) and campaign_slots.summary(slot).is_empty(): count += 1
	return count

func game_status(type: String, slot: int) -> String:
	refresh_account()
	if not cloud.signed_in(): return "Saved on this device · Sign in to upload manually"
	var key := type + ":" + str(slot)
	if conflicts.has(key): return "Saved on this device · Choose which version to keep in Backups"
	var saved: Dictionary = campaign_slots.summary(slot)
	var known: Dictionary = _account().games.get(key, {})
	if known.get("revision", -1) == 0 and not saved.is_empty() and known.get("hash") == fingerprint(saved): return "Saved on this device · Cloud backup deleted; upload manually to save again"
	if not saved.is_empty() and known.get("hash") == fingerprint(saved): return "Saved on this device · Private backup up to date"
	return "Saved on this device · Upload manually to update cloud"

func library_status() -> String:
	return "Cloud uploads are manual. Open a build and choose Upload build." if cloud.signed_in() else "Sign in, then choose Upload build to save it to cloud."

func upload_build(code: String) -> bool:
	if busy or cloud.busy: return false
	refresh_account()
	if not cloud.signed_in():
		status = "Sign in, then choose Upload build again."
		return false
	var entry := slots.reusable_entry(slots.shared_entry(code))
	if entry.is_empty():
		status = "This build could not be uploaded. Your local copy is safe."
		return false
	busy = true
	cloud.busy = true
	var account_id: String = cloud.player_id
	var epoch: int = cloud.generation
	var account := _account()
	var build_hash: String = entry.code.sha256_text()
	status = "Uploading build…"
	changed.emit()
	var response: Dictionary = await cloud._rpc("put_private_build", {"build_hash": build_hash, "configuration": entry.code})
	busy = false
	if epoch == cloud.generation: cloud.busy = false
	if account_id != cloud.player_id or epoch != cloud.generation:
		refresh_account()
		return false
	var ok: bool = response.get("ok", false) and response.get("data") == true
	if ok:
		account.builds[build_hash] = true
		ok = _save_state()
	status = "Build uploaded to your private cloud storage." if ok else "Upload did not finish. Your local copy is safe. Choose Upload build to retry."
	changed.emit()
	return ok

func cloud_entries() -> Array:
	var entries := []
	for source in slots.shared_configurations("all"):
		var entry := slots.reusable_entry(source)
		if entry.is_empty(): continue
		entry.source_code = source.code
		entries.append(entry)
	return entries

# Only explicit upload/recovery controls invoke this operation.
func sync_now(upload: bool = true) -> void:
	if busy or cloud.busy: return
	if not cloud.signed_in(): status = "Sign in to upload or recover saved games and My builds."; changed.emit(); return
	refresh_account()
	busy = true
	cloud.busy = true
	var account_id: String = cloud.player_id
	var epoch: int = cloud.generation
	var account := _account()
	var ok := true
	status = "Uploading saved games and My builds…" if upload else "Recovering cloud saves and My builds…"
	changed.emit()
	var deleted: Dictionary = await cloud._rpc("list_deleted_private_builds", {})
	if account_id != cloud.player_id or epoch != cloud.generation: _finish(false, epoch, upload); return
	if not deleted.get("ok", false) or not deleted.get("data") is Array: _finish(false, epoch, upload); return
	deleted_builds.clear()
	for build_hash in deleted.data: deleted_builds[build_hash] = true
	for entry in cloud_entries():
		if deleted_builds.has(entry.code.sha256_text()) and not slots.delete_shared(entry.source_code): _finish(false, epoch, upload); return
	for item in (local_games() if upload else []):
		var key: String = item.game_type + ":" + str(item.slot)
		if conflicts.has(key): continue
		var known: Dictionary = account.games.get(key, {})
		if known.get("hash") == item.hash: continue
		var response: Dictionary = await cloud._rpc("put_private_game", {"game_type": item.game_type, "slot_number": item.slot,
			"snapshot": item.snapshot, "expected_revision": int(known.get("revision", 0)), "content_hash": item.hash})
		if account_id != cloud.player_id or epoch != cloud.generation: _finish(false, epoch, upload); return
		if not response.get("ok", false) or not response.get("data") is Dictionary: ok = false; break
		var data: Dictionary = response.data
		if data.get("conflict", false):
			conflicts[key] = data
		else:
			account.games[key] = {"revision": int(data.revision), "hash": item.hash}
			if not _save_state(): ok = false; break
	if ok and upload:
		for entry in cloud_entries():
			var build_hash: String = entry.code.sha256_text()
			if account.builds.has(build_hash): continue
			var response: Dictionary = await cloud._rpc("put_private_build", {"build_hash": build_hash, "configuration": entry.code})
			if account_id != cloud.player_id or epoch != cloud.generation: _finish(false, epoch, upload); return
			if not response.get("ok", false): ok = false; break
			account.builds[build_hash] = true
			if not _save_state(): ok = false; break
	if ok:
		var response: Dictionary = await cloud._rpc("list_private_games", {})
		if account_id != cloud.player_id or epoch != cloud.generation: _finish(false, epoch, upload); return
		ok = response.get("ok", false) and response.get("data") is Array
		if ok:
			remote_games = response.data.filter(func(remote): return remote.get("game_type") == "campaign")
			for remote in remote_games:
				var key: String = remote.game_type + ":" + str(remote.slot_number)
				var known: Dictionary = account.games.get(key, {})
				if not known.is_empty() and known.get("revision", 0) != remote.revision:
					conflicts[key] = remote.duplicate(true)
	if ok:
		var local_builds := {}
		for entry in cloud_entries(): local_builds[entry.code.sha256_text()] = true
		var page := 0
		while true:
			var response: Dictionary = await cloud._rpc("list_private_builds", {"page_number": page})
			if account_id != cloud.player_id or epoch != cloud.generation: _finish(false, epoch, upload); return
			if not response.get("ok", false) or not response.get("data") is Array: ok = false; break
			for entry in response.data:
				if not entry.get("configuration") is String or entry.get("build_hash") != entry.configuration.sha256_text(): ok = false; break
				if hidden_builds.has(entry.build_hash) or slots.shared_entry(entry.configuration).is_empty(): continue
				if not local_builds.has(entry.build_hash):
					if not slots.save_shared(entry.configuration): ok = false; break
					local_builds[entry.build_hash] = true
				account.builds[entry.build_hash] = true
			if not _save_state(): ok = false
			if not ok or response.data.is_empty(): break
			page += 1
	_finish(ok, epoch, upload)

func _finish(ok: bool, epoch: int, upload: bool = true) -> void:
	busy = false
	if cloud.generation == epoch: cloud.busy = false
	if ok:
		status = "Saved games and My builds are backed up." if conflicts.is_empty() else "Some games have different cloud versions. Choose which version to keep below."
		if not upload: status = "Cloud saves refreshed and My builds recovered. Nothing was uploaded."
		if unreadable_games() > 0: status += " Some local games need recovery before they can be backed up."
	else:
		status = "Cloud operation did not finish. Your local saves are safe. Choose the action again to retry."
	changed.emit()

func read_backup(type: String, slot: int) -> Dictionary:
	if type != "campaign" or busy or cloud.busy: return {}
	var account_id: String = cloud.player_id
	var epoch: int = cloud.generation
	busy = true
	cloud.busy = true
	var response: Dictionary = await cloud._rpc("read_private_game", {"game_type": type, "slot_number": slot})
	busy = false
	if cloud.generation == epoch: cloud.busy = false
	if account_id != cloud.player_id or epoch != cloud.generation: return {}
	if not response.get("ok", false) or not response.get("data") is Dictionary: return {}
	var value: Dictionary = response.data
	if not value.get("snapshot") is Dictionary: return {}
	if value.get("content_hash") != fingerprint(value.snapshot): return {}
	var valid: bool = CampaignSlots.valid(value.snapshot)
	return value if valid else {}

func keep_local(type: String, slot: int, cloud_revision: int) -> void:
	# Retain the local game and remember the reviewed remote revision for the
	# next explicit upload. A further remote change still conflicts.
	var key := type + ":" + str(slot)
	_account().games[key] = {"revision": cloud_revision, "hash": ""}
	conflicts.erase(key)
	if not _save_state(): status = "Couldn't remember this choice. Please try again."; changed.emit(); return
	status = "Device version kept. Choose Upload to cloud to send it."
	changed.emit()

func accept_restored(type: String, destination: int, source_slot: int, revision: int) -> void:
	var key := type + ":" + str(destination)
	var value: Dictionary = campaign_slots.summary(destination)
	if source_slot == destination:
		_account().games[key] = {"revision": revision, "hash": fingerprint(value)}
	else: _account().games.erase(key)
	conflicts.erase(key)
	_save_state()
	status = "Backup restored on this device. Cloud uploads remain manual."
	changed.emit()

func recovery_games() -> Array:
	var result := []
	var directory := DirAccess.open(slots.base_path.get_base_dir())
	if directory == null: return result
	for filename in directory.get_files():
		if not filename.begins_with(slots.base_path.get_file()) or not (filename.contains(".recovery-") or filename.contains(".archived-") or filename.contains(".before-cloud-")): continue
		if filename.ends_with(".tmp") or filename.ends_with(".bak") or filename.ends_with(".cloud-outbox"): continue
		var path := slots.base_path.get_base_dir().path_join(filename)
		var campaign := campaign_slots.storage.read_candidate(path)
		var type := "campaign"
		var snapshot: Dictionary = campaign
		if not snapshot.is_empty(): result.append({"game_type": type, "snapshot": snapshot, "path": path})
	return result

func delete_recovery(path: String) -> bool:
	# Only enumerated recovery files can be deleted, never an active slot or arbitrary path.
	for entry in recovery_games():
		if entry.path == path: return DirAccess.remove_absolute(path) == OK
	return false

func delete_cloud_record(endpoint: String, payload: Dictionary, account_id: String) -> bool:
	if busy or cloud.busy or not cloud.signed_in() or account_id != cloud.player_id: return false
	busy = true
	cloud.busy = true
	var epoch: int = cloud.generation
	var response: Dictionary = await cloud._rpc(endpoint, payload)
	busy = false
	if epoch == cloud.generation: cloud.busy = false
	return account_id == cloud.player_id and epoch == cloud.generation and response.get("ok", false) and response.get("data") == true

func delete_game(remote: Dictionary, account_id: String) -> bool:
	if not await delete_cloud_record("delete_private_game", {"game_type": remote.game_type, "slot_number": int(remote.slot_number), "expected_revision": int(remote.revision)}, account_id): return false
	var key: String = remote.game_type + ":" + str(remote.slot_number)
	var snapshot: Dictionary = campaign_slots.summary(int(remote.slot_number))
	_account().games[key] = {"revision": 0, "hash": fingerprint(snapshot)}
	conflicts.erase(key)
	remote_games.erase(remote)
	return _save_state()

func delete_build(code: String, account_id: String) -> bool:
	if busy or cloud.busy: return false
	var entry := slots.reusable_entry(slots.shared_entry(code))
	if entry.is_empty(): return false
	var remote_code: String = entry.code
	if account_id != "":
		if not await delete_cloud_record("delete_private_build", {"build_hash": remote_code.sha256_text()}, account_id): return false
	hidden_builds[remote_code.sha256_text()] = true
	if not _save_state(): return false
	return slots.delete_shared(code)
