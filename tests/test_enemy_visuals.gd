extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/enemy_catalog.gd")
const WorldView = preload("res://scripts/world_view.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var simulation = Simulation.new()
	simulation.start_run([{"id": 1, "name": "Observer", "character": "ranger"}, {"id": 2, "name": "Ally", "character": "vanguard"}], 2707)
	var world = WorldView.new()
	root.add_child(world)
	world.set_process(false)
	world.interpolate_remote_entities = true
	var seen_attacks: Dictionary = {}
	var seen_hazards: Dictionary = {}
	var seen_enemies: Dictionary = {}
	for stage: int in [1, 2, 3]:
		simulation._build_stage(stage)
		simulation._spawn_clock = 9999.0
		var center: Vector2 = Vector2(float(simulation.state.world_size.x) * 0.42, float(simulation.state.floor_y) - 21.0)
		for player: Dictionary in simulation.state.players.values():
			player.pos = center + Vector2((int(player.id) - 1) * 24.0, 0.0)
			player.vel = Vector2.ZERO
			player.invuln = 1000.0
			simulation._reset_exploration(player, true)
		var index: int = 0
		for kind: String in Catalog.pool(str(simulation.state.biome)):
			var enemy: Dictionary = simulation._spawn_enemy(kind, center + Vector2([-230.0, 290.0, 430.0, 220.0][index], -100.0))
			seen_enemies[kind] = true
			if kind != "conductor": enemy.hp = float(enemy.max_hp) * 0.75
			index += 1
		simulation._spawn_enemy("boss", center + Vector2(570.0, -95.0))
		var readonly: bool = true
		var bounded: bool = true
		var finite: bool = true
		for tick: int in range(600):
			simulation.step(1.0 / 60.0, {})
			for enemy: Dictionary in simulation.state.enemies:
				if float(enemy.get("telegraph", 0.0)) > 0.0:
					seen_attacks[str(enemy.get("attack_kind", ""))] = true
					finite = finite and Vector2(enemy.get("attack_dir", Vector2.ZERO)).is_finite() and Vector2(enemy.get("attack_target", Vector2.ZERO)).is_finite()
			for hazard: Dictionary in simulation.state.get("hazards", []):
				seen_hazards[str(hazard.get("shape", ""))] = true
				finite = finite and Vector2(hazard.pos).is_finite() and Vector2(hazard.dir).is_finite() and float(hazard.radius) > 0.0
			var frame: Dictionary = simulation.get_snapshot()
			var before_frame: PackedByteArray = var_to_bytes(frame)
			var events_before: PackedByteArray = var_to_bytes(simulation.events)
			world.fx_scale = 0.5 if tick < 300 else 1.5
			world.set_frame(frame, 1, 1.0 / 60.0)
			world.push_events(simulation.events)
			world.call("_process", 1.0 / 60.0)
			if tick % 30 == 0:
				await process_frame
			readonly = readonly and var_to_bytes(frame) == before_frame and var_to_bytes(simulation.events) == events_before
			var budget: Dictionary = world.visual_budget_stats()
			bounded = bounded and int(budget.effects) <= int(budget.max_effects) and int(budget.damage_numbers) <= int(budget.max_damage_numbers) and float(budget.shake) <= 5.0
		_check(readonly, "Biome %d real enemy attacks render without changing incoming snapshots or event payloads" % stage)
		_check(bounded, "Biome %d boss and ordinary enemy effects stay within existing effect, number and shake budgets" % stage)
		_check(finite, "Biome %d real telegraphs and hazards expose finite drawable geometry" % stage)
	_check(seen_enemies.size() == 10, "The three real biome snapshots cover ten distinct ordinary enemy silhouettes")
	_check(seen_attacks.size() >= 9 and not seen_attacks.has(""), "The renderer consumes real windups from at least nine distinct enemy attack patterns")
	_check(seen_hazards.has("circle") and seen_hazards.has("line"), "Real enemy AI produces both area and locked-line hazards for the threat overlay")
	world.queue_free()
	await process_frame
	print("ENEMY_VISUAL_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)
