extends SceneTree

const Fixtures = preload("res://tools/capture-natural-warnings-v0201.gd")
const World = preload("res://scripts/world_view.gd")
const Beam = preload("res://scripts/enemy_attack_visual.gd")
const DT: float = 1.0 / 60.0
var Natural
var passed: int = 0
var failed: int = 0

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS: ", label)
	else: failed += 1; push_error("FAIL: " + label)

func _run() -> void:
	Natural = load("res://scripts/natural_threats.gd")
	if Natural == null:
		_check(false, "The natural threat material module loads")
	else:
		for attack: String in Fixtures.CASES:
			await _real_attack(attack)
		await _locked_dodge()
		_test_no_auxiliary_primitives()
	print("NATURAL_WARNINGS_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _new_world(low: bool):
	var world = World.new()
	world.screen_size = Vector2(960, 540)
	world.scenery_cache_enabled = false
	world.shake_enabled = false
	world.fx_scale = 0.0 if low else 1.0
	world.reduced_motion = low
	root.add_child(world)
	world.set_process(false)
	return world

func _real_attack(attack: String) -> void:
	var setup: Dictionary = Fixtures.fixture(attack, false)
	var sim = setup.sim
	var reference = Fixtures.fixture(attack, false).sim
	var enemy: Dictionary = setup.enemy
	_check(str(enemy.attack_kind) == attack and float(enemy.telegraph) >= 0.55, attack + ": the real AI starts its existing timed attack")
	var world = _new_world(true)
	var unchanged: bool = true
	var readonly: bool = true
	var quiet_until_release: bool = true
	var bad_effect: bool = false
	var release_seen: bool = false
	var active_seen: bool = false
	var enemy_releases: int = 0
	var initial_hp: float = sim.state.players[1].hp
	var original_hazards: Dictionary = {}
	for hazard: Dictionary in sim.state.hazards: original_hazards[int(hazard.id)] = hazard.duplicate(true)
	var locked: bool = true
	var damage_before_active: bool = false
	var slow_samples_valid: bool = true
	var active_samples_valid: bool = true
	var warning_material: bool = false
	var active_material: bool = false
	var initial_healing: Dictionary = {}
	if attack == "mend":
		for ally: Dictionary in sim.state.enemies:
			if int(ally.id) != int(enemy.id): initial_healing[int(ally.id)] = float(ally.hp)
	for tick: int in range(210):
		var winding: bool = str(enemy.attack_kind) == attack and float(enemy.telegraph) > 0.0
		# Hazards begin counting down on their creation tick; the attacker's
		# own timer advances next tick. The damage body's active flag, rather
		# than rounded visual timer equality, is the authoritative boundary.
		var hazard_active: bool = Array(sim.state.hazards).any(func(h: Dictionary) -> bool: return bool(h.active))
		if not winding or hazard_active: release_seen = true
		if not release_seen and float(sim.state.players[1].hp) < initial_hp: quiet_until_release = false
		for hazard: Dictionary in sim.state.hazards:
			if not original_hazards.has(int(hazard.id)): continue
			var original: Dictionary = original_hazards[int(hazard.id)]
			locked = locked and hazard.pos == original.pos and hazard.dir == original.dir and hazard.length == original.length and hazard.radius == original.radius
			if bool(hazard.active): active_seen = true
			var samples: Array = []
			for option: Array in [[1.0, false], [0.0, false], [0.0, true]]:
				var data: Dictionary = Beam.beam_sample(hazard, option[0], option[1]) if str(hazard.shape) == "line" else Natural.area_sample(hazard, option[0], option[1])
				samples.append(data)
				var alpha: float = float(data.get("material_alpha", 0.0))
				var size: Vector2 = data.get("material_size", data.get("size", Vector2.ZERO))
				var valid: bool = alpha > 0.0 and is_finite(alpha) and size.is_finite() and size.x > 0 and size.y > 0
				if bool(hazard.active): active_samples_valid = active_samples_valid and valid; active_material = true
				else: slow_samples_valid = slow_samples_valid and valid; warning_material = true
			for variant: Dictionary in samples:
				locked = locked and variant.origin == hazard.pos and variant.radius == hazard.radius and variant.active == hazard.active
				if str(hazard.shape) == "line": locked = locked and variant.end == Vector2(hazard.pos) + Vector2(hazard.dir) * float(hazard.length) and variant.direction == hazard.dir
		if not original_hazards.is_empty() and not active_seen and float(sim.state.players[1].hp) < initial_hp: damage_before_active = true
		var snapshot: Dictionary = sim.get_snapshot()
		var before: PackedByteArray = var_to_bytes(snapshot)
		world._process(DT)
		world.set_frame(snapshot, 1, DT)
		world.camera_position = setup.camera
		world.push_events(sim.events)
		for effect: Dictionary in world._effects:
			if str(effect.get("kind", "")) in ["ring", "blast"]: bad_effect = true
		for event: Dictionary in sim.events:
			if event.type == "explosion" and event.get("team", "") == "enemy": enemy_releases += 1
		if tick % 60 == 0: await process_frame
		readonly = readonly and var_to_bytes(snapshot) == before
		unchanged = unchanged and var_to_bytes(sim.get_snapshot()) == var_to_bytes(reference.get_snapshot())
		sim.step(DT, {})
		reference.step(DT, {})
	_check(quiet_until_release and release_seen, attack + ": warning remains harmless until the authority releases the attack")
	_check(unchanged and readonly, attack + ": low-FX World rendering cannot change damage, timings, RNG, or shared snapshots")
	_check(not bad_effect, attack + ": real hostile events never reintroduce geometric explosion rings or blasts")
	if not original_hazards.is_empty():
		_check(locked, attack + ": authority origin, direction, range and radius stay locked in every material setting")
		_check(warning_material and active_material and slow_samples_valid and active_samples_valid, attack + ": both windup and damaging phases retain visible material even with FX disabled")
		_check(active_seen and not damage_before_active and sim.state.hazards.is_empty() and enemy_releases > 0, attack + ": hazard activation and expiry retain their existing damage window")
	if attack == "blink":
		_check(str(enemy.attack_kind) == "salvo" and int(enemy.attack_count) == 0, "Blink still transitions into its separately warned salvo, without a fabricated hazard")
	elif attack == "mend":
		var healed: int = 0
		var total: float = 0.0
		for ally: Dictionary in sim.state.enemies:
			if initial_healing.has(int(ally.id)):
				var amount: float = float(ally.hp) - float(initial_healing[int(ally.id)])
				if amount > 0: healed += 1; total += amount
		_check(healed == 3 and total == 24.0 and enemy.heal_budget == 24.0, "Natural mend presentation preserves the exact three-target healing budget")
	world.queue_free()
	await process_frame

func _locked_dodge() -> void:
	for attack: String in ["beam", "mortar", "burrow"]:
		var setup: Dictionary = Fixtures.fixture(attack, false)
		var sim = setup.sim
		var enemy: Dictionary = setup.enemy
		var target: Vector2 = enemy.attack_target
		var aim: Vector2 = enemy.attack_dir
		var locked: Dictionary = sim.state.hazards[0].duplicate(true)
		var stable: bool = true
		for tick: int in range(76):
			var command: Dictionary = {"move": -1.0 if attack != "beam" else 0.0, "jump": attack == "beam" and tick == 26, "jump_held": true}
			sim.step(DT, {1: command})
			for hazard: Dictionary in sim.state.hazards:
				if int(hazard.id) == int(locked.id): stable = stable and hazard.pos == locked.pos and hazard.dir == locked.dir
		_check(stable and enemy.attack_target == target and enemy.attack_dir == aim and sim.state.players[1].hp == 100.0, attack + ": real movement still dodges the locked attack after natural-warning changes")

func _function_text(source: String, name: String) -> String:
	var start: int = source.find("func " + name + "(")
	if start < 0: return ""
	var end: int = source.find("\nfunc ", start + 1)
	var next_static: int = source.find("\nstatic func ", start + 1)
	if next_static >= 0 and (end < 0 or next_static < end): end = next_static
	return source.substr(start, source.length() - start if end < 0 else end - start)

func _test_no_auxiliary_primitives() -> void:
	# Static guard complements the actual native captures: these exact World
	# entry points must not quietly restore lines/rings behind natural sprites.
	var world_source: String = FileAccess.get_file_as_string("res://scripts/world_view.gd")
	var material_source: String = FileAccess.get_file_as_string("res://scripts/natural_threats.gd")
	var beam_source: String = FileAccess.get_file_as_string("res://scripts/enemy_attack_visual.gd")
	for record: Array in [[world_source, "_draw_threat_overlays"], [world_source, "_draw_hazard"], [material_source, "draw_area"], [beam_source, "draw_beam"], [beam_source, "draw_lane"]]:
		var body: String = _function_text(record[0], record[1])
		var safe: bool = not body.is_empty()
		for primitive: String in ["draw_line(", "draw_arc(", "draw_circle(", "draw_polyline(", "draw_colored_polygon(", "_draw_dashes("]:
			if body.contains(primitive): safe = false
		_check(safe, record[1] + ": the live path contains no auxiliary geometry drawing calls")
