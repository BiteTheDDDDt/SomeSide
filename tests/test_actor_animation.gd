extends SceneTree

const Pixels = preload("res://scripts/pixel_actor_renderer.gd")
const World = preload("res://scripts/world_view.gd")
const Pose = preload("res://scripts/weapon_pose.gd")
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

func _record() -> Dictionary:
	var frames: Array = []
	for index: int in range(16):
		frames.append({"rect": [index, 0, 1, 1], "anchor": [0, 0], "duration": 0.1})
	frames[11]["shoulder"] = [3, 7]
	frames[12]["shoulder"] = [1, 0]
	return {"texture": "fixture", "movement_speed": 200.0, "frames": frames,
		"animations": {"idle": [0, 1], "run": [2, 3, 4, 5], "move": [2, 3, 4, 5], "rise": [6, 7], "fall": [8, 9], "dash": [10], "land": [11, 12], "windup": [13, 14], "attack": [14, 15]}}

func _player(id: int = 1) -> Dictionary:
	return {"id": id, "character": "ranger", "grounded": true, "vel": Vector2.ZERO, "pos": Vector2(100, 200), "attack_count": 0}

func _run() -> void:
	var image := Image.create(16, 1, false, Image.FORMAT_RGBA8)
	for index: int in range(16):
		image.set_pixel(index, 0, Color.from_hsv(float(index) / 16.0, 1.0, 1.0))
	var manifest: Dictionary = {"version": 1, "actors": {"ranger": _record(), "crawler": _record()}}
	var source_bytes: PackedByteArray = var_to_bytes(manifest)
	Pixels.install_manifest(manifest, {"fixture": ImageTexture.create_from_image(image)})
	var canvas := Node2D.new()
	var other_canvas := Node2D.new()
	var player: Dictionary = _player()
	var state_bytes: PackedByteArray = var_to_bytes(player)
	var first: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 100.175, true)
	_check(first.index == 0 and first.animation == "idle", "A new actor enters the first idle pose regardless of global clock")
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 100.285, true).index == 1, "Idle advances its own authored frame durations")
	_check(var_to_bytes(player) == state_bytes and var_to_bytes(manifest) == source_bytes, "Animation tracking changes neither the snapshot nor source manifest")
	_check(Pixels.tracked_frame_for(other_canvas, "ranger", player, 100.285, true).index == 0, "Separate worlds and previews cannot share actor clock history")
	player.vel = Vector2(200, 0)
	var running: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 100.3, true)
	_check(running.index == 2 and is_zero_approx(running.elapsed), "Entering run starts the first stride instead of an arbitrary world-clock pose")
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 100.41, true).index == 3, "Running advances at the authored reference movement speed")
	player.vel = Vector2(100, 0)
	var slowing: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 100.41, true)
	var slow: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 100.57, true)
	_check(is_equal_approx(slow.elapsed - slowing.elapsed, 0.08) and slow.index == 3, "Half speed adds half a cycle step without rewinding an existing stride")
	var repeat: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 100.57, true)
	_check(repeat.index == slow.index and repeat.elapsed == slow.elapsed, "Drawing an actor twice at the same clock is idempotent")
	player.vel = Vector2(-100, 0)
	var reverse: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 100.63, true)
	_check(reverse.elapsed > repeat.elapsed and reverse.index == 4, "Changing facing preserves the current running cycle")
	player.vel = Vector2.ZERO
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 100.65, true).index == 0, "Stopping switches immediately to the first idle frame")
	_check(Pixels.tracked_frame_for(canvas, "ranger", _player(2), 100.65, true).index == 0, "Two players with the same character retain independent timelines")
	player.grounded = false
	player.vel = Vector2(100, -80)
	var rise: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 100.7, true)
	_check(rise.animation == "rise" and rise.index == 6 and not rise.loop, "Jump ascent starts its own one-shot pose")
	Pixels.tracked_frame_for(canvas, "ranger", player, 100.95, true)
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 101.2, true).index == 7, "A long ascent holds its final pose instead of repeatedly tucking the legs")
	player.vel = Vector2(100, 80)
	var fall: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 101.21, true)
	_check(fall.animation == "fall" and fall.index == 8, "The apex starts the first falling pose independently from ascent")
	player.grounded = true
	player.vel = Vector2(100, 0)
	var land: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 101.24, true)
	_check(land.animation == "land" and land.index == 11, "A real airborne-to-grounded transition plays the landing pose")
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 101.35, true).index == 12, "Landing recovery advances while physical movement remains untouched")
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 101.45, true).animation == "run", "Landing returns to current movement after its authored duration")
	Pixels.reset_tracks(canvas)
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 101.46, true).animation == "run", "Spawning already grounded never triggers a false landing")
	player.grounded = false
	player.vel = Vector2(100, 100)
	Pixels.tracked_frame_for(canvas, "ranger", player, 101.5, true)
	player.grounded = true
	player.vel = Vector2.ZERO
	Pixels.tracked_frame_for(canvas, "ranger", player, 101.51, true)
	player.grounded = false
	player.vel = Vector2(100, -100)
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 101.52, true).animation == "rise", "Jumping again immediately interrupts landing recovery")
	player.dash_timer = 0.1
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 101.53, true).animation == "dash", "Dashing interrupts airborne and landing animations immediately")
	player.dash_timer = 0.0
	player.grounded = true
	player.vel = Vector2.ZERO
	Pixels.reset_tracks(canvas)
	Pixels.tracked_frame_for(canvas, "ranger", player, 102.0, true)
	player.attack_count = 1
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 102.01, true).animation == "attack", "An available standing attack sequence starts only on an actual shot")
	player.vel = Vector2(200, 0)
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 102.02, true).animation == "run", "Movement immediately interrupts a standing attack pose")
	player.vel = Vector2.ZERO
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 102.03, true).animation == "idle", "An old shot cannot restart attack animation when movement stops")
	var enemy: Dictionary = {"id": 4, "kind": "crawler", "vel": Vector2.ZERO, "telegraph": 0.8, "telegraph_max": 0.8}
	var enemy_before: PackedByteArray = var_to_bytes(enemy)
	_check(Pixels.tracked_frame_for(canvas, "crawler", enemy, 103.0).index == 13, "Enemy anticipation begins at its warning's actual start")
	enemy.telegraph = 0.3
	_check(Pixels.tracked_frame_for(other_canvas, "crawler", enemy, 300.0).index == 14, "A late-visible or remote enemy uses warning progress rather than local render history")
	enemy.telegraph = 0.8
	_check(var_to_bytes(enemy) == enemy_before, "Warning sampling does not consume or modify the replicated telegraph")
	enemy.telegraph = 0.0
	enemy.attack_kind = "charge"
	enemy.attack_cooldown = 3.0
	enemy.attack_cd = 3.0
	_check(Pixels.tracked_frame_for(canvas, "crawler", enemy, 104.0).index == 14, "Enemy release starts from the first attack frame")
	enemy.attack_cd = 2.88
	_check(Pixels.tracked_frame_for(other_canvas, "crawler", enemy, 400.0).index == 15, "Remote attack frames are determined by replicated cooldown elapsed time")
	enemy.attack_cd = 2.4
	enemy.charge_timer = 0.1
	_check(Pixels.tracked_frame_for(canvas, "crawler", enemy, 104.4).index == 15, "A longer charge holds the final attack pose without looping the release")
	player.vel = Vector2(200, 0)
	Pixels.reset_tracks(canvas)
	Pixels.tracked_frame_for(canvas, "ranger", player, 110.0, true)
	Pixels.tracked_frame_for(canvas, "ranger", player, 110.15, true)
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 2.0, true).index == 2, "Clock rollback starts a fresh action timeline")
	Pixels.tracked_frame_for(canvas, "ranger", player, 2.15, true)
	player.pos += Vector2(500, 0)
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 2.16, true).index == 2, "Stage teleports do not reuse the previous stride phase")
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 5.0, true).index == 2, "Returning after a long hidden gap starts cleanly instead of fast-forwarding")
	Pixels.tracked_frame_for(canvas, "ranger", player, 5.15, true)
	Pixels.reset_tracks(canvas)
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 5.16, true).index == 2, "Explicit world resets clear actor history even when IDs and positions are reused")
	var rates: Array[float] = []
	for rate: int in [30, 60, 120, 165]:
		Pixels.reset_tracks(canvas)
		var frame: Dictionary
		for tick: int in range(rate + 1):
			frame = Pixels.tracked_frame_for(canvas, "ranger", player, float(tick) / rate, true)
		rates.append(frame.elapsed)
	_check(rates.all(func(value: float) -> bool: return absf(value - 1.0) < 0.00001), "Stride cadence measures elapsed time consistently at 30, 60, 120 and 165 FPS")
	Pixels.reset_tracks(canvas)
	for index: int in range(Pixels.MAX_TRACKS + 20):
		Pixels.tracked_frame_for(canvas, "ranger", _player(index), 1.0, true)
	_check(canvas.get_meta(Pixels.TRACK_META).tracks.size() == Pixels.MAX_TRACKS, "Presentation history remains explicitly bounded across many actor identities")
	Pixels.tracked_frame_for(canvas, "ranger", _player(9999), 4.0, true)
	_check(canvas.get_meta(Pixels.TRACK_META).tracks.size() == 1, "Departed actors are pruned instead of retained for an entire run")
	Pixels.install_manifest(manifest, {"fixture": ImageTexture.create_from_image(image)})
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 4.1, true).index == 2, "Reloaded assets invalidate old per-canvas animation tracks")
	var world := World.new()
	world._frame = {"stage": 1, "time": 10.0}
	world._update_render_positions(0.0)
	Pixels.tracked_frame_for(world, "ranger", player, 10.0, true)
	Pixels.tracked_frame_for(world, "ranger", player, 10.15, true)
	world._frame = {"stage": 2, "time": 10.2}
	world._update_render_positions(0.0)
	_check(Pixels.tracked_frame_for(world, "ranger", player, 10.2, true).index == 2, "The real world stage-change path resets animation even at the same position and ID")
	Pixels.tracked_frame_for(world, "ranger", player, 10.35, true)
	world._frame = {"stage": 2, "time": 0.0}
	world._update_render_positions(0.0)
	_check(Pixels.tracked_frame_for(world, "ranger", player, 10.4, true).index == 2, "The real world run-restart path resets animation even when presentation time stays monotonic")
	world.free()
	_check_landing_weapon()
	_check_distance_stride(image)
	_check_dedicated_retreat(image)
	canvas.free()
	other_canvas.free()
	Pixels.reload_manifest()
	for id: String in ["ranger", "vanguard"]:
		var actor: Dictionary = Pixels._actors[id]
		_check(float(actor.stride_distance) >= 48.0 and float(actor.stride_distance) <= 72.0, "%s authored two-step gait is calibrated to its foot sweep instead of the former 127px slide" % id)
		_check(actor.animations.get("backpedal", []).size() == 8 and actor.animations.run.size() == 8 and not actor.animations.run.any(func(index: Variant) -> bool: return index in actor.animations.backpedal), "%s forward and retreat use sixteen distinct authored poses" % id)
	print("ACTOR_ANIMATION_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check_dedicated_retreat(image: Image) -> void:
	var record: Dictionary = _record()
	record.stride_distance = 80.0
	record.stride_distances = {"backpedal":40.0}
	record.animations.backpedal = [6,7,8,9]
	for index: int in [6,7,8,9]:
		record.frames[index]["texture"] = "retreat_fixture"
		record.frames[index]["scale"] = 0.5
	var alternate := Image.create(16,1,false,Image.FORMAT_RGBA8)
	alternate.fill(Color(0.2,0.5,0.7,1))
	Pixels.install_manifest({"version":1,"actors":{"ranger":record}}, {"fixture":ImageTexture.create_from_image(image),"retreat_fixture":ImageTexture.create_from_image(alternate)})
	_check(Pixels.stats().errors.is_empty() and Pixels.stats().textures == 2 and Pixels._actors.ranger.frames[6].source_path == "retreat_fixture", "Per-frame source sheets and scales load into the same bounded actor atlas")
	_check(Pixels._actors.ranger.frames[6].draw_target == Pixels._actors.ranger.frames[2].draw_target, "Supplemental retreat sheets keep a common integer body canvas")
	var canvas := Node2D.new()
	var player: Dictionary = _player()
	player.aim = Vector2.RIGHT
	player.vel = Vector2(200,0)
	Pixels.tracked_frame_for(canvas,"ranger",player,0.0,true)
	player.pos.x += 20.0
	var forward: Dictionary = Pixels.tracked_frame_for(canvas,"ranger",player,0.1,true)
	player.vel.x = -200.0
	var retreat: Dictionary = Pixels.tracked_frame_for(canvas,"ranger",player,0.1,true)
	_check(forward.index == 3 and retreat.index == 7 and is_equal_approx(forward.elapsed,retreat.elapsed), "Changing travel direction selects the dedicated retreat while preserving planted-leg phase")
	player.pos.x -= 10.0
	retreat = Pixels.tracked_frame_for(canvas,"ranger",player,0.15,true)
	_check(retreat.index == 8 and is_equal_approx(retreat.elapsed,0.2), "Retreat advances its authored order by the shorter step distance, rather than reversing the forward clip")
	var before: PackedByteArray = var_to_bytes(player)
	var repeated: Dictionary = Pixels.tracked_frame_for(canvas,"ranger",player,0.15,true)
	_check(repeated.index == retreat.index and repeated.elapsed == retreat.elapsed and before == var_to_bytes(player), "Body and weapon reads cannot double-step retreat or mutate the player")
	player.aim = Vector2.LEFT
	var turned: Dictionary = Pixels.tracked_frame_for(canvas,"ranger",player,0.15,true)
	_check(turned.animation == "run" and turned.index == 4, "Aiming toward travel restores forward gait at the same foot-contact phase")
	player.aim = Vector2.RIGHT
	player.grounded = false
	player.vel.y = -100.0
	_check(Pixels.tracked_frame_for(canvas,"ranger",player,0.2,true).animation == "rise", "A backwards run-jump uses the authored airborne pose instead of moving feet on an invisible floor")
	var phases: Array[float] = []
	for rate: int in [30,60,120,165]:
		Pixels.reset_tracks(canvas)
		player.grounded = true
		player.vel = Vector2(-40,0)
		for tick: int in range(rate + 1):
			player.pos = Vector2(100.0 - 40.0 * float(tick) / rate,200)
			retreat = Pixels.tracked_frame_for(canvas,"ranger",player,float(tick)/rate,true)
		phases.append(retreat.elapsed)
	_check(phases.all(func(value: float) -> bool: return absf(value - 0.4) < 0.00001), "Independent retreat foot contacts cover one forty-pixel stride at 30, 60, 120 and 165 FPS")
	canvas.free()

func _check_distance_stride(image: Image) -> void:
	var record: Dictionary = _record()
	record.stride_distance = 80.0
	Pixels.install_manifest({"version": 1, "actors": {"ranger": record}}, {"fixture": ImageTexture.create_from_image(image)})
	var canvas := Node2D.new()
	var player: Dictionary = _player()
	player.vel = Vector2(200, 0)
	player.aim = Vector2.RIGHT
	Pixels.tracked_frame_for(canvas, "ranger", player, 0.0, true)
	player.pos.x += 22.0
	var step: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 0.11, true)
	_check(step.index == 3 and is_equal_approx(step.elapsed, 0.11), "A forward quarter-stride follows actual horizontal distance")
	var frozen: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 0.3, true)
	_check(frozen.index == step.index and frozen.elapsed == step.elapsed, "No displacement means no foot movement even if the snapshot still reports velocity")
	player.vel.x = -200.0
	player.pos.x -= 12.0
	var reverse: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 0.36, true)
	_check(reverse.index == 2 and is_equal_approx(reverse.elapsed, 0.05), "Backpedalling reverses the foot-contact sequence instead of moonwalking forward")
	player.aim = Vector2.LEFT
	var turned: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 0.36, true)
	_check(turned.index == reverse.index and turned.elapsed == reverse.elapsed, "Mouse-facing changes alone do not advance or restart the current stride")
	player.pos.x -= 12.0
	var left: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 0.42, true)
	_check(left.index == 3 and is_equal_approx(left.elapsed, 0.11), "Moving left while aiming left uses the mirrored forward gait")
	player.pos.x += 24.0
	player.vel.x = 400.0
	var right_backward: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 0.48, true)
	_check(is_equal_approx(right_backward.elapsed, -0.01) and right_backward.index == 5, "Moving right while aiming left wraps the reverse gait correctly")
	var before: PackedByteArray = var_to_bytes(player)
	var repeated: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 0.48, true)
	_check(repeated.elapsed == right_backward.elapsed and var_to_bytes(player) == before, "Repeated body/weapon sampling is idempotent and leaves physical state untouched")
	Pixels.reset_tracks(canvas)
	player.aim = Vector2.RIGHT
	player.vel.x = 800.0
	Pixels.tracked_frame_for(canvas, "ranger", player, 1.0, true)
	player.pos.x += 64.0
	var haste: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 1.08, true)
	_check(is_equal_approx(haste.elapsed, 0.32), "High haste follows the complete travelled stride without the previous 2x cadence ceiling")
	player.pos.x += 10.0
	var early_muzzle: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 1.08, true)
	var after_clock: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 1.10, true)
	_check(early_muzzle.elapsed == haste.elapsed and is_equal_approx(after_clock.elapsed, haste.elapsed + 0.05), "A muzzle query before the world clock advances cannot consume the next frame's foot travel")
	var phases: Array[float] = []
	for rate: int in [30, 60, 120, 165]:
		Pixels.reset_tracks(canvas)
		player.pos.x = 100.0
		var frame: Dictionary
		for tick: int in range(rate + 1):
			# Accelerating travel uses the same analytical path at every render rate.
			var t: float = float(tick) / rate
			player.pos.x = 100.0 + 160.0 * t * t
			player.vel.x = maxf(16.0, 320.0 * t)
			frame = Pixels.tracked_frame_for(canvas, "ranger", player, t, true)
		phases.append(float(frame.elapsed))
	_check(phases.all(func(value: float) -> bool: return absf(value - 0.8) < 0.00001), "Actual accelerating travel produces the same stride at 30, 60, 120 and 165 FPS")
	player.vel = Vector2.ZERO
	_check(Pixels.tracked_frame_for(canvas, "ranger", player, 1.01, true).animation == "idle", "Stopping immediately exits the distance-driven run cycle")
	var world := World.new()
	player.vel = Vector2(200, 0)
	player.pos = Vector2(100, 200)
	world._render_positions["p1"] = Vector2(90, 200)
	world._clock = 2.0
	world.weapon_draw_pose(player)
	player.pos.x += 20.0
	world._render_positions["p1"] = Vector2(97, 200)
	world._clock = 2.1
	var immutable: PackedByteArray = var_to_bytes(player)
	var pose: Dictionary = world.weapon_draw_pose(player)
	var tracked: Dictionary = world.get_meta(Pixels.TRACK_META).tracks["p:1:ranger"]
	_check(tracked.pos == Vector2(97, 200) and is_equal_approx(tracked.elapsed, 0.035), "The production weapon path advances gait by seven rendered pixels rather than twenty snapshot pixels")
	var displayed: Dictionary = player.duplicate(false)
	displayed.pos = pose.position
	var body: Dictionary = Pixels.tracked_frame_for(world, "ranger", displayed, world._clock, true)
	_check(is_equal_approx(body.elapsed, tracked.elapsed) and var_to_bytes(player) == immutable, "The body reuses the displayed weapon sample while the authoritative snapshot stays unchanged")
	world.free()
	Pixels.reset_tracks(canvas)
	player.grounded = false
	player.vel = Vector2(245, 100)
	Pixels.tracked_frame_for(canvas, "ranger", player, 3.0, true)
	player.grounded = true
	player.vel.y = 0.0
	var land: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 3.01, true)
	player.pos.x += 5.0
	var leaving_contact: Dictionary = Pixels.tracked_frame_for(canvas, "ranger", player, 3.03, true)
	_check(land.animation == "land" and leaving_contact.animation == "run", "Running out of a landing resumes footwork after four pixels instead of sliding through a stationary crouch")
	canvas.free()

