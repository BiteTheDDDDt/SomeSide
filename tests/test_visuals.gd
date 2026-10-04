extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
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
	simulation.start_run([{"id": 1, "name": "VFX tester", "character": "ranger"}], 20261004)
	var world = WorldView.new()
	root.add_child(world)
	world.set_process(false)
	var strengths: Array[float] = []
	var tiers: Array[int] = []
	var last_event: Dictionary = {}
	for stacks in [0, 2, 6, 12, 1000]:
		var player: Dictionary = simulation.state.players[1]
		player.items = {"capacitor": stacks}
		player.fire_cd = 0.0
		simulation.state.projectiles.clear()
		simulation.step(1.0 / 60.0, {1: {"fire": true, "aim": Vector2.UP}})
		var shot: Dictionary = {}
		for event in simulation.events:
			if event.type == "shoot":
				shot = event
		_check(not shot.is_empty() and int(shot.get("visual_stacks", -1)) == stacks and not simulation.state.projectiles.is_empty() and int(simulation.state.projectiles[0].get("visual_stacks", -1)) == stacks, "A real %d-stack attack propagates visual metadata to both its event and projectile" % stacks)
		tiers.append(int(shot.get("visual_strength", -1)))
		world.set_frame(simulation.get_snapshot(), 1, 1.0 / 60.0)
		strengths.append(world.effect_strength(shot))
		last_event = shot.duplicate(true)
	_check(strengths[0] < strengths[1] and strengths[1] < strengths[2] and strengths[2] < strengths[3], "The same real attack becomes visually stronger through low, medium and high relic stacks")
	_check(is_equal_approx(strengths[3], strengths[4]) and tiers[4] <= 3, "Extreme relic stacks saturate visual strength rather than growing without a limit")
	var authoritative: Dictionary = simulation.get_snapshot()
	var input_event: Dictionary = last_event.duplicate(true)
	world.fx_scale = 0.5
	var reduced: float = world.effect_strength(last_event)
	world.fx_scale = 1.5
	var increased: float = world.effect_strength(last_event)
	_check(reduced < increased and increased <= 3.3001, "The visual-intensity setting changes presentation within the documented upper bound")
	world.fx_scale = 99.0
	_check(is_equal_approx(world.effect_strength(last_event), increased), "Out-of-range visual intensity cannot exceed the rendering safety cap")
	world.fx_scale = 1.5
	var maximum_effects: int = 0
	var maximum_numbers: int = 0
	for index in range(1200):
		var position: Vector2 = simulation.state.players[1].pos + Vector2(index % 40, -20)
		world.push_events([
			{"type": "hit", "pos": position, "amount": 9999, "crit": true, "arc_from": position - Vector2(90, 0), "visual_stacks": 1000},
			{"type": "explosion", "pos": position, "radius": 10000.0, "visual_stacks": 1000},
			last_event,
		])
		var stats: Dictionary = world.visual_budget_stats()
		maximum_effects = maxi(maximum_effects, int(stats.effects))
		maximum_numbers = maxi(maximum_numbers, int(stats.damage_numbers))
	var budget: Dictionary = world.visual_budget_stats()
	_check(maximum_effects > 0 and maximum_effects <= int(budget.max_effects) and maximum_effects <= 512, "A 3600-event high-stack burst never exceeds the particle/effect budget, even between event batches")
	_check(maximum_numbers > 0 and maximum_numbers <= int(budget.max_damage_numbers) and maximum_numbers <= 64, "The same burst keeps damage numbers bounded")
	_check(float(budget.shake) <= 5.0, "Chained high-stack explosions keep camera shake within five pixels")
	var finite: bool = true
	var radius_bounded: bool = true
	for effect in world.get("_effects"):
		finite = finite and Vector2(effect.pos).is_finite() and is_finite(float(effect.life))
		radius_bounded = radius_bounded and float(effect.get("radius", 0.0)) <= 300.0
	_check(finite and radius_bounded, "Every surviving visual has finite coordinates/lifetime and bounded area")
	world.shake_enabled = false
	world.call("_process", 1.0 / 60.0)
	_check(Vector2(world.get("_shake_offset")) == Vector2.ZERO, "Disabling camera shake removes the actual camera offset during active effects")
	_check(simulation.get_snapshot() == authoritative and last_event == input_event, "Rendering amplified effects cannot mutate authority state or incoming event metadata")
	for tick in range(180):
		world.call("_process", 1.0 / 60.0)
	var settled: Dictionary = world.visual_budget_stats()
	_check(int(settled.effects) == 0 and int(settled.damage_numbers) == 0, "Transient effects and damage numbers expire after the combat burst")
	world.queue_free()
	await process_frame
	print("VISUAL_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)
