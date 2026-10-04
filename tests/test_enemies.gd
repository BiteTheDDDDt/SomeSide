extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/enemy_catalog.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_test_catalog_and_stage_pools()
	_test_telegraphs_and_attacks()
	_test_dodging()
	_test_support_and_bosses()
	_test_lifecycle_and_snapshot()
	_test_determinism_and_budget()
	print("ENEMY_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _fresh(stage: int = 1, count: int = 1):
	var simulation = Simulation.new()
	var roster: Array = []
	for index in range(count): roster.append({"id": index + 1, "name": "Enemy probe", "character": "ranger"})
	simulation.start_run(roster, 70707)
	if stage != 1: simulation._build_stage(stage)
	simulation.state.floor_y = 1000.0
	simulation.state.platforms = [Rect2(0, 1000, simulation.state.world_size.x, 100)]
	simulation.state.chests = []
	for player in simulation.state.players.values():
		player.pos = Vector2(1000, 979)
		player.vel = Vector2.ZERO
		player.grounded = true
		player.invuln = 0.0
		simulation._reset_exploration(player, true)
	return simulation

func _advance(simulation, ticks: int, commands: Dictionary = {}) -> void:
	for tick in range(ticks): simulation.step(DT, commands)

func _spawn(simulation, id: String, distance: float = 300.0) -> Dictionary:
	var enemy: Dictionary = simulation._spawn_enemy(id, Vector2(1000.0 + distance, 983.0))
	enemy.attack_cd = 0.0
	enemy.grounded = true
	return enemy

func _test_catalog_and_stage_pools() -> void:
	var seen: Dictionary = {}
	var valid: bool = Catalog.catalog().size() == 9
	for entry in Catalog.catalog():
		valid = valid and not seen.has(entry.id) and float(entry.windup) >= 0.55 and float(entry.windup) <= 0.9 and float(entry.cooldown) >= 2.5
		seen[entry.id] = true
	_check(valid and seen.has("crawler") and seen.has("spitter") and seen.has("drone"), "Nine distinct enemies preserve the legacy IDs and provide bounded readable attack timing")
	var unique_styles: Dictionary = {}
	for stage in range(1, 4):
		var simulation = _fresh(stage)
		var biome: String = simulation.state.biome
		var pool: Array[String] = Catalog.pool(biome)
		var owned: bool = pool.size() == 3
		for kind in pool: owned = owned and str(Catalog.definition(kind).biome) == biome
		owned = owned and Catalog.flying_kind(biome) in pool and bool(Catalog.definition(Catalog.flying_kind(biome)).flying)
		_check(owned, "Stage %d has its own pool and an in-biome flying fallback" % stage)
		simulation.state.gate.active = true
		simulation.state.gate.pos = simulation.state.players[1].pos
		var generated: Dictionary = {}
		for index in range(70):
			simulation.state.enemies.clear()
			simulation._spawn_clock = 0.0
			simulation._step_director(DT)
			for enemy in simulation.state.enemies: generated[str(enemy.kind)] = true
		var only_pool: bool = not generated.is_empty()
		for id in generated: only_pool = only_pool and id in pool
		_check(only_pool and generated.size() == 3, "Stage %d gate reinforcements sample all native enemies without foreign spawns" % stage)
		simulation.state.enemies.clear()
		simulation.state.players[1].pos = Vector2(1000, 200)
		simulation.state.gate.pos = Vector2(1000, 200)
		simulation._spawn_clock = 0.0
		simulation._step_director(DT)
		_check(not simulation.state.enemies.is_empty() and simulation.state.enemies[0].kind == Catalog.flying_kind(biome), "Stage %d isolated balconies use the local flying candidate" % stage)
		simulation.state.enemies.clear()
		var chest: Dictionary = {"id": 9100, "pos": Vector2(1000, 983), "type": "combat", "status": "idle"}
		simulation._start_challenge(chest, simulation.state.players[1])
		var challenge_native: bool = simulation.state.enemies.size() == 4
		for enemy in simulation.state.enemies: challenge_native = challenge_native and str(enemy.kind) in pool
		_check(challenge_native, "Stage %d combat beacons use only the current biome pool" % stage)
		var boss: Dictionary = simulation._spawn_enemy("boss", Vector2(1400, 956))
		unique_styles[str(boss.boss_style)] = true
		_check(str(boss.biome) == biome and str(boss.name) == str(Catalog.boss_definition(biome).name), "Stage %d boss snapshot has its native style and name" % stage)
	_check(unique_styles.size() == 3, "All three bosses have distinct encounter styles")

func _test_telegraphs_and_attacks() -> void:
	for entry in Catalog.catalog():
		var simulation = _fresh()
		var enemy: Dictionary = _spawn(simulation, str(entry.id), 110.0 if str(entry.id) in ["crawler", "charger"] else 300.0)
		simulation.step(DT, {})
		var warned: bool = float(enemy.telegraph) >= 0.55 and str(enemy.attack_kind) == str(entry.attack_kind)
		_advance(simulation, int((float(entry.windup) - 0.12) / DT))
		var safe: bool = float(simulation.state.players[1].hp) == 100.0 and simulation.state.projectiles.is_empty()
		for hazard in simulation.state.hazards: safe = safe and not bool(hazard.active)
		_check(warned and safe, str(entry.id) + ": actual AI warns before firing or applying its attack")
		_advance(simulation, 150)
		_check(float(simulation.state.players[1].hp) < 100.0, str(entry.id) + ": its real attack damages a stationary player")
		_check(float(enemy.attack_cd) > 0.0 or float(enemy.telegraph) > 0.0, str(entry.id) + ": attacks remain cooldown-gated after release")
	var blink = _fresh(3)
	var hunter: Dictionary = _spawn(blink, "skirmisher", 300)
	blink._begin_enemy_attack(hunter, blink.state.players[1])
	_advance(blink, 44)
	_check(str(hunter.attack_kind) == "salvo" and float(hunter.telegraph) > 0.5 and blink.state.projectiles.is_empty(), "Skirmisher gives a second aim warning after teleporting and before firing")
	var shot = _fresh()
	var source: Dictionary = _spawn(shot, "spitter")
	shot._enemy_shoot(source, Vector2.LEFT, 270, 10, "spit")
	_check(shot.events.back().pos == shot.state.projectiles.back().origin and int(shot.events.back().enemy_id) == int(source.id), "Hostile shoot events and bullets share the actual muzzle and attacker metadata")

func _test_dodging() -> void:
	for kind in ["spore_moth", "burrower", "sentinel"]:
		var simulation = _fresh()
		var enemy: Dictionary = _spawn(simulation, kind)
		simulation._begin_enemy_attack(enemy, simulation.state.players[1])
		var target_before: Vector2 = enemy.attack_target
		var direction_before: Vector2 = enemy.attack_dir
		# A single jump lasts about 0.76 seconds: react to the 0.9-second
		# warning after 0.3 seconds, instead of landing before release.
		if kind == "sentinel":
			_advance(simulation, 18)
		var command: Dictionary = {"move": -1.0} if kind != "sentinel" else {"jump": true}
		simulation.step(DT, {1: command})
		_advance(simulation, 39 if kind == "sentinel" else 57, {1: {"move": -1.0 if kind != "sentinel" else 0.0}})
		_check(float(simulation.state.players[1].hp) == 100.0 and enemy.attack_target == target_before and enemy.attack_dir == direction_before, kind + ": real movement during a locked warning dodges the danger")
	var ranged = _fresh()
	var spitter: Dictionary = _spawn(ranged, "spitter")
	ranged._begin_enemy_attack(spitter, ranged.state.players[1])
	_advance(ranged, 46)
	var projectile: Dictionary = ranged.state.projectiles[0]
	_check(Vector2(projectile.vel).length() <= 285.0 and float(projectile.damage) == 10.0, "Normal hostile bullets have dodgeable speed and bounded base damage")
	var old_dir: Vector2 = spitter.attack_dir
	ranged.state.players[1].pos += Vector2(0, -180)
	_advance(ranged, 55)
	_check(Vector2(projectile.vel).normalized().dot(old_dir) > 0.999, "Released bullets do not home onto later player movement")
	for stage in [1, 3]:
		var beam = _fresh(stage)
		var unit: Dictionary = _spawn(beam, "sentinel" if stage == 1 else "boss", 350)
		unit.vel = Vector2(-90, -180)
		beam._begin_enemy_attack(unit, beam.state.players[1])
		var fixed_origin: Vector2 = unit.pos
		_advance(beam, 60)
		_check(unit.pos == fixed_origin, "Ray attacker stage %d holds its exact launch position throughout warning and active frames" % stage)
	var falling = _fresh()
	var grounded_ray: Dictionary = _spawn(falling, "sentinel")
	grounded_ray.pos.y -= 200
	grounded_ray.grounded = false
	falling.step(DT, {})
	_check(float(grounded_ray.telegraph) == 0.0 and falling.state.hazards.is_empty(), "A falling ground sentinel lands before beginning its fixed-origin beam")
	for kind in ["burrower", "boss"]:
		var ground_attack = _fresh(2)
		var attacker: Dictionary = _spawn(ground_attack, kind)
		ground_attack.state.players[1].pos.y = 850.0
		ground_attack._begin_enemy_attack(attacker, ground_attack.state.players[1])
		var supported: bool = not ground_attack.state.hazards.is_empty()
		for hazard in ground_attack.state.hazards:
			supported = supported and is_equal_approx(Vector2(hazard.pos).y, 983.0)
		_check(supported, kind + ": ground eruptions lock onto a real support surface even when their target is airborne")

func _test_support_and_bosses() -> void:
	var support = _fresh(3)
	var conductor: Dictionary = _spawn(support, "conductor", 500)
	var ally: Dictionary = _spawn(support, "sentinel", 530)
	conductor.attack_kind = "mend"
	var gained: float = 0.0
	for cycle in range(20):
		ally.hp = 1.0
		support._release_enemy_attack(conductor, support.state.players[1])
		gained += float(ally.hp) - 1.0
	_check(is_equal_approx(gained, 48.0) and float(conductor.heal_budget) == 0.0, "Conductor healing exhausts a finite 48-health lifetime budget")
	ally.hp = 0.0
	conductor.heal_budget = 48.0
	support._release_enemy_attack(conductor, support.state.players[1])
	_check(float(ally.hp) == 0.0, "Conductor cannot resurrect dead enemies")
	for stage in range(1, 4):
		var simulation = _fresh(stage)
		var boss: Dictionary = simulation._spawn_enemy("boss", Vector2(1400, 956))
		boss.attack_cd = 0.0
		boss.grounded = true
		simulation.step(DT, {})
		var first: String = boss.attack_kind
		var warned: bool = float(boss.telegraph) >= 0.85
		_advance(simulation, 160)
		var delivered: bool = float(simulation.state.players[1].hp) < 100.0
		boss.attack_cd = 0.0
		boss.telegraph = 0.0
		simulation.step(DT, {})
		_check(warned and delivered and first != str(boss.attack_kind), "Stage %d boss alternates between distinct real damaging patterns" % stage)

func _test_lifecycle_and_snapshot() -> void:
	var simulation = _fresh(3, 2)
	var enemy: Dictionary = _spawn(simulation, "sentinel")
	simulation._begin_enemy_attack(enemy, simulation.state.players[1])
	var client = Simulation.new()
	client.apply_snapshot(simulation.get_snapshot())
	client.state.hazards[0].hit_ids.append(99)
	client.state.enemies[0].attack_target += Vector2.ONE
	_check(simulation.state.hazards[0].hit_ids.is_empty() and simulation.state.enemies[0].attack_target != client.state.enemies[0].attack_target, "Cooperative snapshots independently copy warnings and danger hit records")
	_advance(simulation, 62)
	_check(float(simulation.state.players[1].hp) == float(simulation.state.players[2].hp) and float(simulation.state.players[1].hp) < 100.0, "An active ray damages each exposed teammate once")
	var cancelled = _fresh()
	var moth: Dictionary = _spawn(cancelled, "spore_moth")
	cancelled._begin_enemy_attack(moth, cancelled.state.players[1])
	moth.hp = 0.0
	_advance(cancelled, 80)
	_check(cancelled.state.hazards.is_empty() and float(cancelled.state.players[1].hp) == 100.0, "Killing an attacker cancels its pending danger and postmortem damage")
	var interrupted = _fresh()
	var sentinel: Dictionary = _spawn(interrupted, "sentinel")
	interrupted._begin_enemy_attack(sentinel, interrupted.state.players[1])
	sentinel.stun_timer = 2.0
	interrupted.step(DT, {})
	_check(interrupted.state.hazards.is_empty() and float(sentinel.telegraph) == 0.0, "Stunning an attacker cancels its unfinished warning and danger")
	var stage_change = _fresh()
	var source: Dictionary = _spawn(stage_change, "spore_moth")
	stage_change._begin_enemy_attack(source, stage_change.state.players[1])
	stage_change._build_stage(2)
	_check(stage_change.state.hazards.is_empty() and stage_change.state.enemies.is_empty() and stage_change.state.projectiles.is_empty(), "Stage changes clear all hostile dangers, attackers and bullets")

func _test_determinism_and_budget() -> void:
	var a = _fresh(3, 4)
	var b = _fresh(3, 4)
	for simulation in [a, b]:
		for player in simulation.state.players.values(): player.invuln = 999.0
		for entry in Catalog.catalog(): _spawn(simulation, str(entry.id), 220 + simulation.state.enemies.size() * 30)
	for tick in range(480):
		a.step(DT, {})
		b.step(DT, {})
	_check(a.get_snapshot() == b.get_snapshot(), "Enemy decisions and warnings reproduce under identical seeds and inputs")
	var crowded = _fresh(3, 4)
	for player in crowded.state.players.values(): player.invuln = 999.0
	for index in range(Simulation.MAX_ENEMIES):
		var enemy: Dictionary = _spawn(crowded, "sentinel", 150 + index * 8)
		crowded._begin_enemy_attack(enemy, crowded.state.players[1])
	_check(crowded.state.hazards.size() == Simulation.MAX_HAZARDS, "Simultaneous warnings respect the 24-danger budget")
	var finite: bool = true
	for tick in range(600):
		crowded.step(DT, {})
		finite = finite and crowded.state.hazards.size() <= Simulation.MAX_HAZARDS and crowded.state.projectiles.size() <= Simulation.MAX_PROJECTILES and crowded.events.size() <= 64
		for hazard in crowded.state.hazards: finite = finite and Vector2(hazard.pos).is_finite() and Vector2(hazard.dir).is_finite() and is_finite(float(hazard.delay))
	_check(finite and crowded.state.enemies.size() <= Simulation.MAX_ENEMIES, "Dense four-player combat preserves finite danger geometry and all entity/event budgets")
