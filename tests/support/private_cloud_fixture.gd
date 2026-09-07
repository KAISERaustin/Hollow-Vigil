extends "res://scripts/cloud/cloud_service.gd"
## Deterministic network boundary; the real backup and publication services run unchanged.
var accounts := {}
var sent: Array = []
var fail_next := false
var change_account_during_read := false
var publications := {}
var unavailable := false

func _ready() -> void: pass
func _process(_delta: float) -> void: pass

func _request(path: String, body: Dictionary, _authenticated: bool) -> Dictionary:
	return await _rpc(path.get_file(), body)

func _rpc(method: String, body: Dictionary) -> Dictionary:
	sent.append({"method": method, "body": body.duplicate(true), "owner": player_id})
	var owner := player_id
	await get_tree().process_frame
	if change_account_during_read:
		change_account_during_read = false
		player_id = Codec.uuid()
		generation += 1
		busy = false
		return {"ok": true, "data": {}}
	if fail_next or unavailable:
		fail_next = false
		return {"ok": false}
	if not accounts.has(owner): accounts[owner] = {"games": {}, "builds": {}}
	var account: Dictionary = accounts[owner]
	match method:
		"put_private_game":
			var key: String = body.game_type + ":" + str(body.slot_number)
			var previous: Dictionary = account.games.get(key, {})
			var revision: int = previous.get("revision", 0)
			if previous.get("content_hash") == body.content_hash: return {"ok": true, "data": {"revision": revision, "conflict": false}}
			if revision != int(body.expected_revision): return {"ok": true, "data": {"revision": revision, "conflict": true}}
			account.games[key] = {"snapshot": body.snapshot.duplicate(true), "content_hash": body.content_hash, "revision": revision + 1}
			return {"ok": true, "data": {"revision": revision + 1, "conflict": false}}
		"list_private_games":
			var games := []
			for key in account.games:
				var saved: Dictionary = account.games[key]
				games.append({"game_type": key.get_slice(":", 0), "slot_number": int(key.get_slice(":", 1)), "revision": saved.revision,
					"content_hash": saved.content_hash, "name": saved.snapshot.get("name", saved.snapshot.get("setup", {}).get("name", "Saved game")), "mode": saved.snapshot.mode})
			return {"ok": true, "data": games}
		"read_private_game": return {"ok": true, "data": account.games.get(body.game_type + ":" + str(body.slot_number), {}).duplicate(true)}
		"put_private_build": account.builds[body.build_hash] = body.configuration; return {"ok": true, "data": true}
		"list_private_builds":
			var keys: Array = account.builds.keys()
			keys.sort()
			var page := int(body.page_number)
			return {"ok": true, "data": [{"build_hash": keys[page], "configuration": account.builds[keys[page]]}] if page < keys.size() else []}
		"publish_reusable_build": publications[body.build_id] = body.configuration; return {"ok": true, "data": body.build_id}
		"list_build_library":
			var builds := []
			for key in publications:
				var value: Dictionary = JSON.parse_string(publications[key].payload)
				builds.append({"id": key, "title": value.setup.name, "description": value.setup.description, "author_name": "Fixture player", "contents_summary": "Selected starting stats"})
			return {"ok": true, "data": builds.slice(int(body.page_number) * 20, (int(body.page_number) + 1) * 20)}
		"read_public_build":
			return {"ok": true, "data": {"configuration": publications.get(body.build_id, {})}}
	return {"ok": false}
