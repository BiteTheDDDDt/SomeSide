extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_test_atomic_transition()
	_test_dead_enemy_and_rescue()
	_test_downward_grenade()
	_test_stage_reachability()
	_test_shared_economy()
	_test_four_player_stress(false)
	_test_four_player_stress(true)
	print("STRESS_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _new_sim(count: int = 4) -> RefCounted:
	var simulation = Simulation.new()
	var roster: Array = []
	for index in range(count):
		roster.append({"id": index + 1, "name": "Stress %d" % index, "character": "ranger" if index % 2 == 0 else "vanguard"})
	simulation.start_run(roster, 20261004)
	return simulation

func _test_atomic_transition() -> void:
	var simulation = _new_sim(2)
	var expected = _new_sim(2)
	expected._build_stage(2)
	simulation.state.gate.ready = true
	simulation.state.gate.active = true
	simulation.state.players[1].pos = simulation.state.gate.pos
	simulation.state.players[2].pos = simulation.state.gate.pos
	simulation._spawn_projectile(simulation.state.gate.pos, Vector2.LEFT * 200.0, "enemy", "orb", 20.0, -1, 5.0, 6.0)
	simulation.step(DT, {1: {"interact": true}, 2: {"fire": true, "skill": true, "move": 1.0, "jump": true}})
	_check(int(simulation.state.stage) == 2, "Interaction loads the next stage")
	_check(simulation.state.projectiles.is_empty(), "Stage transition removes old projectiles and ignores remaining old-stage fire commands")
	_check(Vector2(simulation.state.players[2].pos) == Vector2(expected.state.players[2].pos), "Later players remain at the new map's actual spawn instead of applying a previous-stage command")
	_check(simulation.events.size() == 1 and str(simulation.events[0].type) == "stage", "Only the new stage event survives the transition boundary")

func _test_dead_enemy_and_rescue() -> void:
	var simulation = _new_sim(2)
	var player: Dictionary = simulation.state.players[1]
	player.invuln = 0.0
	simulation._spawn_enemy("spitter", Vector2(player.pos) + Vector2(60.0, 0.0))
	var enemy: Dictionary = simulation.state.enemies[0]
	enemy.attack_cd = 0.0
	simulation._damage_enemy(enemy, 10000.0, 1, false, 0)
	simulation.step(DT, {})
	_check(simulation.state.projectiles.is_empty(), "An enemy killed before its AI update cannot attack later in the same tick")
	var downed: Dictionary = simulation.state.players[2]
	downed.dead = true
	downed.hp = 0.0
	downed.pos = player.pos
	simulation.step(DT, {1: {"interact": true}})
	_check(float(downed.revive_timer) > 0.0, "A living teammate starts a rescue beacon")
	player.dead = true
	player.hp = 0.0
	simulation.step(DT, {})
	for index in range(180):
		simulation.step(DT, {})
	_check(str(simulation.state.phase) == "lost" and bool(downed.dead), "A full wipe stops an unfinished rescue rather than reviving after defeat")

func _test_downward_grenade() -> void:
	var simulation = _new_sim(1)
	simulation.step(DT, {1: {"aim": Vector2.DOWN, "skill": true}})
	var exploded: bool = false
	for event_value in simulation.events:
		var event: Dictionary = event_value
		if str(event.type) == "explosion":
			exploded = true
	_check(exploded and simulation.state.projectiles.is_empty(), "A grenade aimed into the ground detonates instead of escaping below the floor")

func _test_stage_reachability() -> void:
	var topology_signatures: Array = []
	for character in ["ranger", "vanguard"]:
		var simulation = Simulation.new()
		simulation.start_run([{"id": 1, "name": "Route Tester", "character": character}], 20261004)
		for stage in range(1, 4):
			simulation._build_stage(stage)
			var platforms: Array = simulation.state.platforms
			var spawn: Vector2 = simulation.state.players[1].pos
			var source_platform: int = _support_below(platforms, spawn)
			var reachable: Dictionary = {source_platform: true}
			var progress: bool = true
			while progress:
				progress = false
				for target_index in range(platforms.size()):
					if reachable.has(target_index):
						continue
					for source_index in reachable.keys():
						if _can_jump_between(simulation, platforms[int(source_index)], platforms[target_index]):
							reachable[target_index] = true
							progress = true
							break
			var missing: Array = []
			for index in range(platforms.size()):
				if not reachable.has(index):
					missing.append(index)
			_check(reachable.size() == platforms.size(), "%s stage %d: all platforms reachable by single jumps with no item or dash, 32px takeoff margin, 24px landing margin and +/-12px starting tolerance (%d/%d; missing %s)" % [character, stage, reachable.size(), platforms.size(), str(missing)])
			_check(float(simulation.state.chests[0].cost) <= 35.0 or stage > 1, "The introductory chest is affordable before earning any money")
			var destinations_supported: bool = true
			var destinations: Array = simulation.state.chests.duplicate()
			destinations.append(simulation.state.gate)
			for destination in destinations:
				var support: int = _support_below(platforms, destination.pos)
				destinations_supported = destinations_supported and support >= 0 and reachable.has(support)
			_check(destinations_supported, "%s stage %d: every facility and the gate have support on the reachable route graph" % [character, stage])
			if character == "ranger":
				var world: Vector2 = simulation.state.world_size
				var bounds := Rect2(Vector2.ZERO, world)
				var contained: bool = true
				for platform in platforms:
					contained = contained and bounds.encloses(platform)
				_check(contained and world.x * world.y > 3200.0 * 1100.0 * 1.75 and platforms.size() > 16, "Stage %d is substantially larger than v0.3 and all platforms fit its own dynamic world bounds" % stage)
				topology_signatures.append(_topology_signature(platforms, world))
				var player: Dictionary = simulation.state.players[1]
				player.pos = Vector2(simulation.state.gate.pos.x, float(simulation.state.floor_y) - Simulation.PLAYER_HALF.y)
				simulation._interact(player, {"kind": "gate", "id": -1})
				_check(not simulation.state.gate.active, "Stage %d elevated gate cannot be activated from the bottom floor directly beneath it" % stage)
				var gate_support: int = _support_below(platforms, simulation.state.gate.pos)
				if gate_support >= 0:
					player.pos = Vector2(simulation.state.gate.pos.x, Rect2(platforms[gate_support]).position.y - Simulation.PLAYER_HALF.y)
					player.interact_cd = 0.0
					simulation._interact(player, {"kind": "gate", "id": -1})
				_check(bool(simulation.state.gate.active), "Stage %d gate activates normally from its reachable platform" % stage)
	for first in range(topology_signatures.size()):
		for second in range(first + 1, topology_signatures.size()):
			var a: Dictionary = topology_signatures[first]
			var b: Dictionary = topology_signatures[second]
			var shared: int = 0
			for cell in a:
				if b.has(cell):
					shared += 1
			var similarity: float = float(shared) / maxf(1.0, a.size() + b.size() - shared)
			_check(similarity < 0.75, "Stages %d/%d differ structurally on a normalized 12x8 platform grid (overlap %.2f)" % [first + 1, second + 1, similarity])

func _support_below(platforms: Array, position: Vector2) -> int:
	var closest: float = INF
	var result: int = -1
	for index in range(platforms.size()):
		var platform: Rect2 = platforms[index]
		var separation: float = platform.position.y - position.y
		if position.x >= platform.position.x and position.x <= platform.end.x and separation >= -1.0 and separation <= 85.0 and separation < closest:
			closest = separation
			result = index
	return result

func _topology_signature(platforms: Array, world: Vector2) -> Dictionary:
	# Normalize size before comparing topology, so merely stretching or shifting
	# an old staircase cannot masquerade as three genuinely different maps.
	var occupied: Dictionary = {}
	for platform_value in platforms:
		var platform: Rect2 = platform_value
		if platform.size.x > world.x * 0.9:
			continue
		var center: Vector2 = platform.get_center() / world
		occupied[Vector2i(int(center.x * 12.0), int(center.y * 8.0))] = true
	return occupied

func _can_jump_between(simulation: RefCounted, source: Rect2, target: Rect2) -> bool:
	# Use real movement/collision, one jump press and generous interior landing.
	# Each accepted graph edge must also work from both +/-12px takeoff offsets.
	var rise: float = source.position.y - target.position.y
	if rise > 126.0 or source.size.x < 88.0:
		return false
	var gap: float = maxf(target.position.x - source.end.x, source.position.x - target.end.x)
	if gap > 450.0 and rise > -250.0:
		return false
	var desired_x: float = target.get_center().x
	var takeoffs: Array[float] = [clampf(desired_x, source.position.x + 44.0, source.end.x - 44.0), source.get_center().x]
	if desired_x > source.get_center().x:
		takeoffs.append(source.end.x - 44.0)
	else:
		takeoffs.append(source.position.x + 44.0)
	for takeoff in takeoffs:
		for jump_delay in [0]:
			var successes: int = 0
			for deviation in [-12.0, 0.0, 12.0]:
				var player: Dictionary = simulation.state.players[1].duplicate(true)
				player.items = {}
				player.pos = Vector2(takeoff + deviation, source.position.y - 21.0)
				player.vel = Vector2.ZERO
				player.grounded = true
				player.jumps = 0
				player.dash_timer = 0.0
				player.drop_timer = 0.0
				for tick in range(110):
					var offset: float = desired_x - Vector2(player.pos).x
					var movement: float = signf(offset) if absf(offset) > 15.0 else 0.0
					simulation.predict_player(player, {"move": movement, "jump": tick == int(jump_delay)}, DT)
					var position: Vector2 = player.pos
					if tick > jump_delay + 2 and bool(player.grounded) and absf(position.y + 21.0 - target.position.y) < 0.1 and position.x >= target.position.x + 24.0 and position.x <= target.end.x - 24.0:
						successes += 1
						break
			if successes == 3:
				return true
	return false

func _test_shared_economy() -> void:
	var simulation = _new_sim(4)
	var spawn: Vector2 = simulation.state.players[1].pos
	for player_value in simulation.state.players.values():
		var player: Dictionary = player_value
		player.pos = spawn
	for index in range(12):
		simulation._spawn_enemy("crawler", spawn)
		var enemy: Dictionary = simulation.state.enemies.back()
		simulation._damage_enemy(enemy, 9999.0, 1, false, 0)
	simulation.step(DT, {})
	var everyone_paid: bool = true
	for player_value in simulation.state.players.values():
		var player: Dictionary = player_value
		everyone_paid = everyone_paid and int(player.coins) == 83
	_check(everyone_paid, "Twelve common kills pay 48 shared coins to every player, enough for another chest each")

func _test_four_player_stress(with_build: bool) -> void:
	var simulation = _new_sim(4)
	simulation.state.time = 1200.0
	var base_position: Vector2 = simulation.state.players[1].pos
	for player_value in simulation.state.players.values():
		var player: Dictionary = player_value
		player.pos = base_position + Vector2(250.0 + int(player.id) * 135.0, 0.0)
		player.invuln = 9999.0
		if with_build:
			player.weapon = ["flamethrower", "boomerang", "storm_staff", "sun_lance"][int(player.id) - 1]
			player.equipment = ["graviton", "turret", "meteor", "time_warp"][int(player.id) - 1]
			for definition in Simulation.item_catalog():
				for index in range(12):
					simulation._grant_item(player, str(definition.id))
	var max_enemies: int = 0
	var max_projectiles: int = 0
	var max_events: int = 0
	var max_deployables: int = 0
	var max_delayed_effects: int = 0
	var finite: bool = true
	var bounded: bool = true
	var started: int = Time.get_ticks_usec()
	var worst_tick_usec: int = 0
	for tick in range(7200):
		# Pressure here is explicit test input: resting no longer generates
		# ambient enemies, so do not confuse safety-at-rest with a failed load test.
		if not with_build and tick % 120 == 0:
			for spawn in range(4):
				simulation._spawn_enemy("crawler" if spawn % 2 == 0 else "drone", Vector2(simulation.state.players[1].pos) + Vector2(200.0 + spawn * 55.0, -50.0 - spawn * 35.0), true)
		if with_build and tick % 8 == 0:
			for spawn in range(4):
				simulation._spawn_enemy("crawler" if spawn % 2 == 0 else "drone", Vector2(simulation.state.players[1].pos) + Vector2(200.0 + spawn * 55.0, -50.0 - spawn * 35.0), true)
		var commands: Dictionary = {}
		for player_value in simulation.state.players.values():
			var player: Dictionary = player_value
			var aim: Vector2 = Vector2.LEFT
			var nearest: float = INF
			for enemy_value in simulation.state.enemies:
				var enemy: Dictionary = enemy_value
				var offset: Vector2 = Vector2(enemy.pos) - Vector2(player.pos)
				if offset.length_squared() < nearest:
					nearest = offset.length_squared()
					aim = offset.normalized()
			commands[player.id] = {"aim": aim, "fire": with_build, "skill": with_build and tick % 91 == 0, "jump": tick % 137 == 0}
		var tick_start: int = Time.get_ticks_usec()
		simulation.step(DT, commands)
		worst_tick_usec = maxi(worst_tick_usec, Time.get_ticks_usec() - tick_start)
		max_enemies = maxi(max_enemies, simulation.state.enemies.size())
		max_projectiles = maxi(max_projectiles, simulation.state.projectiles.size())
		max_events = maxi(max_events, simulation.events.size())
		max_deployables = maxi(max_deployables, simulation.state.deployables.size())
		max_delayed_effects = maxi(max_delayed_effects, simulation.state.effects.size())
		bounded = bounded and simulation.state.enemies.size() <= 44 and simulation.state.projectiles.size() <= 280 and simulation.state.pickups.size() <= 90 and simulation.events.size() <= 64
		bounded = bounded and simulation.state.deployables.size() <= 4 and simulation.state.effects.size() <= 24
		for collection in [simulation.state.players.values(), simulation.state.enemies, simulation.state.projectiles, simulation.state.pickups, simulation.state.deployables, simulation.state.effects]:
			for entity_value in collection:
				var entity: Dictionary = entity_value
				finite = finite and Vector2(entity.pos).is_finite()
				if entity.has("vel"):
					finite = finite and Vector2(entity.vel).is_finite()
				if entity.has("hp"):
					finite = finite and is_finite(float(entity.hp)) and float(entity.hp) >= 0.0
	var elapsed_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	var label: String = "12-stack proc build" if with_build else "enemy accumulation"
	_check(finite, "Four-player %s stays numerically finite for 120 simulated seconds" % label)
	_check(bounded, "Four-player %s respects all entity and event budgets" % label)
	_check(str(simulation.state.phase) == "playing" and absf(float(simulation.state.time) - 1320.0) < 0.01, "Four-player %s advances all 7200 ticks" % label)
	print("STRESS_METRICS mode=", label, " kills=", simulation.state.kills, " max_enemies=", max_enemies, " max_projectiles=", max_projectiles, " max_events=", max_events, " max_deployables=", max_deployables, " max_delayed_effects=", max_delayed_effects, " elapsed_ms=", elapsed_ms, " worst_step_us=", worst_tick_usec)
