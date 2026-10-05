extends SceneTree

const DT: float = 1.0 / 60.0

var game: Node
var passed: int = 0
var failed: int = 0
var profile_before: PackedByteArray
var profile_existed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	profile_existed = FileAccess.file_exists("user://profile.cfg")
	profile_before = FileAccess.get_file_as_bytes("user://profile.cfg") if profile_existed else PackedByteArray()
	game = load("res://main.tscn").instantiate()
	game.set("_smoke", "controls")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.get("world").set_process(false)
	game.get("sound").call("shutdown")
	# Keep the real human-command path while suppressing every profile write.
	game.get("_options")["language"] = "en"
	game.set("_smoke", "")
	game.call("_start_solo")
	await process_frame
	game.call("_notification", NOTIFICATION_APPLICATION_FOCUS_IN)
	_release_all()
	await process_frame
	await _test_direction_commands()
	await _test_mouse_independence()
	await _test_jump_commands()
	await _test_alternating_jump_physics()
	await _test_pause_and_focus()
	_test_network_hold()
	_release_all()
	var after_exists: bool = FileAccess.file_exists("user://profile.cfg")
	var after: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if after_exists else PackedByteArray()
	_check(after_exists == profile_existed and after == profile_before, "Real-control regression leaves the user's profile byte-for-byte unchanged")
	game.get("sound").call("shutdown")
	game.queue_free()
	await process_frame
	print("CONTROLS_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _key(code: int, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(830, 330)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _command() -> Dictionary:
	return game.call("_get_command")

func _release_all() -> void:
	for code: int in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_W, KEY_UP, KEY_S, KEY_Q]:
		_key(code, false)
	_mouse(MOUSE_BUTTON_LEFT, false)
	_mouse(MOUSE_BUTTON_RIGHT, false)

func _test_direction_commands() -> void:
	_key(KEY_A, true)
	_check(_command().move == -1.0, "A reaches the actual human command as left movement")
	_key(KEY_D, true)
	_check(_command().move == 1.0, "A then D reaches the actual command as right movement")
	var player: Dictionary = game.sim.state.players[1]
	player.vel = Vector2.ZERO
	game.call("_physics_process", DT)
	_check(float(player.vel.x) > 0.0, "The authoritative solo physics tick actually moves right while A remains held")
	_key(KEY_A, true, true)
	_check(_command().move == 1.0, "An A autorepeat does not change the command back to left")
	_key(KEY_D, false)
	_check(_command().move == -1.0, "Releasing D restores A in the production command path")
	_key(KEY_RIGHT, true)
	_check(_command().move == 1.0, "Right arrow overrides a held A through the real main node")
	_key(KEY_D, true)
	_key(KEY_RIGHT, false)
	_check(_command().move == 1.0, "Releasing Right arrow preserves a separately held D")
	_key(KEY_LEFT, true)
	_check(_command().move == -1.0, "The most recent Left arrow overrides both held letter keys")
	_key(KEY_LEFT, false)
	_check(_command().move == 1.0, "Releasing the latest alias restores the newest remaining direction")
	_release_all()
	_check(_command().move == 0.0, "Releasing all physical movement keys returns a neutral command")
	await process_frame

func _test_mouse_independence() -> void:
	_key(KEY_A, true)
	_key(KEY_D, true)
	_mouse(MOUSE_BUTTON_LEFT, true)
	_mouse(MOUSE_BUTTON_RIGHT, true)
	var command: Dictionary = _command()
	_check(command.move == 1.0 and bool(command.fire) and bool(command.skill), "Both mouse buttons can shoot and use equipment while the latest D controls movement")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(20, 650)
	motion.relative = Vector2(-810, 320)
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	_check(_command().move == 1.0 and bool(_command().fire), "Mouse aim movement leaves keyboard priority and held fire intact")
	await process_frame
	command = _command()
	_check(command.move == 1.0 and bool(command.fire) and not bool(command.skill), "Primary fire remains held while the secondary activation is a one-frame edge")
	_key(KEY_D, false)
	_check(_command().move == -1.0 and bool(_command().fire), "Releasing the latest movement key restores A without stopping primary fire")
	_mouse(MOUSE_BUTTON_LEFT, false)
	_mouse(MOUSE_BUTTON_RIGHT, false)
	_check(_command().move == -1.0 and not bool(_command().fire), "Releasing the mouse stops fire without cancelling movement")
	_release_all()
	await process_frame

