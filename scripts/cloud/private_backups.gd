extends Node
## Account-private game snapshots and immutable library union. No publication side effects.
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
var enabled := true
var due := 3.0
var retry_delay := 15.0
var status := "Saved on this device. Sign in for automatic private backups."
var last_account := ""
var deleted_builds := {}

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(state_path) == OK:
		var saved: Variant = config.get_value("backups", "accounts", {})
		if saved is Dictionary: state = saved

func _process(delta: float) -> void:
	if not enabled or busy: return
	if cloud.player_id != last_account:
		last_account = cloud.player_id
		remote_games.clear()
		conflicts.clear()
		due = 1.0
	if not cloud.signed_in(): return
	due -= delta
	if due <= 0 and not cloud.busy: sync_now()

func queue_backup() -> void:
	due = minf(due, 3.0)
	changed.emit()

static func fingerprint(snapshot: Dictionary) -> String:
	# Parse once to normalize StringName keys and JSON numeric representations.
	return JSON.stringify(JSON.parse_string(JSON.stringify(snapshot)), "", true).sha256_text()

func _account() -> Dictionary:
	if not state.has(cloud.player_id): state[cloud.player_id] = {"games": {}, "builds": {}}
	return state[cloud.player_id]

func _save_state() -> bool:
	var config := ConfigFile.new()
	config.set_value("backups", "accounts", state)
	return config.save(state_path + ".tmp") == OK and DirAccess.rename_absolute(state_path + ".tmp", state_path) == OK

func local_games() -> Array:
	var result := []
	for type in ["campaign", "infinite"]:
		for slot in 3:
			var snapshot: Dictionary = campaign_slots.summary(slot) if type == "campaign" else slots.summary(slot)
			if snapshot.is_empty(): continue
			result.append({"game_type": type, "slot": slot, "snapshot": snapshot, "hash": fingerprint(snapshot)})
	return result

func unreadable_games() -> int:
	var count := 0
	for slot in 3:
		if campaign_slots.occupied(slot) and campaign_slots.summary(slot).is_empty(): count += 1
		if slots.occupied(slot) and slots.summary(slot).is_empty(): count += 1
	return count

func game_status(type: String, slot: int) -> String:
	if not cloud.signed_in(): return "Saved on this device · Sign in for automatic backups"
	var key := type + ":" + str(slot)
	if conflicts.has(key): return "Saved on this device · Choose which version to keep in Backups"
	var saved: Dictionary = campaign_slots.summary(slot) if type == "campaign" else slots.summary(slot)
	var known: Dictionary = _account().games.get(key, {})
	if not saved.is_empty() and known.get("hash") == fingerprint(saved): return "Saved on this device · Private backup up to date"
	return "Saved on this device · Private backup pending"

func library_status() -> String:
	if not cloud.signed_in(): return "Sign in for automatic private backup."
	var pending := 0
	for entry in slots.shared_configurations("all"):
		if not _account().builds.has(entry.code.sha256_text()): pending += 1
	return "Private library backup up to date." if pending == 0 else "%d private build backups pending." % pending

