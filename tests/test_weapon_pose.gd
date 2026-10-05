extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const WeaponPose = preload("res://scripts/weapon_pose.gd")
const DT: float = 1.0 / 60.0
const WEAPONS: Array[String] = ["pulse_rifle", "scattergun", "railgun", "flamethrower", "boomerang", "storm_staff", "sun_lance", "arc_blade"]
const LENGTHS: Array[float] = [36.0, 38.0, 52.0, 46.0, 36.0, 48.0, 58.0, 47.0]
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_test_aim_safety()
	_test_actual_firing()
	_test_point_blank()
	_test_swap_and_snapshot()
	_test_collision_order()
	_test_command_path()
	print("WEAPON_POSE_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _fresh():
	var simulation = Simulation.new()
	simulation.start_run([{"id": 1, "name": "Weapon pose", "character": "ranger"}], 20261005)
	simulation.state.players[1].pos = Vector2(2000.0, 600.0)
	simulation.state.players[1].vel = Vector2.ZERO
	simulation.state.enemies.clear()
	simulation.state.projectiles.clear()
	simulation.state.platforms.clear()
	simulation.events.clear()
	return simulation

func _dummy(simulation, position: Vector2) -> Dictionary:
	var enemy: Dictionary = simulation._spawn_enemy("crawler", position)
	enemy.hp = 100000.0
	enemy.max_hp = 100000.0
	return enemy

func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.001

func _shot_event(simulation) -> Dictionary:
	for event_value in simulation.events:
		var event: Dictionary = event_value
		if str(event.get("type", "")) in ["shoot", "slash"] and event.has("weapon"):
			return event
	return {}

func _test_aim_safety() -> void:
	var simulation = _fresh()
	var player: Dictionary = simulation.state.players[1]
	player.aim = Vector2.UP
	var shoulder: Vector2 = WeaponPose.shoulder_position(player.pos)
	_check(_near(shoulder, Vector2(player.pos) + Vector2(0, -5)), "The shoulder is fixed five pixels above the actual player center")
	_check(WeaponPose.normalized_aim(Vector2.ZERO) == Vector2.RIGHT and WeaponPose.normalized_aim(Vector2(NAN, 0)) == Vector2.RIGHT and WeaponPose.normalized_aim(Vector2(INF, 0)) == Vector2.RIGHT, "Zero and non-finite aim safely normalize to the right")
	var large_aim: Vector2 = WeaponPose.normalized_aim(Vector2(1.0e30, -1.0e30))
	_check(large_aim.is_finite() and is_equal_approx(large_aim.length(), 1.0), "Huge finite aim vectors normalize without overflowing")
	_check(WeaponPose.aim_at(player, shoulder) == Vector2.UP and WeaponPose.aim_at(player, shoulder + Vector2(3, 0)) == Vector2.UP and WeaponPose.aim_at(player, Vector2(NAN, 0)) == Vector2.UP, "Cursor positions at or within four pixels of the shoulder retain the current aim")
	_check(WeaponPose.aim_at(player, shoulder + Vector2(20, 0)) == Vector2.RIGHT, "A nearby target inside the barrel still aims from the shoulder without inverting direction")
	_check(_near(WeaponPose.muzzle_position(player, Vector2.LEFT), shoulder + Vector2.LEFT * 36), "A preview aim override controls the shared muzzle without changing stored aim")
	_check(player.aim == Vector2.UP, "Shared pose and cursor helpers never mutate the player")

func _test_actual_firing() -> void:
	for index in range(WEAPONS.size()):
		var weapon: String = WEAPONS[index]
		var pose_ok: bool = true
		var trajectory_ok: bool = true
		var cadence_ok: bool = true
		for direction_index in range(8):
			var simulation = _fresh()
			var player: Dictionary = simulation.state.players[1]
			player.weapon = weapon
			player.aim = Vector2.RIGHT.rotated(direction_index * PI / 4.0)
			var shoulder: Vector2 = WeaponPose.shoulder_position(player.pos)
			var muzzle: Vector2 = shoulder + Vector2(player.aim) * LENGTHS[index]
			simulation._fire_weapon(player)
			var event: Dictionary = _shot_event(simulation)
			pose_ok = pose_ok and not event.is_empty() and str(event.get("weapon", "")) == weapon and _near(event.get("pos", Vector2.ZERO), muzzle)
			cadence_ok = cadence_ok and is_equal_approx(float(player.fire_cd), float(Simulation.loot_definition(weapon).fire_interval))
			if weapon in ["arc_blade", "flamethrower"]:
				pose_ok = pose_ok and simulation.state.projectiles.is_empty() and str(event.get("type", "")) == "slash"
				continue
			pose_ok = pose_ok and simulation.state.projectiles.size() == (6 if weapon == "scattergun" else 1)
			for projectile in simulation.state.projectiles:
				pose_ok = pose_ok and _near(projectile.pos, muzzle) and _near(projectile.origin, muzzle) and _near(projectile.sweep_origin, shoulder) and float(projectile.travel_distance) == 0.0
			simulation._step_projectiles(DT)
			for projectile in simulation.state.projectiles:
				var expected_position: Vector2 = muzzle + Vector2(projectile.vel) * DT
				var trail_length: float = minf(54.0, float(projectile.travel_distance))
				var trail_end: Vector2 = Vector2(projectile.pos) - Vector2(projectile.vel).normalized() * trail_length
				trajectory_ok = trajectory_ok and _near(projectile.pos, expected_position) and _near(projectile.origin, muzzle) and not projectile.has("sweep_origin")
				trajectory_ok = trajectory_ok and absf(float(projectile.travel_distance) - Vector2(projectile.vel).length() * DT) < 0.001 and (trail_end - muzzle).dot(Vector2(projectile.vel).normalized()) > -0.001
		_check(pose_ok, weapon + ": actual attacks in eight directions share one exact event/projectile muzzle")
		_check(trajectory_ok, weapon + ": first-step flight and visible tail begin at the muzzle, with no repeated shoulder sweep")
		_check(cadence_ok, weapon + ": the muzzle correction preserves its catalog fire interval")

func _test_point_blank() -> void:
	for weapon in WEAPONS:
		var all_hit: bool = true
		for direction_index in range(8):
			var simulation = _fresh()
			var player: Dictionary = simulation.state.players[1]
			player.weapon = weapon
			player.aim = Vector2.RIGHT.rotated(direction_index * PI / 4.0)
			var shoulder: Vector2 = WeaponPose.shoulder_position(player.pos)
			var enemy: Dictionary = _dummy(simulation, shoulder + Vector2(player.aim) * 22.0)
			simulation._fire_weapon(player)
			if weapon == "arc_blade":
				# The blade now has a real anticipation interval before its one strike.
				simulation._step_melee(player, WeaponPose.melee_impact_time(float(player.melee.duration)))
			simulation._step_projectiles(DT)
			all_hit = all_hit and float(enemy.hp) < 100000.0
		_check(all_hit, weapon + ": an enemy between shoulder and muzzle is still damaged in all eight directions")
	var flames = _fresh()
	flames.state.players[1].weapon = "flamethrower"
	var behind: Dictionary = _dummy(flames, Vector2(flames.state.players[1].pos) - Vector2(70, 0))
	flames._fire_weapon(flames.state.players[1])
	_check(float(behind.hp) == 100000.0, "Moving the flamethrower visual origin does not extend its damage cone behind the wielder")

func _test_swap_and_snapshot() -> void:
	var simulation = _fresh()
	var player: Dictionary = simulation.state.players[1]
	simulation._fire_weapon(player)
	var first_origin: Vector2 = simulation.state.projectiles[0].origin
	var before_cooldown: float = float(player.fire_cd)
	var pickup: Dictionary = simulation._spawn_pickup(player.pos, "item", "sun_lance", 1)
	simulation._take_loot(player, pickup)
	_check(str(player.weapon) == "sun_lance" and is_equal_approx(float(player.fire_cd), before_cooldown), "Actually swapping the ground weapon preserves its active cooldown")
	simulation._fire_weapon(player)
	var last_event: Dictionary = simulation.events.back()
	var switched_muzzle: Vector2 = WeaponPose.muzzle_position(player)
	_check(_near(last_event.pos, switched_muzzle) and _near(simulation.state.projectiles.back().origin, switched_muzzle) and first_origin.distance_to(switched_muzzle) > 20.0, "A real weapon swap immediately uses the longer barrel for new shots")
	_check(_near(simulation.state.projectiles[0].origin, first_origin), "Shots already in flight retain the original muzzle after a weapon swap")
	var clone = Simulation.new()
	clone.apply_snapshot(simulation.get_snapshot())
	clone._step_projectiles(DT)
	_check(clone.state.projectiles[0].has("origin") and float(clone.state.projectiles[0].travel_distance) > 0.0 and float(simulation.state.projectiles[0].travel_distance) == 0.0, "New projectile origins and transient sweep state round-trip through an independent network snapshot")

func _test_collision_order() -> void:
	var simulation = _fresh()
	var player: Dictionary = simulation.state.players[1]
	var shoulder: Vector2 = WeaponPose.shoulder_position(player.pos)
	var far_enemy: Dictionary = _dummy(simulation, shoulder + Vector2(90, 0))
	var near_enemy: Dictionary = _dummy(simulation, shoulder + Vector2(22, 0))
	simulation._fire_weapon(player)
	simulation._step_projectiles(0.05)
	_check(float(near_enemy.hp) < 100000.0 and float(far_enemy.hp) == 100000.0 and simulation.state.projectiles.is_empty(), "The hidden first barrel sweep resolves before farther flight collisions regardless of enemy array order")
	var repeated = _fresh()
	var owner: Dictionary = repeated.state.players[1]
	owner.weapon = "railgun"
	var close_enemy: Dictionary = _dummy(repeated, WeaponPose.shoulder_position(owner.pos) + Vector2(25, 0))
	repeated._fire_weapon(owner)
	repeated._step_projectiles(DT)
	var health_after_first: float = float(close_enemy.hp)
	for tick in range(5): repeated._step_projectiles(DT)
	_check(float(close_enemy.hp) == health_after_first and health_after_first < 100000.0, "A piercing projectile cannot repeatedly damage a close target through its first-frame barrel sweep")
	var active = _fresh()
	active._use_skill(active.state.players[1])
	_check(not active.events.back().has("weapon") and not active.state.projectiles.back().has("sweep_origin"), "Grenade active equipment retains its own origin and never masquerades as a main weapon flash")

func _test_command_path() -> void:
	var simulation = _fresh()
	var player: Dictionary = simulation.state.players[1]
	var target: Vector2 = Vector2(player.pos) + Vector2(-150, -120)
	var command_aim: Vector2 = WeaponPose.aim_at(player, target)
	simulation.step(DT, {1: {"aim": command_aim, "fire": true}})
	var muzzle: Vector2 = WeaponPose.muzzle_position(player)
	var event: Dictionary = _shot_event(simulation)
	_check(not event.is_empty() and _near(event.pos, muzzle) and _near(simulation.state.projectiles[0].origin, muzzle), "The real movement/input/attack step uses the post-movement shared muzzle for both event and projectile")
	var invalid = _fresh()
	invalid.state.players[1].aim = Vector2(NAN, INF)
	invalid._fire_weapon(invalid.state.players[1])
	_check(Vector2(invalid.events.back().pos).is_finite() and Vector2(invalid.state.projectiles[0].pos).is_finite() and Vector2(invalid.state.projectiles[0].vel).is_finite(), "An invalid stored aim cannot create non-finite events or projectiles")
