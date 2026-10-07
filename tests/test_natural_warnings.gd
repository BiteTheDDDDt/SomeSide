extends SceneTree

const Fixtures = preload("res://tools/capture-attack-phases-v0203.gd")
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
		_test_distinct_attack_phases()
		_test_airborne_spores()
		_test_travel_attacks_unchanged()
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
	var first_samples: int = 0
	var first_signal: bool = true
	var initial_healing: Dictionary = {}
	if attack == "mend":
		for ally: Dictionary in sim.state.enemies:
			if int(ally.id) != int(enemy.id): initial_healing[int(ally.id)] = float(ally.hp)
	for tick: int in range(maxi(210, int(ceil(float(enemy.telegraph_max) / DT)) + 100)):
		var winding: bool = str(enemy.attack_kind) == attack and float(enemy.telegraph) > 0.0
		# Hazard and attacker timers now both retain the creation tick. Use
		# the actual damage body flag, not rounded display seconds, as the
		# authoritative boundary throughout the complete warning window.
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
				var valid: bool = is_finite(alpha) and size.is_finite() and size.x > 0 and size.y > 0
				if str(hazard.shape) == "line":
					valid = valid and float(data.get("source_alpha", 0.0)) >= 0.6
					valid = valid and (bool(data.material_visible) and alpha == 1.0 if bool(hazard.active) else bool(data.warning_visible) and float(data.warning_alpha) >= 0.67 and data.warning_end == Vector2(hazard.pos) + Vector2(hazard.dir) * float(hazard.length))
				else:
					valid = valid and alpha == 1.0
					if not bool(hazard.active):
						valid = valid and bool(data.warning_visible) and float(data.warning_alpha) >= 0.67 and data.warning_radius == hazard.radius
						if str(data.family) == "spore_ready": valid = valid and Vector2(data.size).x >= 36.0 and not Beam.Sprites.frame_data("spore_ready", float(data.phase)).is_empty()
				if tick < 6 and not bool(hazard.active):
					first_samples += 1
					first_signal = first_signal and valid
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
		_check(first_samples >= 18 and first_signal, attack + ": the complete first 100ms warning is visible in normal, low FX, and reduced motion")
		_check(locked, attack + ": authority origin, direction, range and radius stay locked in every material setting")
		_check(warning_material and active_material and slow_samples_valid and active_samples_valid, attack + ": the appropriate source/area signal remains visible at low FX in both phases")
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
	for attack: String in ["beam", "prism_beam", "prism_cross", "mortar", "burrow", "stone_spikes", "spore_bloom"]:
		var setup: Dictionary = Fixtures.fixture(attack, false)
		var sim = setup.sim
		var control = Fixtures.fixture(attack, false).sim
		var enemy: Dictionary = setup.enemy
		var target: Vector2 = enemy.attack_target
		var aim: Vector2 = enemy.attack_dir
		var windup: float = float(enemy.telegraph_max)
		var initial: Dictionary = {}
		for hazard: Dictionary in sim.state.hazards: initial[int(hazard.id)] = hazard.duplicate(true)
		var stable: bool = true
		var active_seen: bool = false
		var active_control: bool = false
		var target_hp: float = float(sim.state.players[1].hp)
		var window: int = int(ceil((windup + 0.8) / DT))
		for tick: int in range(window):
			for hazard: Dictionary in sim.state.hazards:
				if initial.has(int(hazard.id)):
					var locked: Dictionary = initial[int(hazard.id)]
					stable = stable and hazard.pos == locked.pos and hazard.dir == locked.dir
					active_seen = active_seen or bool(hazard.active)
			for hazard: Dictionary in control.state.hazards: active_control = active_control or bool(hazard.active)
			sim.step(DT, {1: Fixtures.dodge_command(attack, tick, windup)})
			control.step(DT, {})
		_check(active_seen and active_control and sim.state.hazards.is_empty() and control.state.hazards.is_empty(), attack + ": dodge audit actually observes the damaging window and continues through expiry")
		_check(stable and enemy.attack_target == target and enemy.attack_dir == aim and sim.state.players[1].hp == target_hp, attack + ": ordinary movement and a single jump can avoid the locked attack after a 300ms reaction delay")
		_check(float(control.state.players[1].hp) < target_hp, attack + ": standing still in the same attack is a positive damage control")