func sync_now() -> void:
	if busy or cloud.busy: return
	if not cloud.signed_in(): status = "Sign in to back up saved games and My builds."; changed.emit(); return
	if last_account != cloud.player_id:
		last_account = cloud.player_id
		remote_games.clear()
		conflicts.clear()
	busy = true
	cloud.busy = true
	var owner: String = cloud.player_id
	var epoch: int = cloud.generation
	var account := _account()
	var ok := true
	status = "Backing up saved games and My builds…"
	changed.emit()
	var deleted: Dictionary = await cloud._rpc("list_deleted_private_builds", {})
	if owner != cloud.player_id or epoch != cloud.generation: _finish(false, epoch); return
	if not deleted.get("ok", false) or not deleted.get("data") is Array: _finish(false, epoch); return
	deleted_builds.clear()
	for hash in deleted.data: deleted_builds[hash] = true
	for entry in slots.shared_configurations("all"):
		if deleted_builds.has(entry.code.sha256_text()) and not slots.delete_shared(entry.code): _finish(false, epoch); return
	for item in local_games():
		var key: String = item.game_type + ":" + str(item.slot)
		if conflicts.has(key): continue
		var known: Dictionary = account.games.get(key, {})
		if known.get("hash") == item.hash: continue
		var response: Dictionary = await cloud._rpc("put_private_game", {"game_type": item.game_type, "slot_number": item.slot,
			"snapshot": item.snapshot, "expected_revision": int(known.get("revision", 0)), "content_hash": item.hash})
		if owner != cloud.player_id or epoch != cloud.generation: _finish(false, epoch); return
		if not response.get("ok", false) or not response.get("data") is Dictionary: ok = false; break
		var data: Dictionary = response.data
		if data.get("conflict", false):
			conflicts[key] = data
		else:
			account.games[key] = {"revision": int(data.revision), "hash": item.hash}
			if not _save_state(): ok = false; break
	if ok:
		for entry in slots.shared_configurations("all"):
			var hash: String = entry.code.sha256_text()
			if account.builds.has(hash): continue
			var response: Dictionary = await cloud._rpc("put_private_build", {"build_hash": hash, "configuration": entry.code})
			if owner != cloud.player_id or epoch != cloud.generation: _finish(false, epoch); return
			if not response.get("ok", false): ok = false; break
			account.builds[hash] = true
			if not _save_state(): ok = false; break
	if ok:
		var response: Dictionary = await cloud._rpc("list_private_games", {})
		if owner != cloud.player_id or epoch != cloud.generation: _finish(false, epoch); return
		ok = response.get("ok", false) and response.get("data") is Array
		if ok:
			remote_games = response.data
			for remote in remote_games:
				var key: String = remote.game_type + ":" + str(remote.slot_number)
				var known: Dictionary = account.games.get(key, {})
				if not known.is_empty() and known.get("revision", 0) != remote.revision:
					conflicts[key] = remote.duplicate(true)
	if ok:
		var local_builds := {}
		for entry in slots.shared_configurations("all"): local_builds[entry.code.sha256_text()] = true
		var page := 0
		while true:
			var response: Dictionary = await cloud._rpc("list_private_builds", {"page_number": page})
			if owner != cloud.player_id or epoch != cloud.generation: _finish(false, epoch); return
			if not response.get("ok", false) or not response.get("data") is Array: ok = false; break
			for entry in response.data:
				if not entry.get("configuration") is String or entry.get("build_hash") != entry.configuration.sha256_text(): ok = false; break
				if not local_builds.has(entry.build_hash):
					if not slots.save_shared(entry.configuration): ok = false; break
					local_builds[entry.build_hash] = true
				account.builds[entry.build_hash] = true
			if not _save_state(): ok = false
			if not ok or response.data.is_empty(): break
			page += 1
	_finish(ok, epoch)

func _finish(ok: bool, epoch: int) -> void:
	busy = false
	if cloud.generation == epoch: cloud.busy = false
	if ok:
		retry_delay = 15.0
		due = 60.0
		status = "Saved games and My builds are backed up." if conflicts.is_empty() else "Some games have different cloud versions. Choose which version to keep below."
		if unreadable_games() > 0: status += " Some local games need recovery before they can be backed up."
	else:
		due = retry_delay
		retry_delay = minf(retry_delay * 2.0, 300.0)
		status = "Private backup pending. Your local saves are safe; we'll retry when connected."
	changed.emit()

