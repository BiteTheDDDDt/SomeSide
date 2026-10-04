extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_test_height_control()
	_test_release_and_landing()
	_test_feather()
	_test_drop_and_coyote()
	_test_external_motion()
	_test_reset_and_snapshot()
	_test_prediction()
	_test_held_jump_routes()
	print("MOVEMENT_TEST_RESULT passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _fresh(character: String = "ranger", count: int = 1) -> RefCounted:
	var sim = Simulation.new()
	var roster: Array = []
	for index in range(count):
		roster.append({"id": index + 1, "name": "Movement %d" % index, "character": character})
	sim.start_run(roster, 20261004)
	sim.state.world_size = Vector2(1800.0, 1100.0)
	sim.state.floor_y = 1000.0
	sim.state.platforms = [Rect2(0.0, 1000.0, 1800.0, 60.0)]
	sim.state.chests = []
	sim._spawn_clock = 9999.0
	for player: Dictionary in sim.state.players.values():
		player.pos = Vector2(600.0 + int(player.id) * 50.0, 979.0)
		player.vel = Vector2.ZERO
		player.grounded = true
		player.explore_anchor = player.pos
		player.explore_sites = [player.pos]
	return sim

func _arc(hold_ticks: int, dt: float = DT, character: String = "ranger", legacy: bool = false, repress: bool = false) -> Dictionary:
	var sim = _fresh(character)
	var player: Dictionary = sim.state.players[1]
	var start_y: float = Vector2(player.pos).y
	var peak: float = start_y
	var trace: Array = []
	for tick in range(ceili(1.6 / dt)):
		var command: Dictionary = {"jump": tick == 0}
		if not legacy:
			command["jump_held"] = tick < hold_ticks or (repress and tick > hold_ticks + 2)
			if repress and tick == hold_ticks + 3:
				command["jump"] = true
		sim.step(dt, {1: command})
		peak = minf(peak, Vector2(player.pos).y)
		trace.append([player.pos, player.vel])
	return {"height": start_y - peak, "trace": trace, "player": player}

func _test_height_control() -> void:
	for character in ["ranger", "vanguard"]:
		for dt: float in [1.0 / 30.0, DT, 1.0 / 120.0]:
			var short: Dictionary = _arc(1, dt, character)
			var medium: Dictionary = _arc(roundi(0.15 / dt), dt, character)
			var full: Dictionary = _arc(1000, dt, character)
			var legacy: Dictionary = _arc(0, dt, character, true)
			_check(float(short.height) + 20.0 < float(medium.height) and float(medium.height) + 15.0 < float(full.height), "%s %.0fHz: short / medium / held jump heights are clearly ordered (%.2f / %.2f / %.2f px)" % [character, 1.0 / dt, short.height, medium.height, full.height])
			_check(full.trace == legacy.trace, "%s %.0fHz: holding jump exactly preserves the legacy full trajectory" % [character, 1.0 / dt])
			var velocity: float = -665.0
			var y: float = 0.0
			var expected: float = 0.0
			while velocity < 0.0:
				velocity += 1750.0 * dt
				y += velocity * dt
				expected = minf(expected, y)
			_check(absf(float(full.height) + expected) < 0.001, "%s %.0fHz: highest jump still follows the original 665 / 1750 physics" % [character, 1.0 / dt])

func _test_release_and_landing() -> void:
	var short: Dictionary = _arc(1)
	var repressed: Dictionary = _arc(1, DT, "ranger", false, true)
	_check(short.trace == repressed.trace, "Releasing then pressing again without feather cannot restore lift or extend a jump")
	var full: Dictionary = _arc(1000)
	_check(bool(full.player.grounded) and Vector2(full.player.vel).is_zero_approx() and int(full.player.jumps) == 0, "Keeping the key held after landing does not automatically jump again")
	_check(not bool(full.player.jump_rising), "Landing clears variable-height ownership")
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	sim.step(DT, {1: {"jump": true, "jump_held": false}})
	_check(Vector2(player.vel).y < 0.0 and Vector2(player.vel).y > -Simulation.JUMP_RELEASE_SPEED, "A press-and-release received in one tick still creates a small intentional hop")
	for tick in range(90):
		sim.step(DT, {1: {"jump_held": true}})
	sim.step(DT, {1: {"jump": true, "jump_held": true}})
	_check(Vector2(player.vel).y < -600.0 and bool(player.jump_rising), "A new edge after landing starts a fresh full-strength jump")

func _feather_arc(hold_ticks: int) -> Dictionary:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.items.feather = 1
	player.pos = Vector2(650.0, 760.0)
	player.vel = Vector2(0.0, 150.0)
	player.grounded = false
	player.jumps = 1
	var peak: float = 760.0
	for tick in range(45):
		sim.step(DT, {1: {"jump": tick == 0, "jump_held": tick < hold_ticks}})
		peak = minf(peak, Vector2(player.pos).y)
		if tick == 0:
			_check(int(player.jumps) == 2 and bool(player.jump_rising), "A feather air jump grants fresh variable-height control and consumes one jump")
	return {"height": 760.0 - peak, "player": player}

func _test_feather() -> void:
	var short: Dictionary = _feather_arc(1)
	var full: Dictionary = _feather_arc(1000)
	_check(float(short.height) + 55.0 < float(full.height), "A feather air jump supports both a short tap and a full held arc")
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.items.feather = 2
	for jump_index in range(3):
		sim.step(DT, {1: {"jump": true, "jump_held": true}})
		_check(int(player.jumps) == jump_index + 1 and bool(player.jump_rising), "Jump %d starts its own ascent control with two feather stacks" % (jump_index + 1))
		sim.step(DT, {1: {"jump_held": false}})
		_check(not bool(player.jump_rising) and Vector2(player.vel).y > -Simulation.JUMP_RELEASE_SPEED, "Releasing jump %d cuts only its current ascent" % (jump_index + 1))
	var before: float = Vector2(player.vel).y
	sim.step(DT, {1: {"jump": true, "jump_held": true}})
	_check(int(player.jumps) == 3 and Vector2(player.vel).y > before, "A fourth press cannot exceed the two-feather jump allowance")

func _test_drop_and_coyote() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	sim.state.platforms.append(Rect2(400.0, 800.0, 500.0, 18.0))
	player.pos = Vector2(650.0, 779.0)
	player.items.feather = 2
	sim.step(DT, {1: {"jump": true, "jump_held": true, "drop": true}})
	_check(Vector2(player.vel).y > 0.0 and not bool(player.grounded) and int(player.jumps) == 0 and not bool(player.jump_rising), "Down+jump drops through the platform without starting or consuming a feather jump")
	for tick in range(90):
		sim.step(DT, {1: {"jump_held": true}})
	_check(bool(player.grounded) and absf(Vector2(player.pos).y - 979.0) < 0.001, "Holding jump during a drop lands on the floor without a rebound")
	sim.step(DT, {1: {"jump": true, "jump_held": true, "drop": true}})
	_check(bool(player.grounded) and int(player.jumps) == 0, "A drop request on the bottom floor never becomes an accidental jump")
	player.grounded = false
	player.coyote = 0.08
	player.pos.y -= 4.0
	sim.step(DT, {1: {"jump": true, "jump_held": true}})
	_check(Vector2(player.vel).y < -600.0 and bool(player.jump_rising), "A coyote-time jump starts the same full ascent control")
	sim.step(DT, {1: {"jump_held": false}})
	_check(Vector2(player.vel).y > -Simulation.JUMP_RELEASE_SPEED, "Releasing a coyote-time jump also produces a short arc")

func _test_external_motion() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	sim.step(DT, {1: {"jump": true, "jump_held": true}})
	sim.step(DT, {1: {"dash": true, "aim": Vector2.UP, "jump_held": false}})
	_check(Vector2(player.vel).y == -Simulation.DASH_SPEED and not bool(player.jump_rising), "Releasing during an upward dash cannot shorten its impulse")
	for tick in range(12):
		sim.step(DT, {1: {"jump_held": false}})
	_check(Vector2(player.vel).y < -400.0, "Jump release does not cut upward dash momentum after the dash timer expires")
	player.invuln = 0.0
	player.jump_rising = true
	sim._damage_player(player, 1.0, Vector2(player.pos) - Vector2.RIGHT * 20.0)
	_check(not bool(player.jump_rising), "Taking damage cancels jump ownership before knockback")
	var expected_y: float = Vector2(player.vel).y + Simulation.GRAVITY * DT
	sim.step(DT, {1: {"jump_held": false}})
	_check(absf(Vector2(player.vel).y - expected_y) < 0.001, "Knockback follows its own gravity arc regardless of jump release")
	player.equipment = "shockwave"
	player.jump_rising = true
	sim._use_skill(player)
	_check(not bool(player.jump_rising) and float(player.dash_timer) > 0.0, "Shockwave replaces jump ownership with its movement ability")

func _test_reset_and_snapshot() -> void:
	var sim = _fresh("ranger", 2)
	var player: Dictionary = sim.state.players[1]
	_check(player.has("jump_rising") and not bool(player.jump_rising), "A new player starts with no owned jump ascent")
	sim.step(DT, {1: {"jump": true, "jump_held": true}})
	var snapshot: Dictionary = bytes_to_var(var_to_bytes(sim.get_snapshot()))
	var replica = Simulation.new()
	replica.apply_snapshot(snapshot)
	_check(bool(replica.state.players[1].jump_rising), "Active jump state survives serialization and cooperative snapshots")
	snapshot.players[1].jump_rising = false
	_check(bool(player.jump_rising) and bool(replica.state.players[1].jump_rising), "Snapshot jump state does not alias either authority or replica")
	player.dead = true
	player.hp = 0.0
	player.revive_timer = DT
	sim.step(DT, {})
	_check(not bool(player.dead) and not bool(player.jump_rising), "Cooperative revival clears the previous life's ascent control")
	player.jump_rising = true
	sim._build_stage(2)
	_check(not bool(player.jump_rising) and Vector2(player.vel).is_zero_approx(), "Stage transition clears ascent control alongside velocity")

func _test_prediction() -> void:
	for character in ["ranger", "vanguard"]:
		var sim = _fresh(character)
		var player: Dictionary = sim.state.players[1]
		player.items.feather = 2
		var predicted: Dictionary = player.duplicate(true)
		var matches: bool = true
		for tick in range(150):
			var command: Dictionary = {"move": 0.3 if tick < 90 else -0.3, "jump": tick in [0, 14, 28, 115], "jump_held": tick < 2 or (tick >= 14 and tick < 20) or (tick >= 28 and tick < 60) or tick >= 115, "dash": tick == 70, "aim": Vector2(1.0, -0.5).normalized()}
			sim.predict_player(predicted, command, DT)
			sim.step(DT, {1: command})
			for key in ["pos", "vel", "grounded", "jumps", "jump_rising", "coyote", "dash_timer"]:
				matches = matches and predicted.get(key) == player.get(key)
		_check(matches, "%s predicted and authoritative variable jumps / feather / dash agree on every tick" % character)

func _test_held_jump_routes() -> void:
	# Use actual stage geometry and the new held command, not its legacy fallback.
	# Every accepted edge must tolerate +/-12px takeoff error, with at least
	# 32px left on the source and 24px inside the destination platform.
	for character in ["ranger", "vanguard"]:
		var sim = Simulation.new()
		sim.start_run([{"id": 1, "name": "Held route", "character": character}], 20261004)
		for stage in range(1, 4):
			sim._build_stage(stage)
			var platforms: Array = sim.state.platforms
			var reachable: Dictionary = {_support(platforms, sim.state.players[1].pos): true}
			var progress: bool = true
			while progress:
				progress = false
				for target_index in range(platforms.size()):
					if reachable.has(target_index):
						continue
					for source_index in reachable.keys():
						if _held_route(sim, platforms[int(source_index)], platforms[target_index]):
							reachable[target_index] = true
							progress = true
							break
			_check(reachable.size() == platforms.size(), "%s stage %d: explicit held single jumps reach all %d platforms with takeoff and landing margins" % [character, stage, platforms.size()])
			var supported: bool = true
			var destinations: Array = sim.state.chests.duplicate()
			destinations.append(sim.state.gate)
			for destination: Dictionary in destinations:
				supported = supported and reachable.has(_support(platforms, destination.pos))
			_check(supported, "%s stage %d: all facilities and the elevated gate remain reachable without feather or dash" % [character, stage])

func _support(platforms: Array, position: Vector2) -> int:
	var closest: float = INF
	var index: int = -1
	for current in range(platforms.size()):
		var platform: Rect2 = platforms[current]
		var separation: float = platform.position.y - position.y
		if position.x >= platform.position.x and position.x <= platform.end.x and separation >= -1.0 and separation <= 85.0 and separation < closest:
			closest = separation
			index = current
	return index

func _held_route(sim: RefCounted, source: Rect2, target: Rect2) -> bool:
	var rise: float = source.position.y - target.position.y
	if rise > 126.0 or source.size.x < 88.0:
		return false
	var gap: float = maxf(target.position.x - source.end.x, source.position.x - target.end.x)
	if gap > 450.0 and rise > -250.0:
		return false
	var desired_x: float = target.get_center().x
	var takeoffs: Array[float] = [clampf(desired_x, source.position.x + 44.0, source.end.x - 44.0), source.get_center().x, source.end.x - 44.0 if desired_x > source.get_center().x else source.position.x + 44.0]
	for takeoff: float in takeoffs:
		var successes: int = 0
		for deviation: float in [-12.0, 0.0, 12.0]:
			var player: Dictionary = sim.state.players[1].duplicate(true)
			player.pos = Vector2(takeoff + deviation, source.position.y - Simulation.PLAYER_HALF.y)
			for tick in range(110):
				var offset: float = desired_x - Vector2(player.pos).x
				sim.predict_player(player, {"move": signf(offset) if absf(offset) > 15.0 else 0.0, "jump": tick == 0, "jump_held": true}, DT)
				var position: Vector2 = player.pos
				if tick > 2 and bool(player.grounded) and absf(position.y + Simulation.PLAYER_HALF.y - target.position.y) < 0.1 and position.x >= target.position.x + 24.0 and position.x <= target.end.x - 24.0:
					successes += 1
					break
		if successes == 3:
			return true
	return false
