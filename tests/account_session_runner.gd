extends "res://tests/test_runner.gd"
const Service = preload("res://scripts/cloud/cloud_service.gd")
const Store = preload("res://scripts/cloud/session_store.gd")
const Progress = preload("res://scripts/campaign/progress.gd")
const PLAYER := "11111111-1111-4111-8111-111111111111"
const PROJECT := "https://session-fixture.supabase.co"

class FakeService extends Service:
	signal release_refresh
	var responses: Array = []
	var requests: Array = []
	var hold_refresh := false
	func _request(path: String, body: Dictionary, authenticated: bool) -> Dictionary:
		requests.append({"path": path, "body": body.duplicate(true), "authenticated": authenticated})
		if hold_refresh and path.contains("refresh_token"):
			await release_refresh
		return responses.pop_front() if not responses.is_empty() else {"ok": false, "code": 0, "data": null}

var path := "user://account-session-check-" + str(Time.get_ticks_usec()) + ".json"

func response(token: String = "rotated-token", name: String = "Returning player") -> Dictionary:
	return {"ok": true, "code": 200, "data": {"access_token": "verified-access", "refresh_token": token, "expires_in": 3600, "user": {"id": PLAYER, "email": "fixture@example.invalid", "user_metadata": {"display_name": name}}}}

func service() -> FakeService:
	var s := FakeService.new()
	s.game = VigilState.new(72)
	s.game.save_path = path + ".world"
	s.url = PROJECT
	s.key = "sb_publishable_fixture"
	s.session_store.path = path
	s.enabled = false
	return s

func complete(s: FakeService, results: Array) -> void:
	results.append(await s._ensure_session())