func _test_distinct_attack_phases() -> void:
	for attack: String in ["beam", "prism_beam", "prism_cross", "mortar", "burrow", "stone_spikes", "spore_bloom"]:
		var history: Dictionary = Fixtures.phase_samples(attack)
		var states: Array = []
		for index: int in history.selected: states.append(history.history[index].state)
		var early: Dictionary = states[0].hazards[0]
		var late: Dictionary = states[1].hazards[0]
		var active: Dictionary = states[2].hazards[0]
		_check(not early.active and not late.active and active.active and float(active.ttl) > 0.0, attack + ": photography uses real hazard activation, not an attacker animation timer")
		var valid: bool = true
		var distinct: bool = true
		var aligned: bool = true
		for option: Array in [[1.0, false], [0.0, false], [0.0, true]]:
			var data: Array = []
			for hazard: Dictionary in [early, late, active]:
				var saved: PackedByteArray = var_to_bytes(hazard)
				data.append(Beam.beam_sample(hazard, option[0], option[1]) if str(hazard.shape) == "line" else Natural.area_sample(hazard, option[0], option[1]))
				aligned = aligned and var_to_bytes(hazard) == saved
			if str(early.shape) == "line":
				for ready: Dictionary in [data[0], data[1]]:
					valid = valid and bool(ready.warning_visible) and float(ready.warning_alpha) >= 0.67 and not bool(ready.material_visible)
					valid = valid and ready.warning_origin == early.pos and ready.warning_end == Vector2(early.pos) + Vector2(early.dir) * float(early.length) and ready.warning_radius == early.radius
				distinct = distinct and not bool(data[2].warning_visible) and bool(data[2].material_visible) and data[2].material_family == "laser" and float(data[2].material_alpha) == 1.0
				distinct = distinct and Vector2(data[2].material_size) == Vector2(float(active.length), float(active.radius) * 2.0)
				aligned = aligned and data[0].origin == data[1].origin and data[1].origin == data[2].origin and data[0].end == data[2].end
			else:
				var material: String = "spore" if str(early.kind) in ["spore_mortar", "boss_spore"] else ("stone" if str(early.kind) == "stone_spike" else "earth")
				valid = valid and data[0].family == material + "_ready" and data[1].family == material + "_ready" and data[2].family == material + "_hit"
				valid = valid and float(data[0].phase) < float(data[1].phase) and float(data[2].phase) >= 0 and float(data[2].phase) <= 1
				for ready: Dictionary in [data[0], data[1]]:
					valid = valid and bool(ready.warning_visible) and float(ready.warning_alpha) >= 0.67 and ready.warning_radius == early.radius and float(ready.material_alpha) == 1.0
				if material == "spore":
					for ready: Dictionary in [data[0], data[1]]:
						var seed_size: Vector2 = ready.size
						valid = valid and is_equal_approx(seed_size.x, seed_size.y) and seed_size.x >= 36.0 and seed_size.x <= 44.0
				distinct = distinct and Vector2(data[2].size).y >= Vector2(data[1].size).y * 2.0 and float(data[2].material_alpha) == 1.0 and not bool(data[2].warning_visible)
				for sample: Dictionary in data:
					if material == "spore": aligned = aligned and Vector2(sample.draw_offset) == Vector2.ZERO
					else: aligned = aligned and is_equal_approx(Vector2(sample.draw_offset).y + Vector2(sample.size).y * 0.5, 17.0)
		_check(valid, attack + ": early/late ready signals match the actual attack material and only active selects the hit form")
		_check(distinct, attack + ": the damaging sprite stays distinct from the harmless range cue at every FX setting")
		_check(aligned, attack + ": phase selection preserves immutable origins and the correct ground or airborne anchor")
	for attack: String in ["charge", "stone_charge"]:
		var setup: Dictionary = Fixtures.fixture(attack)
		var enemy: Dictionary = setup.enemy
		var local: Dictionary = Beam.preparation_sample(enemy, Vector2.ZERO, Vector2.RIGHT, 0.82, 17.0)
		_check(Vector2(local.size).x <= 55.0 and Vector2(local.origin).length() < 32.0 and local.family == "earth_ready", attack + ": preparation stays under the body instead of drawing a future charge runway")

func _test_airborne_spores() -> void:
	for attack: String in ["airborne_mortar", "airborne_spore_bloom"]:
		var setup: Dictionary = Fixtures.fixture(attack)
		var sim = setup.sim
		var original: Dictionary = sim.state.hazards[0].duplicate(true)
		var airborne: bool = Vector2(original.pos).y < float(sim.state.floor_y) - 100.0
		var preserved: bool = true
		var active_seen: bool = false
		for tick: int in range(int(ceil((float(original.telegraph_max) + 1.0) / DT))):
			for hazard: Dictionary in sim.state.hazards:
				if int(hazard.id) != int(original.id): continue
				var sample: Dictionary = Natural.area_sample(hazard, 0.0, true)
				preserved = preserved and hazard.pos == original.pos and sample.origin == original.pos and sample.draw_offset == Vector2.ZERO
				preserved = preserved and sample.family == ("spore_hit" if hazard.active else "spore_ready")
				active_seen = active_seen or bool(hazard.active)
			sim.step(DT, {})
		_check(airborne and preserved and active_seen and sim.state.players[1].grounded, attack + ": spores stay at the locked airborne center even after their target lands")

func _test_travel_attacks_unchanged() -> void:
	for record: Array in [["charge", .8, 430.0], ["stone_charge", .9, 370.0], ["pounce", .65, 320.0], ["spit", .75, 270.0], ["triple", .75, 235.0], ["spore_volley", .9, 225.0], ["mend", .85, 210.0]]:
		var attack: String = record[0]
		var setup: Dictionary = Fixtures.fixture(attack)
		var sim = setup.sim
		var enemy: Dictionary = setup.enemy
		_check(is_equal_approx(float(enemy.telegraph_max), float(record[1])), attack + ": travel attacks retain the established windup")
		var released: bool = false
		var unchanged_speed: bool = false
		for tick: int in range(int(ceil((float(enemy.telegraph_max) + .3) / DT))):
			sim.step(DT, {})
			if float(enemy.charge_timer) > 0:
				released = true
				unchanged_speed = is_equal_approx(float(enemy.charge_speed), float(record[2]))
				break
			for shot: Dictionary in sim.state.projectiles:
				if str(shot.team) == "enemy":
					released = true
					unchanged_speed = absf(Vector2(shot.vel).length() - float(record[2])) < .01
			if released: break
		_check(released and unchanged_speed, attack + ": real released charge/projectile retains its established travel speed")