func _check_landing_weapon() -> void:
	var world := World.new()
	var player: Dictionary = _player()
	player.weapon = "pulse_rifle"
	player.aim = Vector2.RIGHT
	var snapshot: Dictionary = {"stage": 1, "time": 1.0, "players": {1: player}, "enemies": [], "projectiles": []}
	world._frame = snapshot
	world._update_render_positions(0.0)
	world._clock = 10.0
	var normal: Dictionary = world.weapon_draw_pose(player)
	_check(normal.shoulder == Pose.shoulder_position(player.pos) and normal.muzzle == Pose.muzzle_position(player), "Ordinary frames retain the original displayed weapon shoulder and muzzle")
	player.grounded = false
	player.vel = Vector2(0, 100)
	world._clock = 10.01
	world.weapon_draw_pose(player)
	player.grounded = true
	player.vel = Vector2.ZERO
	world._clock = 10.02
	world.weapon_draw_pose(player)
	world._clock=10.06
	var landing: Dictionary = world.weapon_draw_pose(player)
	var body: Dictionary = Pixels.tracked_frame_for(world, "ranger", player, world._clock, true)
	_check(body.animation == "land" and float(landing.body.landing)>0 and landing.shoulder.is_equal_approx(Vector2(player.pos) + Vector2(landing.body.shoulder)), "Landing weapon follows the selected frame's lowered logical-pixel shoulder")
	_check(landing.body.phase=="compress" and landing.position == normal.position, "Weapon and body reuse the same animation frame without moving the body origin")
	var stable: bool = true
	var origins: bool = true
	var tails: bool = true
	var immutable: bool = true
	var effects: bool = true
	for direction: int in range(8):
		var aim := Vector2.from_angle(direction * TAU / 8.0)
		player.aim = aim
		var physical_muzzle: Vector2 = Pose.muzzle_position(player)
		var physical_aim: Vector2 = Pose.aim_at(player, Vector2(700, 250))
		var socket: Vector2=landing.body.shoulder
		var expected_shoulder: Vector2 = Vector2(player.pos) + Vector2(socket.x if aim.x >= 0.0 else -socket.x,socket.y)
		var pose: Dictionary = world.weapon_draw_pose(player)
		stable = stable and pose.shoulder.is_equal_approx(expected_shoulder) and pose.aim.is_equal_approx(aim) and pose.muzzle.is_equal_approx(expected_shoulder + aim * Pose.muzzle_length("pulse_rifle"))
		var bullet: Dictionary = {"id": 700 + direction, "team": "player", "kind": "bullet", "owner": 1, "age": 1.0 / 60.0, "origin": physical_muzzle, "pos": physical_muzzle + aim * 10.0, "vel": aim * 600.0, "travel_distance": 10.0}
		snapshot.projectiles = [bullet]
		var before: PackedByteArray = var_to_bytes(snapshot)
		world._update_render_positions(0.0)
		var visual: Vector2 = world._entity_draw_position("b" + str(bullet.id), bullet.pos)
		origins = origins and visual.is_equal_approx(pose.muzzle)
		tails = tails and is_zero_approx(world.rendered_projectile_trail_length(bullet, visual, 100.0))
		immutable = immutable and before == var_to_bytes(snapshot) and Pose.muzzle_position(player).is_equal_approx(physical_muzzle) and Pose.aim_at(player, Vector2(700, 250)).is_equal_approx(physical_aim)
		var effect: Dictionary = world.muzzle_effect_pose({"owner": 1, "weapon": "pulse_rifle"})
		effects = effects and bool(effect.visible) and Vector2(effect.pos).is_equal_approx(pose.muzzle)
	_check(stable, "Landing shoulder mirrors with facing while all eight aim directions stay unchanged")
	_check(origins and tails, "Actual new-projectile visual bridging starts at the landing gun muzzle with zero reverse trail")
	_check(effects, "Landing muzzle flashes share the adjusted displayed gun origin")
	_check(immutable, "Landing attachments never change snapshots, ballistic origins, projectile travel or input aim")
	world._clock = 10.13
	var recovering: Dictionary = world.weapon_draw_pose(player)
	_check(float(recovering.body.landing)<float(landing.body.landing) and recovering.shoulder.is_equal_approx(Vector2(player.pos)+Vector2(recovering.body.shoulder)*Vector2(1 if player.aim.x>=0 else -1,1)), "Multi-frame landing recovery follows each selected frame's own attachment")
	world._clock = 10.25
	var recovered: Dictionary = world.weapon_draw_pose(player)
	_check(recovered.shoulder == Pose.shoulder_position(player.pos) and recovered.muzzle.is_equal_approx(Pose.muzzle_position(player)), "The weapon returns to its normal shoulder immediately when landing recovery finishes")
	world.free()