func _test_jump_commands() -> void:
	_key(KEY_SPACE, true)
	var command: Dictionary = _command()
	_check(bool(command.jump) and bool(command.get("jump_held", false)), "A fresh Space press produces both the jump edge and held state")
	await process_frame
	command = _command()
	_check(not bool(command.jump) and bool(command.get("jump_held", false)), "Keeping Space down preserves hold without issuing another jump edge")
	_key(KEY_W, true)
	command = _command()
	_check(bool(command.jump) and bool(command.jump_held), "Pressing W while Space remains held sends its own jump edge")
	_check(not bool(_command().jump), "A pending physical jump is consumed by exactly one command")
	_key(KEY_SPACE, false)
	_check(bool(_command().get("jump_held", false)), "A separately held W keeps jump held after Space is released")
	await process_frame
	_key(KEY_W, false)
	_check(not bool(_command().get("jump_held", true)), "Releasing the final jump alias sends jump_held=false")
	_key(KEY_UP, true)
	_check(bool(_command().get("jump_held", false)), "Up arrow supplies the same held jump command")
	_key(KEY_A, true)
	_key(KEY_D, true)
	_check(_command().move == 1.0 and bool(_command().get("jump_held", false)), "Opposing movement keys do not cancel held jump")
	_release_all()
	await process_frame
	_key(KEY_S, true)
	_key(KEY_SPACE, true)
	command = _command()
	_check(bool(command.jump) and bool(command.drop), "The existing S plus Space platform-drop edge remains available")
	_release_all()
	await process_frame

func _test_alternating_jump_physics() -> void:
	var sim = game.sim
	var saved_state: Dictionary = sim.state.duplicate(true)
	sim.state.world_size = Vector2(1800, 1100)
	sim.state.floor_y = 1000.0
	sim.state.platforms = [Rect2(0, 1000, 1800, 60)]
	for aliases: Array in [[KEY_SPACE, KEY_W], [KEY_W, KEY_SPACE]]:
		for feathers: int in [0, 1]:
			_release_all()
			game.call("_reset_controls")
			var player: Dictionary = sim.state.players[1]
			player.pos = Vector2(650, 979)
			player.vel = Vector2.ZERO
			player.grounded = true
			player.coyote = 0.0
			player.jumps = 0
			player.items = {"feather": feathers}
			_key(int(aliases[0]), true)
			sim._move_player(player, _command(), DT)
			_check(int(player.jumps) == 1 and float(player.vel.y) < -600.0, "First physical alias starts the normal ground jump with %d feather(s)" % feathers)
			for tick: int in range(10):
				sim._move_player(player, _command(), DT)
			var before: float = float(player.vel.y)
			_key(int(aliases[1]), true)
			var command: Dictionary = _command()
			sim._move_player(player, command, DT)
			_check(bool(command.jump) and bool(command.jump_held), "The second alias creates a real production jump request without releasing the first")
			if feathers == 0:
				_check(int(player.jumps) == 1 and float(player.vel.y) > before, "Alternating keys cannot grant an unearned air jump or extend ascent")
			else:
				_check(int(player.jumps) == 2 and float(player.vel.y) < -570.0, "The second alias consumes the available feather jump immediately")
				_key(KEY_UP, true)
				before = float(player.vel.y)
				sim._move_player(player, _command(), DT)
				_check(int(player.jumps) == 2 and float(player.vel.y) > before, "A third alias cannot exceed the one-feather jump budget")
			_release_all()
			sim._move_player(player, _command(), DT)
			_check(float(player.vel.y) >= -260.01 and not bool(player.jump_rising), "Releasing all aliases still cuts the current jump to its short-hop ascent")
			_key(int(aliases[0]), true)
			# Consume the unavailable midair edge, then keep this alias held through landing.
			sim._move_player(player, _command(), DT)
			for tick: int in range(100):
				sim._move_player(player, _command(), DT)
			_check(bool(player.grounded) and int(player.jumps) == 0, "Keeping an alias held through landing never causes automatic bouncing")
			_key(int(aliases[1]), true)
			sim._move_player(player, _command(), DT)
			_check(not bool(player.grounded) and float(player.vel.y) < -600.0, "A different alias immediately jumps after landing while the first remains held")
	_release_all()
	game.call("_reset_controls")
	sim.state = saved_state
	await process_frame

