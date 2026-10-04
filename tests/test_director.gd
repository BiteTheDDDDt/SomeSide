extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_test_local_rest()
	_test_exploration_and_expiry()
	_test_coop_spawn_target()
	_test_explicit_events()
	_test_elapsed_time_scaling()
	print("DIRECTOR_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _fresh(count: int = 1):
	var simulation = Simulation.new()
	var roster: Array = []
	for index in range(count):
		roster.append({"id": index + 1, "name": "Explorer", "character": "ranger"})
	simulation.start_run(roster, 20261004)
	for player in simulation.state.players.values():
		player.invuln = 9999.0
	return simulation

func _advance(simulation, ticks: int, commands: Dictionary = {}, clear_enemies: bool = true) -> Dictionary:
	# Count each newly created ID, then clear in ordinary director scenarios.
	# Thus an entity cap cannot hide unlimited respawning during a long rest.
	var observed: Dictionary = {}
	var positions: Array = []
	for tick in range(ticks):
		simulation.step(DT, commands)
		for enemy in simulation.state.enemies:
			if not observed.has(enemy.id):
				observed[enemy.id] = true
				positions.append(enemy.pos)
		if clear_enemies:
			simulation.state.enemies.clear()
			simulation.state.projectiles.clear()
	return {"count": observed.size(), "positions": positions}

func _test_local_rest() -> void:
	for pattern in ["stationary", "small patrol", "repeated jumping"]:
		var simulation = _fresh()
		var total_spawns: int = 0
		for tick in range(3600):
			var command: Dictionary = {}
			if pattern == "small patrol":
				command.move = 1.0 if tick % 48 < 24 else -1.0
			elif pattern == "repeated jumping":
				command.jump = tick % 55 == 0
			var result: Dictionary = _advance(simulation, 1, {1: command})
			total_spawns += int(result.count)
		_check(total_spawns == 0, "%s for 60 seconds creates no ambient enemies even when enemies are cleared every tick" % pattern)
		_check(float(simulation.state.difficulty) > 1.0, "%s still increases difficulty with elapsed run time" % pattern)
		_check(absf(float(simulation.state.time) - 60.0) < 0.01, "%s still advances the ordinary run clock" % pattern)

func _test_exploration_and_expiry() -> void:
	var simulation = _fresh()
	var outbound: Dictionary = _advance(simulation, 180, {1: {"move": 1.0}})
	_check(int(outbound.count) > 0 and int(outbound.count) <= 6, "Walking into fresh terrain starts a bounded ambient wave")
	_check(float(simulation.state.time) > 2.9, "Exploration advances the ordinary run clock")
	var tail: Dictionary = _advance(simulation, 360)
	_check(int(tail.count) <= 2, "Stopping permits at most the remainder of the finite exploration wave")
	var resting_difficulty: float = simulation.state.difficulty
	var resting_time: float = simulation.state.time
	var rested: Dictionary = _advance(simulation, 3600)
	_check(int(rested.count) == 0, "After the exploration window expires a full minute of rest creates no enemies")
	_check(float(simulation.state.difficulty) > resting_difficulty and float(simulation.state.time) > resting_time + 59.0, "Rest stops replenishment while the real-time difficulty clock continues")
	var revisited: Dictionary = _advance(simulation, 180, {1: {"move": -1.0}})
	_check(int(revisited.count) == 0, "Walking back through already explored terrain cannot farm another ambient wave")
	_advance(simulation, 360)
	var returned: Dictionary = _advance(simulation, 180, {1: {"move": 1.0}})
	_check(int(returned.count) == 0, "Repeating the same route does not bank new spawn budget")
	var fresh_terrain: Dictionary = _advance(simulation, 90, {1: {"move": 1.0}})
	_check(int(fresh_terrain.count) > 0 and int(fresh_terrain.count) <= 4, "Exploring after a long rest starts a small wave without accumulated-budget burst")

func _test_coop_spawn_target() -> void:
	var simulation = _fresh(4)
	for id in [2, 3, 4]:
		var player: Dictionary = simulation.state.players[id]
		player.pos = Vector2(float(simulation.state.world_size.x) - 600.0 + id * 35.0, Vector2(simulation.state.players[1].pos).y)
		player.explore_anchor = player.pos
		player.explore_sites = [player.pos]
	var result: Dictionary = _advance(simulation, 180, {1: {"move": 1.0}})
	var far_from_idle: bool = true
	for position in result.positions:
		for id in [2, 3, 4]:
			far_from_idle = far_from_idle and Vector2(position).distance_to(simulation.state.players[id].pos) > 900.0
	_check(int(result.count) > 0, "One active explorer can start a wave in a four-player party")
	_check(far_from_idle, "Ambient spawn positions follow the active explorer rather than distant idle teammates")
	_advance(simulation, 360)
	_check(int(_advance(simulation, 1800).count) == 0, "A four-player party does not multiply idle background spawning")

func _place_for_event(simulation, player: Dictionary, position: Vector2) -> void:
	# Facilities are drawn 17px above support, while a player is 21px tall
	# below its center. Stand on the surface instead of teleporting inside it.
	player.pos = Vector2(position.x, simulation._surface_below(position.x, position.y - 40.0) - Simulation.PLAYER_HALF.y)
	player.vel = Vector2.ZERO
	player.explore_anchor = player.pos
	player.explore_sites = [player.pos]
	player.explore_window = 0.0
	player.explore_budget = 0

func _test_explicit_events() -> void:
	var gate_sim = _fresh()
	var player: Dictionary = gate_sim.state.players[1]
	_place_for_event(gate_sim, player, gate_sim.state.gate.pos)
	gate_sim.step(DT, {1: {"interact": true, "interact_target": {"kind": "gate", "id": -1}}})
	_check(bool(gate_sim.state.gate.active) and bool(gate_sim.state.boss_alive), "Explicit gate activation starts its boss event while standing still")
	var gate_enemies_before: int = gate_sim.state.enemies.size()
	_advance(gate_sim, 600, {}, false)
	_check(gate_sim.state.enemies.size() > gate_enemies_before and bool(gate_sim.state.director.event_active), "An active gate receives reinforcement during its deliberate event")
	var challenge_sim = _fresh()
	var challenge: Dictionary = {}
	for chest in challenge_sim.state.chests:
		if chest.type == "combat":
			challenge = chest
			break
	_place_for_event(challenge_sim, challenge_sim.state.players[1], challenge.pos)
	challenge_sim.step(DT, {1: {"interact": true, "interact_target": {"kind": "chest", "id": challenge.id}}})
	_check(str(challenge.status) == "active" and challenge_sim.state.enemies.size() > 0, "A deliberate combat trial starts its linked wave without exploration movement")
	_advance(challenge_sim, 180, {}, false)
	_check(bool(challenge_sim.state.director.event_active), "The linked trial remains an active event while its player stays nearby")
	for enemy in challenge_sim.state.enemies.duplicate():
		challenge_sim._damage_enemy(enemy, 1000000.0, 1, false, 0)
	challenge_sim.step(DT, {})
	_check(str(challenge.status) == "cleared" and not challenge_sim.state.pickups.is_empty(), "Clearing the explicit linked wave still produces its ground reward")
	_advance(challenge_sim, 360)
	var settled: float = challenge_sim.state.difficulty
	_check(int(_advance(challenge_sim, 3600).count) == 0 and float(challenge_sim.state.difficulty) > settled, "A completed trial stops replenishing enemies while elapsed-time difficulty keeps rising")

func _test_elapsed_time_scaling() -> void:
	var health: Array[float] = []
	var damage: Array[float] = []
	for elapsed in [0.0, 120.0, 600.0]:
		var simulation = _fresh()
		simulation.state.time = elapsed
		simulation.step(DT, {})
		var enemy: Dictionary = simulation._spawn_enemy("spitter", simulation.state.players[1].pos + Vector2(400, 0))
		health.append(float(enemy.max_hp))
		simulation._enemy_shoot(enemy, Vector2.LEFT, 100.0, 10.0, "orb")
		damage.append(float(simulation.state.projectiles.back().damage))
	_check(health[0] < health[1] and health[1] < health[2], "Fresh enemies at 0, 120 and 600 elapsed seconds have strictly increasing maximum health")
	_check(damage[0] < damage[1] and damage[1] < damage[2], "Real enemy attack projectiles at 0, 120 and 600 seconds deal increasing damage")
