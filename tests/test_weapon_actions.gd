extends SceneTree

const Motion = preload("res://scripts/weapon_action_motion.gd")
const Content = preload("res://scripts/content.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var signatures: Dictionary = {}
	for weapon: String in Motion.WEAPONS:
		var interval: float = Content.definition(weapon).fire_interval
		var duration: float = Motion.duration(weapon, interval)
		var moved: bool = false
		var bounded: bool = true
		var signature: Array = []
		for step: int in range(20):
			var pose: Dictionary = Motion.sample(weapon, duration * step / 20.0, duration)
			moved = moved or Vector2(pose.offset).length() > 1.0
			bounded = bounded and Vector2(pose.offset).is_finite() and Vector2(pose.offset).length() <= 20.0 and absf(float(pose.angle_offset)) < 1.0 and absf(float(pose.body_angle)) < 0.13 and float(pose.weapon_alpha) >= 0.0 and float(pose.weapon_alpha) <= 1.0
			signature.append([pose.offset, pose.angle_offset, pose.phase])
		signatures[var_to_str(signature)] = true
		_check(moved and bounded, weapon + " moves the actual weapon within a bounded, finite body/arm pose")
		var start: Dictionary = Motion.sample(weapon, 0.0, duration)
		var end: Dictionary = Motion.sample(weapon, duration - 0.000001, duration)
		_check(Vector2(start.offset).length() < 0.001 and Vector2(end.offset).length() < 0.001 and absf(float(end.angle_offset)) < 0.001 and not Motion.sample(weapon, duration, duration).active, weapon + " begins at its real firing muzzle and settles smoothly back to its ready pose")
		var fits: bool = true
		for speed_interval: float in [0.045, 0.06, 0.10, interval, 3.0]:
			var length: float = Motion.duration(weapon, speed_interval)
			fits = fits and length > 0.0 and length <= speed_interval
		_check(fits, weapon + " finishes before the next shot even at the maximum firing rate")
	_check(signatures.size() == Motion.WEAPONS.size(), "All nine ranged weapons have different movement trajectories and phases")
	_check(Motion.sample("scattergun", .55, 1.0).phase == "cycle" and Motion.sample("scattergun", .55, 1.0).mechanism > .5, "Shotgun follow-through operates its pump between shots")
	_check(Motion.sample("boomerang", .30, 1.0).weapon_alpha == 0.0 and Motion.sample("boomerang", .30, 1.0).offset.x > 5.0, "Boomerang visibly leaves the forward-reaching hand during the throw")
	_check(Motion.sample("sun_lance", .13, 1.0).offset.x > 10.0 and Motion.sample("railgun", .10, 1.0).offset.x < -10.0, "The lance thrusts forward while the railgun recoils backward")
	_check(Motion.sample("storm_staff", .20, 1.0).angle_offset < -.45, "The storm staff has a distinct raised casting gesture")
	_check(Motion.sample("flamethrower", .20, 1.0).phase == "brace" and absf(float(Motion.sample("flamethrower", .20, 1.0).angle_offset)) < .05, "Sustained flame uses controlled bracing rather than large shot kicks")
	_check(not Motion.sample("unknown", .1, .2).active and not Motion.sample("railgun", NAN, .2).active and not Motion.sample("railgun", .1, INF).active and not Motion.sample("railgun", -.1, .2).active, "Invalid samples return a safe neutral pose")
	_check(Motion.duration("arc_blade", .52) == 0.0, "Blade timing remains owned by its separate damage-aligned melee timeline")
	print("WEAPON_ACTIONS_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)
