extends SceneTree

const Motion = preload("res://scripts/melee_motion.gd")
const Action = preload("res://scripts/weapon_action_motion.gd")
const Pose = preload("res://scripts/weapon_pose.gd")
const World = preload("res://scripts/world_view.gd")
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
	for interval: float in [0.52, 0.2, 0.045]:
		var duration: float = Pose.melee_duration(interval)
		_check(duration <= interval and Pose.melee_swing_time(duration) < Pose.melee_impact_time(duration), "A %.3fs attack anticipates, strikes and finishes before its next attack" % interval)
		var before: Dictionary = Motion.sample(Pose.melee_swing_time(duration)*0.5,duration,Vector2.RIGHT)
		var impact: Dictionary = Motion.sample(Pose.melee_impact_time(duration),duration,Vector2.RIGHT)
		var recovery: Dictionary = Motion.sample(duration*0.8,duration,Vector2.RIGHT)
		_check(before.phase=="windup" and impact.phase=="swing" and recovery.phase=="recover", "Windup, fast cut and recovery are actual distinct weapon states")
		_check(absf(float(impact.angle))<0.00001 and bool(impact.impact) and bool(impact.trail), "The blade crosses its target direction at the authoritative damage instant")
		_check(not bool(Motion.sample(duration,duration,Vector2.RIGHT).active), "A completed action returns to the ordinary weapon hold")
	var world := World.new()
	var immutable: bool = true
	var mirrored: bool = true
	var moving: bool = true
	for character: String in ["ranger","vanguard"]:
		for aim_index: int in range(8):
			var direction := Vector2.from_angle(float(aim_index)*TAU/8.0)
			var player: Dictionary = {"id":1,"character":character,"weapon":"arc_blade","pos":Vector2(500,500),"aim":direction,
				"grounded":aim_index%2==0,"vel":Vector2(150,-80),"melee":{"id":aim_index+1,"duration":0.36,"elapsed":0.0,"aim":direction}}
			world._melee_tracks.clear()
			world._combat_clock = 0.0
			var angles: Array[float] = []
			for fraction: float in [0.0,0.22,0.40,0.58,0.85]:
				player.melee.elapsed = fraction*0.36
				var original: PackedByteArray = var_to_bytes(player)
				var draw: Dictionary = world.weapon_draw_pose(player)
				immutable = immutable and original==var_to_bytes(player)
				mirrored = mirrored and Vector2(draw.tip).is_finite() and Vector2(draw.grip).is_finite() and draw.aim.is_equal_approx(direction)
				moving = moving and draw.position==player.pos and draw.grip.distance_to(draw.shoulder)<24.0 and draw.tip.distance_to(draw.grip)>=39.4
				angles.append(float(draw.weapon_angle))
			_check(absf(angles[1]-angles[3])>3.3,"%s direction %d swings the actual blade through a wide cut"%[character,aim_index])
	_check(immutable,"Melee poses never modify movement, snapshots, physical aim or damage")
	_check(mirrored,"All eight aim directions yield finite mirrored grips and blade tips for both characters")
	_check(moving,"Running and airborne origins stay fixed while the hand and full blade move")
	var continuous: bool = true
	for aim_index: int in range(8):
		var direction := Vector2.from_angle(float(aim_index)*TAU/8.0)
		var player: Dictionary = {"id":9,"character":"ranger","weapon":"arc_blade","pos":Vector2(500,500),"aim":direction,"grounded":true,"vel":Vector2.ZERO}
		var ready: Dictionary = world.weapon_draw_pose(player)
		player.melee = {"id":1,"duration":0.36,"elapsed":0.0,"aim":direction}
		var start: Dictionary = world.weapon_draw_pose(player)
		player.melee.elapsed = 0.36-0.0000001
		var ending: Dictionary = world.weapon_draw_pose(player)
		for field: String in ["weapon_origin","shoulder","grip","tip","muzzle"]:
			continuous = continuous and Vector2(ready[field]).distance_to(start[field])<0.001 and Vector2(ready[field]).distance_to(ending[field])<0.001
		continuous = continuous and absf(float(start.weapon_angle)-float(ready.weapon_angle))<0.00001 and absf(float(ending.weapon_angle)-float(ready.weapon_angle))<0.00001
		continuous = continuous and is_equal_approx(float(start.weapon_scale),1.0) and absf(float(ending.weapon_scale)-1.0)<0.00001
		world._melee_tracks.clear()
	_check(continuous,"Both melee endpoints exactly meet the idle shoulder, grip, origin, tip, angle and blade size in all eight directions")
	for weapon: String in Action.WEAPONS:
		var correct_muzzle: bool = true
		var live_aim: bool = true
		for aim_index: int in range(8):
			var aim := Vector2.from_angle(float(aim_index)*TAU/8.0)
			var player: Dictionary = {"id":3,"character":"ranger","weapon":weapon,"pos":Vector2(700,300),"aim":aim,"grounded":true,"vel":Vector2(120,0),
				"attack_pose":{"id":1,"weapon":weapon,"duration":0.3,"elapsed":0.08,"aim":Vector2.RIGHT}}
			world._weapon_tracks.clear()
			var original: PackedByteArray = var_to_bytes(player)
			var physical_muzzle: Vector2 = Pose.muzzle_position(player)
			var draw: Dictionary = world.weapon_draw_pose(player)
			var expected: Vector2 = Vector2(draw.weapon_origin)+Vector2.from_angle(float(draw.weapon_angle))*Pose.muzzle_length(weapon)
			correct_muzzle = correct_muzzle and Vector2(draw.muzzle).is_equal_approx(expected) and Vector2(draw.tip).is_equal_approx(expected)
			live_aim = live_aim and Vector2(draw.aim).is_equal_approx(aim) and physical_muzzle.is_equal_approx(Pose.muzzle_position(player)) and original==var_to_bytes(player)
		_check(correct_muzzle,weapon+": the production world muzzle is the actual recoiling/rotating weapon tip in all eight directions")
		_check(live_aim,weapon+": follow-through aims with the current mouse while physical projectiles and snapshots remain unchanged")
	world.free()
	print("MELEE_POSE_TEST_RESULT passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