func read_backup(type: String, slot: int) -> Dictionary:
	if busy or cloud.busy: return {}
	var owner: String = cloud.player_id
	var epoch: int = cloud.generation
	busy = true
	cloud.busy = true
	var response: Dictionary = await cloud._rpc("read_private_game", {"game_type": type, "slot_number": slot})
	busy = false
	if cloud.generation == epoch: cloud.busy = false
	if owner != cloud.player_id or epoch != cloud.generation: return {}
	if not response.get("ok", false) or not response.get("data") is Dictionary: return {}
	var value: Dictionary = response.data
	if not value.get("snapshot") is Dictionary: return {}
	if value.get("content_hash") != fingerprint(value.snapshot): return {}
	var valid: bool = CampaignSlots.valid(value.snapshot) if type == "campaign" else slots.storage.valid_data(value.snapshot)
	return value if valid else {}

func keep_local(type: String, slot: int, cloud_revision: int) -> void:
	# This is an explicit player decision; retain the local game and replace only
	# the reviewed remote revision. A further remote change conflicts again.
	var key := type + ":" + str(slot)
	_account().games[key] = {"revision": cloud_revision, "hash": ""}
	conflicts.erase(key)
	if not _save_state(): status = "Couldn't remember this choice. Please try again."; changed.emit(); return
	await sync_now()

func accept_restored(type: String, destination: int, source_slot: int, revision: int) -> void:
	var key := type + ":" + str(destination)
	var value: Dictionary = campaign_slots.summary(destination) if type == "campaign" else slots.summary(destination)
	if source_slot == destination:
		_account().games[key] = {"revision": revision, "hash": fingerprint(value)}
	else: _account().games.erase(key)
	conflicts.erase(key)
	_save_state()
	queue_backup()

func recovery_games() -> Array:
	var result := []
	var directory := DirAccess.open(slots.base_path.get_base_dir())
	if directory == null: return result
	for filename in directory.get_files():
		if not filename.begins_with(slots.base_path.get_file()) or not (filename.contains(".recovery-") or filename.contains(".archived-") or filename.contains(".before-cloud-")): continue
		if filename.ends_with(".tmp") or filename.ends_with(".bak") or filename.ends_with(".cloud-outbox"): continue
		var path := slots.base_path.get_base_dir().path_join(filename)
		var campaign := campaign_slots.storage.read_candidate(path)
		var type := "campaign" if not campaign.is_empty() else "infinite"
		var snapshot: Dictionary = campaign if not campaign.is_empty() else slots.storage.read_candidate(path)
		if not snapshot.is_empty(): result.append({"game_type": type, "snapshot": snapshot, "path": path})
	return result

func delete_recovery(path: String) -> bool:
	# Only enumerated recovery files can be deleted, never an active slot or arbitrary path.
	for entry in recovery_games():
		if entry.path == path: return DirAccess.remove_absolute(path) == OK
	return false

func delete_cloud_record(endpoint: String, payload: Dictionary, owner: String) -> bool:
	if busy or cloud.busy or not cloud.signed_in() or owner != cloud.player_id: return false
	busy = true
	cloud.busy = true
	var epoch: int = cloud.generation
	var response: Dictionary = await cloud._rpc(endpoint, payload)
	busy = false
	if epoch == cloud.generation: cloud.busy = false
	return owner == cloud.player_id and epoch == cloud.generation and response.get("ok", false) and response.get("data") == true

func delete_game(remote: Dictionary, owner: String) -> bool:
	if not await delete_cloud_record("delete_private_game", {"game_type": remote.game_type, "slot_number": int(remote.slot_number), "expected_revision": int(remote.revision)}, owner): return false
	var key: String = remote.game_type + ":" + str(remote.slot_number)
	var snapshot: Dictionary = campaign_slots.summary(int(remote.slot_number)) if remote.game_type == "campaign" else slots.summary(int(remote.slot_number))
	_account().games[key] = {"revision": 0, "hash": fingerprint(snapshot)}
	conflicts.erase(key)
	remote_games.erase(remote)
	return _save_state()

func delete_build(code: String, owner: String) -> bool:
	if busy or cloud.busy: return false
	if owner != "":
		if not await delete_cloud_record("delete_private_build", {"build_hash": code.sha256_text()}, owner): return false
	return slots.delete_shared(code)
