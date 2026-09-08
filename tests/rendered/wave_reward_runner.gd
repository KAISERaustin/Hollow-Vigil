extends SceneTree
const Harness = preload("res://tests/rendered/visual_smoke.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://wave-reward-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_campaign()
	var campaign: Control = app.campaign
	campaign.set_process(false)
	for viewport in [Vector2i(360,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = viewport
		root.content_scale_size = viewport
		campaign.start_mission(0)
		await frame()
		campaign.begin_wave()
		var before: float = campaign.run.game.data.balance
		var reward: float = campaign.run.mission.wave_rules[0].reward
		campaign.run.next_spawn = campaign.run.schedule.size()
		campaign.run.tick(Balance.STEP)
		var transition: Control = campaign.reward_transition
		transition.set_process(false)
		transition.elapsed = 0.7
		transition._update_visuals()
		await frame()
		transition._update_visuals()
		await frame()
		check(transition.active and transition.visible, "Clear opens reward transition")
		check(campaign.status.text == "Wave 1 / 3", "Reward header retains the completed wave count")
		check(transition.reward_label.text == "+%s gold" % VigilInterface.exact_money(reward), "Displays actual paid wave bonus")
		check(is_equal_approx(campaign.run.game.data.balance, before + reward), "Wave pays exactly once")
		check(campaign.run.checkpoint().phase == "planning", "Animation preserves completed checkpoint")
		campaign.begin_wave()
		check(campaign.run.phase == "planning" and campaign.wave_button.disabled, "Next wave waits for presentation")
		check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(transition.card.get_global_rect()), "Reward fits phone")
		await Harness.capture(app, "wave-reward-" + str(viewport.x))
		transition._process(0.69)
		check(transition.active, "Reward remains visible just before 1.4 seconds")
		transition._process(0.02)
		check(not transition.active and not campaign.wave_button.disabled, "Transition automatically returns to planning")
		check(campaign.status.text == "Wave 2 / 3" and campaign.wave_button.text == "Start wave" and campaign.wave_button.accessibility_name == "Start wave 2", "Planning advances the count and offers the next wave")
		for touch in [false, true]:
			for point in [Vector2(2, 2), transition.card.get_global_rect().get_center(), campaign.wave_button.get_global_rect().get_center()]:
				transition.play("Wave 1 won!", reward)
				transition.set_process(false)
				var press: InputEvent
				if touch:
					press = InputEventScreenTouch.new()
				else:
					press = InputEventMouseButton.new()
					press.button_index = MOUSE_BUTTON_LEFT
				press.position = point
				press.pressed = true
				Input.parse_input_event(press)
				Input.flush_buffered_events()
				check(not transition.active and not transition.visible, "Press anywhere immediately dismisses reward, including entrance")
				check(campaign.run.phase == "planning" and not campaign.wave_button.disabled, "Dismissal enables next wave without starting it")
				press = press.duplicate()
				press.pressed = false
				Input.parse_input_event(press)
				Input.flush_buffered_events()
				check(campaign.run.phase == "planning", "Dismissal release cannot start the next wave")
		campaign.run.tick(0.1)
		check(is_equal_approx(campaign.run.game.data.balance, before + reward), "Presentation cannot pay twice")
		campaign.run.wave = campaign.run.mission.waves.size() - 1
		campaign.begin_wave()
		check(campaign.status.text == "Wave 3 / 3", "Final wave displays its bounded count")
		campaign.run.next_spawn = campaign.run.schedule.size()
		campaign.run.tick(Balance.STEP)
		check(transition.active and not campaign.dialog.visible, "Final wave celebrates before results")
		check(campaign.status.text == "Wave 3 / 3", "Final reward never exceeds the wave total")
		var final_tap := InputEventScreenTouch.new()
		final_tap.position = transition.card.get_global_rect().get_center()
		final_tap.pressed = true
		Input.parse_input_event(final_tap)
		Input.flush_buffered_events()
		check(campaign.dialog.visible and not transition.active, "Final result follows immediate tap dismissal")
		final_tap = final_tap.duplicate()
		final_tap.pressed = false
		Input.parse_input_event(final_tap)
		Input.flush_buffered_events()
		campaign.start_mission(0)
		check(not transition.active, "New mission cleans presentation state")
	app.queue_free()
	await process_frame
	print("WAVE REWARD: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
