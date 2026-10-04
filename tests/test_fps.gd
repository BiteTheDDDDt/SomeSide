extends SceneTree

const Locale = preload("res://scripts/localization.gd")
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
	_check(game.profile.get("show_fps", false), "Fresh profiles enable the FPS readout by default")
	game.set("_smoke", "fps-test")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game.sound.shutdown()
	game.call("_notification", NOTIFICATION_APPLICATION_FOCUS_IN)
	game.profile.show_fps = true
	game.call("_refresh_fps_view")
	await _layout()
	var label: Label = game.get("_fps_label")
	_check(is_instance_valid(label) and label.visible, "The title menu displays the enabled FPS readout")
	_check(label.get_theme_font_size("font_size") == 12 and label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "FPS uses compact 12 px text and never intercepts clicks")
	_check_bounds()
	_test_sampling()
	await _test_shortcut_and_settings()
	await _test_gameplay_and_language()
	if DisplayServer.get_name() != "headless":
		await _capture_native()
	var after_exists: bool = FileAccess.file_exists("user://profile.cfg")
	var after: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if after_exists else PackedByteArray()
	_check(after_exists == profile_existed and after == profile_before, "FPS preferences and shortcut tests leave the user's real profile unchanged")
	game.sound.shutdown()
	game.queue_free()
	await process_frame
	print("FPS_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _layout() -> void:
	await process_frame
	await process_frame
	await process_frame

func _key(code: int, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _f3() -> void:
	_key(KEY_F3, true)
	_key(KEY_F3, false)

func _test_sampling() -> void:
	var label: Label = game.get("_fps_label")
	game.set("_fps_refresh_clock", 0.0)
	label.text = "sampling marker"
	game.call("_update_fps", 0.24)
	_check(label.text == "sampling marker", "FPS does not rebuild its text on every render frame")
	var expected: int = maxi(0, roundi(Engine.get_frames_per_second()))
	game.call("_update_fps", 0.02)
	_check(int(game.get("_fps_value")) == expected and label.text == ("%d FPS" % expected if expected > 0 else "— FPS"), "After 0.25 seconds FPS comes from the real render engine counter")
	_check(float(game.get("_fps_refresh_clock")) < 0.25, "Sampling retains only the fractional refresh interval")
	game.call("_update_fps", 5.0)
	_check(float(game.get("_fps_refresh_clock")) < 0.25, "A stalled frame produces one current sample without a refresh backlog")

func _test_shortcut_and_settings() -> void:
	var original_label: Label = game.get("_fps_label")
	_f3()
	_check(not bool(game.profile.show_fps) and not original_label.visible, "F3 immediately hides the readout and updates its saved preference")
	_key(KEY_F3, true, true)
	_key(KEY_F3, false)
	_check(not bool(game.profile.show_fps), "F3 autorepeat cannot repeatedly toggle the preference")
	game.call("_show_settings")
	await _layout()
	_check(game.get("_fps_label") == original_label and not original_label.visible, "Changing menu pages retains one readout and its hidden preference")
	var button: Button = game.get("_fps_settings_button")
	_check(is_instance_valid(button) and button.text.contains("F3"), "Settings exposes a labelled FPS toggle with its keyboard shortcut")
	button.emit_signal("pressed")
	_check(bool(game.profile.show_fps) and original_label.visible, "The settings toggle enables FPS without leaving settings")
	_check(button.text == game.call("_fps_setting_text"), "Settings immediately reflects its current on/off value")
	var fields: Array = game.ui.find_children("*", "LineEdit", true, false)
	if not fields.is_empty():
		fields[0].grab_focus()
	_f3()
	_check(not bool(game.profile.show_fps) and not original_label.visible, "F3 also works while the name text field owns GUI focus")
	_check(button.text == game.call("_fps_setting_text"), "Using F3 refreshes the settings button without rebuilding the page")
	_f3()
	for language: String in ["en", "zh"]:
		game.call("_set_language", language)
		await _layout()
		_check(bool(game.profile.show_fps) and game.get("_fps_label") == original_label, "Switching to %s preserves FPS preference and overlay identity" % language)
		_check_settings_bounds()
		var translated: String = game.get("_fps_settings_button").text
		_check(translated.contains("Show FPS") if language == "en" else translated.contains("显示帧率"), "The FPS settings control is translated for " + language)
	game.call("_show_guide")
	await _layout()
	_check(_all_text(game.ui).contains("F3"), "The operation guide documents the FPS shortcut")
	_check_settings_bounds()
	# The existing command-line override must suppress writes even outside smoke.
	game.get("_options")["language"] = "en"
	game.set("_smoke", "")
	_f3()
	_check(not bool(game.profile.show_fps), "The keyboard toggle also works on the ordinary human-input path")
	game.call("_show_menu")
	_check(not game.get("_fps_label").visible, "Returning to the main menu retains the hidden preference")

func _test_gameplay_and_language() -> void:
	game.call("_start_solo")
	game.call("_notification", NOTIFICATION_APPLICATION_FOCUS_IN)
	await _layout()
	_check(not game.get("_fps_label").visible, "Starting an expedition preserves the FPS preference")
	var snapshot: PackedByteArray = var_to_bytes(game.sim.state)
	_key(KEY_A, true)
	_key(KEY_D, true)
	_f3()
	_check(game.get("_fps_label").visible and game.call("_get_command").move == 1.0, "F3 shows FPS during play without clearing held movement priority")
	_check(var_to_bytes(game.sim.state) == snapshot, "Toggling FPS does not mutate gameplay or network state")
	_key(KEY_D, false)
	_key(KEY_A, false)
	game._coin_panel.reset_size()
	await _layout()
	_check_bounds()
	_check(not game.get("_fps_label").get_global_rect().intersects(game.get("_coin_panel").get_global_rect()), "The FPS readout stays below the complete coin panel without overlap")
	game.sim.state.players[1].coins = 9999999999
	game.call("_update_hud")
	await _layout()
	_check(not game.get("_fps_label").get_global_rect().intersects(game.get("_coin_panel").get_global_rect()), "Even a ten-digit balance remains separate from the FPS readout")
	var label: Label = game.get("_fps_label")
	label.text = "physics marker"
	game.call("_physics_process", 1.0 / 60.0)
	_check(label.text == "physics marker", "A physics tick does not impersonate a render-FPS sample")
	game.call("_show_pause")
	await _layout()
	_check(label.visible and _all_text(game.overlay).contains("F3"), "Pause keeps the readout visible and documents F3")
	_f3()
	game.call("_show_settings", true)
	await _layout()
	_check(not label.visible and bool(game.paused), "Opening in-run settings preserves the hidden FPS preference and pause state")
	game.call("_set_language", "en")
	await _layout()
	_check(not label.visible and not bool(game.profile.show_fps), "An in-run language switch preserves the disabled FPS preference")
	game.get("_fps_settings_button").emit_signal("pressed")
	_check(label.visible and bool(game.profile.show_fps) and bool(game.paused), "The in-run settings toggle changes FPS without resuming the simulation")
	game.call("_resume")
	await _layout()
	_check(label.visible and not bool(game.paused), "Resuming play retains the selected FPS state")
	var readouts: int = 0
	for child in game.ui.get_children():
		if child.name == "FpsReadout": readouts += 1
	_check(readouts == 1, "Menu, pause, language and HUD rebuilds never duplicate the FPS overlay")
	game.call("_update_fps", 0.0, true)

func _check_bounds() -> void:
	var label: Label = game.get("_fps_label")
	var rectangle: Rect2 = label.get_global_rect()
	_check(Rect2(0, 0, 1280, 720).encloses(rectangle) and rectangle.size.x <= 110 and rectangle.size.y <= 24, "FPS remains inside a compact 110 by 24 pixel region of the 1280x720 view")
	_check(rectangle.position.y >= 100 and rectangle.end.x <= 1262.1, "FPS leaves a right-edge margin and sits below stage and gold information")

func _check_settings_bounds() -> void:
	var okay: bool = true
	for node in game.ui.find_children("*", "Button", true, false):
		var button: Button = node
		if button.is_visible_in_tree():
			okay = okay and Rect2(0, 0, 1280, 672).encloses(button.get_global_rect())
	_check(okay, "Settings and guide buttons keep their viewport and footer clearance")

func _all_text(node: Node) -> String:
	var value: String = str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): value += _all_text(child)
	return value

func _capture_native() -> void:
	# Let the engine's one-second frame counter settle before the real screenshot.
	for index: int in range(150):
		await process_frame
		game.call("_update_fps", 1.0 / 120.0)
	game.call("_process", 1.0 / 120.0)
	game.call("_update_fps", 0.0, true)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/results/v010-fps-play.png")
	var label: Label = game.get("_fps_label")
	_check(label.text.ends_with("FPS") and int(game.get("_fps_value")) > 0, "The native screenshot displays a real positive rendered FPS measurement")
	print("FPS_NATIVE_RECT ", label.get_global_rect(), " TEXT=", label.text)
	game.call("_show_settings", true)
	await _layout()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/results/v010-fps-settings-en.png")
	game.call("_set_language", "zh")
	await _layout()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/results/v010-fps-settings-zh.png")
