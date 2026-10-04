class_name SidePlayerInput
extends RefCounted

## Local physical-key state. Feed events from _input (including releases consumed
## by GUI controls), and reset on focus loss or when abandoning a play session.
## Movement follows the newest still-held direction, independently of the mouse.
const MOVEMENT_KEYS: Dictionary = {KEY_A: -1.0, KEY_LEFT: -1.0, KEY_D: 1.0, KEY_RIGHT: 1.0}
const JUMP_KEYS: Array[int] = [KEY_SPACE, KEY_W, KEY_UP]

var _pressed: Dictionary = {}
var _press_order: int = 0

func handle_event(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	# Native keyboard events supply a physical code. Logical fallback also permits
	# virtual/synthetic keyboard events that do not identify a physical position.
	var key: int = int(event.physical_keycode)
	if key == 0:
		key = int(event.keycode)
	if not MOVEMENT_KEYS.has(key) and key not in JUMP_KEYS:
		return
	if not event.pressed:
		_pressed.erase(key)
		return
	# Repeats and duplicate downs must never steal priority from a newer key.
	if event.echo or _pressed.has(key):
		return
	_press_order += 1
	_pressed[key] = _press_order

func reset() -> void:
	_pressed.clear()
	_press_order = 0

func movement_axis() -> float:
	var newest_order: int = -1
	var direction: float = 0.0
	for key: int in MOVEMENT_KEYS:
		var order: int = int(_pressed.get(key, -1))
		if order > newest_order:
			newest_order = order
			direction = float(MOVEMENT_KEYS[key])
	return direction

func jump_held() -> bool:
	for key: int in JUMP_KEYS:
		if _pressed.has(key):
			return true
	return false
