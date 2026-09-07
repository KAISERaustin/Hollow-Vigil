extends "res://tests/test_runner.gd"
const Service = preload("res://scripts/cloud/cloud_service.gd")
class LocalService extends Service:
	func configured() -> bool:
		return url.begins_with("http://127.0.0.1:") and key == "sb_publishable_fixture"

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Run using tools/test_account_session_http.py")
		quit(1)
		return
	var s := LocalService.new()
	s.game = VigilState.new(7)
	s.url = args[0]
	s.key = "sb_publishable_fixture"
	s.session_store.path = args[1]
	s.enabled = args[2] != "sign-in"
	root.add_child(s)
	if args[2] == "sign-in":
		var result: Dictionary = await s._request("/auth/v1/verify", {"token": "fixture-code"}, false)
		check(result.ok and s._accept_session(result.data), "HTTP sign-in persists credential")
	else:
		await process_frame
		while s.busy:
			await create_timer(0.02).timeout
		if args[2] == "restore":
			check(s.signed_in() and s.display_name == "HTTP returning player" and s.refresh_token == "fixture-rotated", "New process restores account using actual HTTP transport")
			check(s.session_store.read_session(s.url) == "fixture-rotated", "HTTP rotated token is durable")
			s.sign_out()
		else:
			check(not s.signed_in() and not FileAccess.file_exists(s.session_store.path), "Third process remains signed out")
	s.queue_free()
	await process_frame
	print("ACCOUNT HTTP %s: %d checks, %d failures" % [args[2], checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
