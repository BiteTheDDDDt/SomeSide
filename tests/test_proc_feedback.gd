extends SceneTree

const Feedback = preload("res://scripts/proc_feedback.gd")
const World = preload("res://scripts/world_view.gd")
const Simulation = preload("res://scripts/simulation.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS: ", label)
	else: failed += 1; push_error("FAIL: " + label)

func _run() -> void:
	var missile: Dictionary = {"kind":"seeker_missile", "team":"player", "vel":Vector2(0,-500), "age":0.17, "ttl":1.43}
	var wave: Dictionary = {"kind":"shock_wave", "team":"player", "vel":Vector2(-420,0), "age":0.43, "ttl":0.02}
	var halo: Dictionary = {"kind":"frost_halo", "radius":120.0, "ttl":0.76, "duration":1.5}
	var shield: Dictionary = {"reactive_shield":10.0, "reactive_shield_timer":2.6}
	var unchanged: PackedByteArray = var_to_bytes([missile,wave,halo,shield])
	var shot_pose: Dictionary = Feedback.projectile_sample(missile)
	_check(shot_pose.family == "missile" and is_equal_approx(shot_pose.angle,-PI/2), "Missile animation faces its actual guided velocity")
	var wave_pose: Dictionary = Feedback.projectile_sample(wave)
	_check(wave_pose.family == "wave" and is_equal_approx(absf(wave_pose.angle), PI) and wave_pose.alpha == 1.0, "Left shock waves retain an opaque damaging body at the end of their lifetime")
	_check(Feedback.field_sample(halo).size == Vector2(240,240), "Halo diameter follows the real authoritative radius")
	_check(Feedback.shield_sample(shield).size == Vector2(68,68), "Temporary armor stays compact around its wearer")
	_check(Feedback.projectile_sample(missile) == shot_pose and Feedback.projectile_sample(wave) == wave_pose, "Repeated paused samples preserve exact sprite phase")
	_check(var_to_bytes([missile,wave,halo,shield]) == unchanged, "Feedback sampling does not mutate replicated combat data")
	missile.ttl = 0.0; wave.ttl = 0.0; halo.ttl = 0.0; shield.reactive_shield = 0.0
	_check(Feedback.projectile_sample(missile).is_empty() and Feedback.projectile_sample(wave).is_empty() and Feedback.field_sample(halo).is_empty() and Feedback.shield_sample(shield).is_empty(), "Expired projectiles, aura and consumed shield leave no persistent art")
	shield.reactive_shield = 10.0; shield.dead = true
	_check(Feedback.shield_sample(shield).is_empty(), "Dead actors cannot display reactive armor")
	missile.ttl = 1.0; missile.team = "enemy"
	_check(Feedback.projectile_sample(missile).is_empty(), "Friendly effects never accidentally render hostile shots")
	halo.ttl = 1.0; halo.radius = 999999.0
	_check(Feedback.field_sample(halo).size == Vector2(260,260), "Malformed radius cannot create unbounded aura geometry")
	for source: String in Feedback.SOURCES:
		var event: Dictionary = {"type":"proc", "kind":source, "pos":Vector2(120,230)}
		var original: PackedByteArray = var_to_bytes(event)
		var fx: Dictionary = Feedback.activation(event)
		_check(fx.pos == event.pos and fx.life <= 0.3 and Feedback.activation_sample(fx).family == "charge", source + " gets a bounded sprite activation at its event origin")
		fx.age = fx.life
		_check(Feedback.activation_sample(fx).is_empty() and var_to_bytes(event) == original, source + " activation expires without changing network events")
	_check(Feedback.activation({"type":"shoot","kind":"missile_pod"}).is_empty(), "Unrelated events cannot replay proc activations")
	var sim = Simulation.new()
	sim.start_run([{"id":1,"name":"Visual probe","character":"ranger"}],200021)
	var world = World.new()
	root.add_child(world)
	world.set_process(false)
	world.fx_scale = 0.0
	world.reduced_motion = true
	world.set_frame(sim.get_snapshot(),1,0.0)
	var event: Dictionary = {"type":"proc", "kind":"missile_pod", "pos":sim.state.players[1].pos}
	world.push_events([event])
	_check(world._effects.any(func(fx: Dictionary) -> bool: return fx.kind == "proc_activation"), "Real world event routing keeps the new sprite activation at reduced FX")
	for n: int in range(450): world.push_events([event])
	_check(world._effects.size() <= World.MAX_EFFECTS, "A proc event burst obeys the existing global effect cap")
	world.free()
	print("PROC_FEEDBACK_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed == 0 else 1)