func _test_pause_and_focus() -> void:
	_key(KEY_D, true)
	_key(KEY_SPACE, true)
	game.call("_show_pause")
	var command: Dictionary = _command()
	_check(command.move == 0.0 and not bool(command.get("jump_held", true)) and not bool(command.fire), "Pause immediately neutralizes held movement, jump, and fire")
	_key(KEY_D, false)
	_key(KEY_SPACE, false)
	game.call("_resume")
	command = _command()
	_check(command.move == 0.0 and not bool(command.get("jump_held", true)), "Keys released while paused cannot become stuck when gameplay resumes")
	await process_frame
	_key(KEY_A, true)
	_key(KEY_W, true)
	game.call("_notification", NOTIFICATION_APPLICATION_FOCUS_OUT)
	command = _command()
	_check(command.move == 0.0 and not bool(command.get("jump_held", true)), "Application focus loss immediately clears held movement and jump")
	_key(KEY_D, true)
	_mouse(MOUSE_BUTTON_LEFT, true)
	_check(_command().move == 0.0 and not bool(_command().fire), "Gameplay remains neutral even if input arrives while the app lacks focus")
	game.call("_notification", NOTIFICATION_APPLICATION_FOCUS_IN)
	_key(KEY_A, true, true)
	_check(_command().move == 0.0 and not bool(_command().get("jump_held", true)), "Focus return plus an old autorepeat cannot revive pre-focus keyboard holds")
	_release_all()
	await process_frame
	_key(KEY_D, true)
	_check(_command().move == 1.0, "A fresh movement press works after focus returns")
	_key(KEY_SPACE, true)
	game.call("_show_menu")
	game.call("_start_solo")
	command = _command()
	_check(command.move == 0.0 and not bool(command.get("jump_held", true)), "Returning to the menu and starting a new run clears the previous run's held keys")
	_release_all()
	await process_frame

func _test_network_hold() -> void:
	# A direct invocation has sender ID zero. Exercise the actual host batch
	# acceptance code without pretending to create a remote ENet connection.
	game.sim.add_player(0, "Control Fixture", "ranger")
	game.hosting = true
	game.call("_submit_inputs", [
		{"seq": 1, "move": -1.0, "jump": true, "jump_held": true},
		{"seq": 2, "move": 1.0, "jump": false, "jump_held": false}
	])
	var commands: Dictionary = game.get("_commands")
	_check(commands.has(0) and commands[0].move == 1.0, "A network input batch preserves the latest resolved movement axis")
	_check(bool(commands[0].jump) and not bool(commands[0].get("jump_held", true)), "The host preserves one pending jump edge but applies the latest released hold state")
	game.call("_submit_inputs", [{"seq": 1, "move": -1.0, "jump_held": true}])
	_check(commands[0].move == 1.0 and not bool(commands[0].get("jump_held", true)), "An out-of-order network packet cannot restore an obsolete direction or hold")
	game.call("_submit_inputs", [{"seq": 3, "move": 1.0, "jump_held": true}])
	var player: Dictionary = game.sim.state.players[0]
	player.pos = Vector2(2000, 300)
	player.vel = Vector2(0, -600)
	player.grounded = false
	player.jump_rising = true
	commands[0].jump = false
	game.get("_command_times")[0] = Time.get_ticks_msec() - 1000
	game.call("_physics_process", DT)
	_check(float(player.vel.y) >= -260.01 and not bool(player.get("jump_rising", true)), "Stale network input releases jump hold instead of sustaining a disconnected player's ascent")
	game.call("_submit_inputs", [{"seq": 4, "move": 0.0, "jump": false}])
	_check(bool(commands[0].get("jump_held", false)), "A legacy input record without jump_held retains the documented full-jump compatibility")
	game.hosting = false
	for field: String in ["_commands", "_command_times", "_received", "_ack"]:
		game.get(field).erase(0)
	game.sim.remove_player(0)