func run() -> void:
	var store := Store.new()
	store.path = path
	var fresh := service()
	root.add_child(fresh)
	fresh.game.data.cloud = {"player_id": PLAYER}
	await fresh.restore_session()
	check(not fresh.signed_in() and fresh.requests.is_empty(), "Fresh installation never infers authentication from world metadata")
	check(store.save_session(PROJECT, "old-refresh"), "Account refresh credential persists")
	check(store.read_session(PROJECT) == "old-refresh", "Session file roundtrips")
	if OS.get_name() in ["macOS", "Linux"]:
		check(FileAccess.get_unix_permissions(path) == (FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER), "Desktop credential file is readable and writable only by owner")
	var returning := service()
	returning.responses = [response(), {"ok": true, "code": 200, "data": []}]
	returning.enabled = true
	var original: Dictionary = returning.game.data.duplicate(true)
	root.add_child(returning)
	await process_frame
	await process_frame
	check(returning.signed_in() and returning.player_id == PLAYER and returning.email == "fixture@example.invalid" and returning.display_name == "Returning player", "Startup restores verified account identity and profile")
	check(returning.requests.size() == 2 and returning.requests[0].path.contains("refresh_token") and returning.requests[1].path.ends_with("list_saves"), "Startup refreshes credentials and only lists backups")
	check(store.read_session(PROJECT) == "rotated-token", "Rotated refresh token replaces saved credential")
	check(returning.game.data == original, "Restoration does not change or upload gameplay")
	var saved := JSON.parse_string(JSON.parse_string(FileAccess.get_file_as_string(path)).payload) as Dictionary
	check(saved.size() == 3 and saved.has("refresh_token") and not saved.has("access_token") and not saved.has("player_id"), "Persistence contains only version, service and refresh credential")
	var encoded := preload("res://scripts/persistence/stat_configuration.gd").encode({}, "Fixture", "")
	check(not encoded.contains("refresh_token") and not JSON.stringify(returning.codec.encode(returning.game.snapshot(1000), Service.Codec.uuid(), false)).contains("refresh_token"), "Configuration and world exports exclude session credentials")
	var progress := Progress.new()
	progress.path = path + ".campaign"
	progress.restore_completed_levels(10)
	var account_file := FileAccess.get_file_as_string(path)
	check(progress.reset_progress() and FileAccess.get_file_as_string(path) == account_file, "Campaign reset cannot touch account session")
	returning.expires_at = 0.0
	returning.hold_refresh = true
	returning.responses = [response("concurrent-rotated")]
	var results: Array = []
	var previous_requests: int = returning.requests.size()
	complete(returning, results)
	complete(returning, results)
	check(returning.requests.size() == previous_requests + 1 and results.is_empty(), "Concurrent requests share one token refresh")
	returning.hold_refresh = false
	returning.release_refresh.emit()
	await process_frame
	check(results.size() == 2 and results.all(func(r): return r.ok) and store.read_session(PROJECT) == "concurrent-rotated", "Concurrent callers resume with the same rotated session")
	for code in [0, 429, 503]:
		var offline := service()
		root.add_child(offline)
		offline.responses = [{"ok": false, "code": code, "data": null}]
		await offline.restore_session()
		check(not offline.signed_in() and offline.has_saved_session() and store.read_session(PROJECT) == "concurrent-rotated", "Transient restoration failure preserves credential without claiming verified identity")
		offline.responses = [response("concurrent-rotated"), {"ok": true, "code": 200, "data": []}]
		await offline.restore_session()
		check(offline.signed_in(), "Explicit restoration retry succeeds")
		offline.queue_free()
	var revoked := service()
	root.add_child(revoked)
	revoked.responses = [{"ok": false, "code": 400, "data": {"error_code": "refresh_token_not_found"}}]
	await revoked.restore_session()
	check(not revoked.signed_in() and not revoked.busy and not FileAccess.file_exists(path), "Revoked credential is removed and sign-in controls become available")
	store.save_session(PROJECT, "logout-test")
	var racing := service()
	root.add_child(racing)
	racing.hold_refresh = true
	racing.responses = [response("must-not-return")]
	racing.restore_session()
	check(racing.busy, "Restore is in flight")
	racing.sign_out()
	racing.hold_refresh = false
	racing.release_refresh.emit()
	await process_frame
	check(not racing.signed_in() and racing.refresh_token.is_empty() and not FileAccess.file_exists(path) and not racing.busy, "Sign-out prevents delayed refresh from resurrecting credentials")
	store.save_session(PROJECT, "foreign-token")
	var foreign := service()
	root.add_child(foreign)
	foreign.url = "https://different.supabase.co"
	await foreign.restore_session()
	check(foreign.requests.is_empty() and not foreign.signed_in(), "Foreign project credential never leaves device")
	for malformed in ["broken", "{}", JSON.stringify({"payload": "{}", "checksum": "wrong"}), "x".repeat(Store.MAX_BYTES + 1)]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(malformed)
		file.close()
		check(store.read_session(PROJECT).is_empty() and not store.last_error.is_empty(), "Malformed stored session fails safely")
	var bad := response().data as Dictionary
	for value in ["", "has space", 12, null]:
		bad.refresh_token = value
		check(not fresh._accept_session(bad), "Invalid server credentials are rejected")
	bad = response().data
	bad.expires_in = "tomorrow"
	check(not fresh._accept_session(bad), "Malformed token lifetime is rejected")
	var unwritable := service()
	root.add_child(unwritable)
	unwritable.session_store.path = path + "/no-parent/session"
	check(unwritable._accept_session(response().data), "Valid authentication remains usable when device persistence fails")
	unwritable._say("Signed in.")
	check(not unwritable.session_notice.is_empty() and unwritable.status.contains("couldn't remember"), "Session persistence failure is visible")
	unwritable.queue_free()
	returning.sign_out()
	var restarted := service()
	root.add_child(restarted)
	await restarted.restore_session()
	check(not restarted.signed_in() and restarted.requests.is_empty(), "Signed-out session stays signed out after restart")
	for s in [fresh, returning, revoked, racing, foreign, restarted]: s.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at("user://"):
		if filename.begins_with(path.get_file()): DirAccess.remove_absolute("user://" + filename)
	print("ACCOUNT SESSION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
