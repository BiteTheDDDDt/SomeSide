extends SceneTree

const PlayerInput = preload("res://scripts/player_input.gd")

class InputProbe extends Node:
	var tracker = PlayerInput.new()
	var key_events: int = 0
	var mouse_events: int = 0

	func _input(event: InputEvent) -> void:
		tracker.handle_event(event)
		if event is InputEventKey:
			key_events += 1
		elif event is InputEventMouse:
			mouse_events += 1

var passed: int = 0
var failed: int = 0
var probe: InputProbe

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_direction_priority()
	_test_aliases()
	_test_repeat_and_reset()
	_test_jump_hold()
	_test_jump_edges()
	_test_physical_keys()
	await _test_real_event_dispatch()
	print("INPUT_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _key(key: int, pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.echo = echo
	return event

func _test_direction_priority() -> void:
	var tracker = PlayerInput.new()
	_check(tracker.movement_axis() == 0.0, "Movement starts neutral")
	tracker.handle_event(_key(KEY_A, true))
	_check(tracker.movement_axis() == -1.0, "A moves left")
	tracker.handle_event(_key(KEY_D, true))
	_check(tracker.movement_axis() == 1.0, "D immediately wins while A remains held")
	tracker.handle_event(_key(KEY_D, false))
	_check(tracker.movement_axis() == -1.0, "Releasing D restores the still-held A")
	tracker.handle_event(_key(KEY_A, false))
	_check(tracker.movement_axis() == 0.0, "Releasing both directions restores neutral")
	tracker.handle_event(_key(KEY_D, true))
	tracker.handle_event(_key(KEY_A, true))
	_check(tracker.movement_axis() == -1.0, "A also wins when it is pressed after D")
	tracker.handle_event(_key(KEY_D, false))
	_check(tracker.movement_axis() == -1.0, "Releasing the older opposite key keeps the newer key active")
	tracker.handle_event(_key(KEY_D, true))
	_check(tracker.movement_axis() == 1.0, "A released then re-pressed direction receives fresh priority")
	tracker.handle_event(_key(KEY_D, false))
	tracker.handle_event(_key(KEY_A, false))
	_check(tracker.movement_axis() == 0.0, "All releases leave no stale movement")

func _test_aliases() -> void:
	var tracker = PlayerInput.new()
	tracker.handle_event(_key(KEY_LEFT, true))
	tracker.handle_event(_key(KEY_RIGHT, true))
	_check(tracker.movement_axis() == 1.0, "Arrow keys use the same last-pressed priority")
	tracker.handle_event(_key(KEY_RIGHT, false))
	_check(tracker.movement_axis() == -1.0, "Arrow release restores the previous held direction")
	tracker.handle_event(_key(KEY_A, true))
	tracker.handle_event(_key(KEY_LEFT, false))
	_check(tracker.movement_axis() == -1.0, "Releasing Left does not release the independently held A")
	tracker.handle_event(_key(KEY_D, true))
	tracker.handle_event(_key(KEY_LEFT, true))
	_check(tracker.movement_axis() == -1.0, "A newer Left arrow can override a held D")
	tracker.handle_event(_key(KEY_LEFT, false))
	_check(tracker.movement_axis() == 1.0, "Releasing a newer alias falls back to the newest remaining physical key")
	tracker.handle_event(_key(KEY_RIGHT, true))
	tracker.handle_event(_key(KEY_D, false))
	_check(tracker.movement_axis() == 1.0, "Releasing D does not release the independently held Right")
	tracker.handle_event(_key(KEY_RIGHT, false))
	_check(tracker.movement_axis() == -1.0, "Releasing both right aliases restores the original held A")
	tracker.handle_event(_key(KEY_A, false))
	_check(tracker.movement_axis() == 0.0, "Four distinct direction keys all release cleanly")

func _test_repeat_and_reset() -> void:
	var tracker = PlayerInput.new()
	tracker.handle_event(_key(KEY_A, true))
	tracker.handle_event(_key(KEY_D, true))
	tracker.handle_event(_key(KEY_A, true, true))
	_check(tracker.movement_axis() == 1.0, "An old key's autorepeat cannot steal direction priority")
	tracker.handle_event(_key(KEY_A, true))
	_check(tracker.movement_axis() == 1.0, "A duplicate non-echo down also cannot steal direction priority")
	tracker.handle_event(_key(KEY_LEFT, true, true))
	_check(tracker.movement_axis() == 1.0, "An orphan echo does not create a new held key")
	tracker.handle_event(_key(KEY_SPACE, true))
	tracker.reset()
	_check(tracker.movement_axis() == 0.0 and not tracker.jump_held(), "Focus-loss reset clears movement and held jump together")
	tracker.handle_event(_key(KEY_A, true, true))
	tracker.handle_event(_key(KEY_SPACE, true, true))
	_check(tracker.movement_axis() == 0.0 and not tracker.jump_held(), "Post-reset repeats cannot resurrect keys held before focus loss")
	tracker.handle_event(_key(KEY_D, false))
	tracker.handle_event(_key(KEY_SPACE, false))
	tracker.reset()
	_check(tracker.movement_axis() == 0.0 and not tracker.jump_held(), "Late releases and repeated reset are harmless")
	tracker.handle_event(_key(KEY_D, true))
	_check(tracker.movement_axis() == 1.0, "A fresh press works immediately after reset")
	tracker.handle_event(_key(KEY_D, false, true))
	_check(tracker.movement_axis() == 0.0, "A release always clears its key even if a synthetic event retains echo")

func _test_jump_hold() -> void:
	var tracker = PlayerInput.new()
	_check(not tracker.jump_held(), "Jump hold starts false")
	for key: int in [KEY_SPACE, KEY_W, KEY_UP]:
		tracker.handle_event(_key(key, true))
		_check(tracker.jump_held(), "Jump binding %d independently starts a hold" % key)
		tracker.handle_event(_key(key, false))
		_check(not tracker.jump_held(), "Jump binding %d independently releases its hold" % key)
	tracker.handle_event(_key(KEY_SPACE, true))
	tracker.handle_event(_key(KEY_W, true))
	tracker.handle_event(_key(KEY_UP, true))
	tracker.handle_event(_key(KEY_SPACE, false))
	_check(tracker.jump_held(), "Releasing Space preserves held W and Up")
	tracker.handle_event(_key(KEY_W, false))
	_check(tracker.jump_held(), "Releasing W preserves held Up")
	tracker.handle_event(_key(KEY_A, true))
	tracker.handle_event(_key(KEY_D, true))
	_check(tracker.jump_held() and tracker.movement_axis() == 1.0, "Changing movement does not change held jump")
	tracker.handle_event(_key(KEY_UP, false))
	_check(not tracker.jump_held() and tracker.movement_axis() == 1.0, "Releasing the final jump alias does not change movement")
	tracker.handle_event(_key(KEY_Q, true))
	tracker.handle_event(_key(KEY_S, true))
	_check(not tracker.jump_held() and tracker.movement_axis() == 1.0, "Skill and drop keys do not masquerade as movement or jump")

func _test_jump_edges() -> void:
	var tracker = PlayerInput.new()
	for first: int in PlayerInput.JUMP_KEYS:
		for second: int in PlayerInput.JUMP_KEYS:
			if first == second:
				continue
			tracker.reset()
			tracker.handle_event(_key(first, true))
			var first_edge: bool = tracker.consume_jump_pressed()
			tracker.handle_event(_key(second, true))
			_check(first_edge and tracker.consume_jump_pressed() and tracker.jump_held(), "Jump aliases %d then %d each issue a fresh edge while the other remains held" % [first, second])
			_check(not tracker.consume_jump_pressed(), "An alias press is consumed once rather than repeated on later ticks")
	tracker.reset()
	tracker.handle_event(_key(KEY_SPACE, true))
	tracker.consume_jump_pressed()
	tracker.handle_event(_key(KEY_SPACE, true, true))
	tracker.handle_event(_key(KEY_SPACE, true))
	_check(not tracker.consume_jump_pressed(), "Autorepeat and duplicate physical downs never produce additional jumps")
	tracker.handle_event(_key(KEY_W, true))
	tracker.handle_event(_key(KEY_W, false))
	_check(tracker.consume_jump_pressed() and tracker.jump_held(), "A quick alias tap between ticks survives release while another key maintains hold")
	tracker.handle_event(_key(KEY_W, true))
	tracker.handle_event(_key(KEY_UP, true))
	_check(tracker.consume_jump_pressed() and not tracker.consume_jump_pressed(), "Several presses before one command coalesce without a delayed extra jump")
	tracker.handle_event(_key(KEY_W, false))
	tracker.handle_event(_key(KEY_W, true))
	tracker.reset()
	_check(not tracker.consume_jump_pressed() and not tracker.jump_held(), "Focus and session reset discard unconsumed presses as well as holds")
	tracker.handle_event(_key(KEY_SPACE, true))
	tracker.handle_event(_key(KEY_SPACE, false))
	_check(tracker.consume_jump_pressed() and not tracker.jump_held(), "A released quick tap delivers the jump edge with released variable-height control")

func _test_physical_keys() -> void:
	var tracker = PlayerInput.new()
	var translated: InputEventKey = _key(KEY_A, true)
	translated.keycode = KEY_Q
	tracker.handle_event(translated)
	_check(tracker.movement_axis() == -1.0, "The physical A position remains left on another keyboard layout")
	translated.pressed = false
	tracker.handle_event(translated)
	_check(tracker.movement_axis() == 0.0, "Physical-position release clears a key with a different logical symbol")
	var logical: InputEventKey = _key(KEY_D, true)
	logical.physical_keycode = 0
	tracker.handle_event(logical)
	_check(tracker.movement_axis() == 1.0, "Virtual keyboard events without physical codes use their logical key")
	logical.pressed = false
	tracker.handle_event(logical)
	_check(tracker.movement_axis() == 0.0, "A logical fallback key releases correctly")
	var unrelated := InputEventJoypadMotion.new()
	unrelated.axis_value = -1.0
	tracker.handle_event(unrelated)
	_check(tracker.movement_axis() == 0.0, "Unsupported input devices do not mutate keyboard tracking")

func _dispatch(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await process_frame

func _mouse(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(120, 120)
	return event

func _test_real_event_dispatch() -> void:
	probe = InputProbe.new()
	root.add_child(probe)
	await process_frame
	await _dispatch(_key(KEY_A, true))
	await _dispatch(_key(KEY_D, true))
	_check(probe.key_events == 2 and probe.tracker.movement_axis() == 1.0, "Real Input.parse_input_event dispatch reaches _input and selects the last pressed direction")
	await _dispatch(_mouse(MOUSE_BUTTON_LEFT, true))
	await _dispatch(_mouse(MOUSE_BUTTON_RIGHT, true))
	_check(probe.mouse_events == 2 and probe.tracker.movement_axis() == 1.0, "Both mouse buttons leave the held movement direction unchanged")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(900, 50)
	motion.relative = Vector2(780, -70)
	await _dispatch(motion)
	_check(probe.tracker.movement_axis() == 1.0, "Mouse aim motion cannot override keyboard direction")
	await _dispatch(_key(KEY_A, true, true))
	_check(probe.tracker.movement_axis() == 1.0, "The real event pipeline preserves echo rejection")
	await _dispatch(_key(KEY_D, false))
	_check(probe.tracker.movement_axis() == -1.0, "Real key release falls back to the held opposite key")
	await _dispatch(_key(KEY_SPACE, true))
	await _dispatch(_key(KEY_W, true))
	await _dispatch(_key(KEY_SPACE, false))
	_check(probe.tracker.jump_held(), "The real event pipeline keeps a second jump alias held")
	await _dispatch(_mouse(MOUSE_BUTTON_LEFT, false))
	await _dispatch(_mouse(MOUSE_BUTTON_RIGHT, false))
	_check(probe.tracker.movement_axis() == -1.0 and probe.tracker.jump_held(), "Mouse release cannot cancel movement or held jump")
	probe.tracker.reset()
	_check(probe.tracker.movement_axis() == 0.0 and not probe.tracker.jump_held(), "Focus reset clears state after real key events")
	# Release the injected engine state so this script leaves no held test input.
	for key: int in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_W, KEY_UP]:
		await _dispatch(_key(key, false))
	_check(probe.tracker.movement_axis() == 0.0 and not probe.tracker.jump_held(), "Real late release events stay neutral after reset")
	probe.queue_free()
	await process_frame
