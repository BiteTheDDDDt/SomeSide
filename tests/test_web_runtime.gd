extends SceneTree

const Locale = preload("res://scripts/localization.gd")
var passed: int = 0
var failed: int = 0
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if value:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _nodes(parent: Node, type: String) -> Array:
	var result: Array = []
	for node: Node in parent.get_children():
		if node.is_class(type):
			result.append(node)
		result.append_array(_nodes(node, type))
	return result

func _text() -> String:
	var result: String = ""
	for type: String in ["Label", "Button"]:
		for node: Control in _nodes(game.ui, type):
			result += str(node.text) + "\n"
	return result

func _buttons() -> Array:
	return _nodes(game.ui, "Button").map(func(button: Button) -> String: return button.text)

func _layout() -> void:
	await process_frame
	await process_frame

func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _new_game(web: bool) -> void:
	game = load("res://main.tscn").instantiate()
	game._smoke = "web-ui"
	game._web_runtime = web
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game.profile.runs = 0

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var existed: bool = FileAccess.file_exists("user://profile.cfg")
	var original: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()
	_new_game(true)
	_check(game._is_web() and not bool(game.profile.fullscreen), "A Web runtime never restores saved fullscreen without a user gesture")
	_check(game.sound.wait_for_gesture and not game.sound._gesture_received and not game.sound._ambient.playing, "Browser ambience waits for the first input instead of autoplaying")
	var sample_audio: bool = not game.sound._streams.is_empty()
	for stream: Variant in game.sound._streams.values():
		sample_audio = sample_audio and stream is AudioStreamWAV and stream.data.size() > 0 and stream.mix_rate == 22050 and stream.format == AudioStreamWAV.FORMAT_16_BITS
	_check(sample_audio and game.sound._ambient.stream is AudioStreamWAV and game.sound._ambient.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Effects and ambience are complete PCM WAV samples compatible with Web Sample playback")
	for language: String in ["en", "zh"]:
		Locale.set_language(language)
		game.profile.language = language
		game._show_menu()
		await _layout()
		var buttons: Array = _buttons()
		var text: String = _text()
		_check(buttons.has(Locale.text("单人游戏")) and buttons.has(Locale.text("下载 Windows 版（含联机）")), "%s Web menu exposes single player and the Windows download" % language)
		_check(not buttons.has(Locale.text("创建合作房间")) and not buttons.has(Locale.text("加入房间")) and not buttons.has(Locale.text("退出")), "%s Web menu omits unsupported UDP rooms and application quit" % language)
		_check(text.contains(Locale.text(game.WEB_COOP_MESSAGE)) and text.contains(Locale.text("浏览器单人版  /  自由瞄准  /  遗物构筑")), "%s Web menu explains solo and Windows co-op in the selected language" % language)
		var fits: bool = true
		for button: Button in _nodes(game.ui, "Button"):
			fits = fits and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect())
		_check(fits, "%s Web menu controls fit the game viewport" % language)
	_check(game.WINDOWS_DOWNLOAD_URL == "https://bitetheddddt.itch.io/someside", "The Windows action targets the user's actual itch project page")
	for action: String in ["_host_lobby", "_show_join", "_join_lobby"]:
		if action == "_join_lobby":
			game.call(action, "127.0.0.1")
		else:
			game.call(action)
		await _layout()
		_check(game.screen == "menu" and not game.online and not game.multiplayer.multiplayer_peer is ENetMultiplayerPeer, "Direct %s calls cannot open a browser UDP peer" % action)
	game._quit_game()
	_check(not game._quitting and game.screen == "menu", "A Web quit request safely returns to the menu without shutting down the engine")
	Locale.set_language("en")
	game.profile.language = "en"
	game._show_settings()
	await _layout()
	_check(_buttons().has("Toggle Fullscreen") and not _text().contains("F11"), "Web settings provides a direct fullscreen control without advertising a browser-reserved shortcut")
	game.profile.fullscreen = false
	var button: Button = game._fullscreen_button
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = button.get_global_rect().get_center()
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	_check(game.profile.fullscreen and game.sound._gesture_received, "A real pressed input handles fullscreen exactly once and unlocks browser sound")
	mouse = mouse.duplicate()
	mouse.pressed = false
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	_check(game.profile.fullscreen, "Releasing the fullscreen click cannot toggle a second time")
	button.grab_focus()
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	_check(not game.profile.fullscreen, "The focused Web fullscreen control also works from a keyboard gesture")
	game._profile_save_error = ERR_CANT_CREATE
	game._show_settings()
	await _layout()
	_check(_text().contains(Locale.text("此浏览器无法保存设置；关闭页面后更改可能丢失。")), "A known storage failure replaces the automatic-save promise with a clear localized message")
	game._profile_save_error = OK
	game._show_guide()
	await _layout()
	_check(not _text().contains("F11") and _text().contains("Build / map / menu / FPS"), "The Web guide matches its available browser controls")
	game._start_solo()
	await _layout()
	_check(game.screen == "playing" and not game.online and game.sim.state.players.size() == 1, "Web single player starts the full solo simulation")
	_key(KEY_A, true)
	Input.action_press("fire")
	Input.action_press("jump")
	_check(game._player_input.movement_axis() == -1.0, "Actual Web gameplay input reaches the local direction tracker")
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(game.paused and is_instance_valid(game.overlay), "Losing browser focus pauses a solo game before it continues in the background")
	_check(game._player_input.movement_axis() == 0.0 and not Input.is_action_pressed("fire") and not Input.is_action_pressed("jump"), "Focus loss clears movement, firing and jumping to prevent stuck controls")
	var paused_time: float = game.sim.state.time
	game._physics_process(1.0 / 60.0)
	_check(game.sim.state.time == paused_time, "An unfocused paused browser run does not advance the simulation")
	game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(game.paused, "Returning to the browser leaves the run paused until the player resumes")
	game._resume()
	_check(not game.paused and game._player_input.movement_axis() == 0.0, "Resuming after browser focus loss starts with clean inputs")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	_new_game(false)
	Locale.set_language("en")
	game._show_menu()
	await _layout()
	var desktop_buttons: Array = _buttons()
	_check(desktop_buttons.has("Host Co-op") and desktop_buttons.has("Join Room") and desktop_buttons.has("Quit"), "Desktop menus retain their original co-op and quit actions")
	_check(not game.sound.wait_for_gesture, "Desktop audio retains its normal startup behavior")
	game._start_solo()
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not game.paused, "The browser focus-pause rule does not change desktop behavior")
	var after: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if FileAccess.file_exists("user://profile.cfg") else PackedByteArray()
	_check(FileAccess.file_exists("user://profile.cfg") == existed and after == original, "Web and desktop fixture checks leave the user's profile byte-for-byte unchanged")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("WEB_RUNTIME_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)
