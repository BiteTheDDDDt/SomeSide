extends SceneTree

const Motion = preload("res://scripts/weapon_action_motion.gd")
const Pose = preload("res://scripts/weapon_pose.gd")
var passed: int = 0
var failed: int = 0
var game: Node
var sim: Variant
var world: Variant

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _fresh(weapon: String) -> Dictionary:
	sim.start_run([{"id": 1, "name": "Local", "character": "ranger"}, {"id": 2, "name": "Remote", "character": "ranger"}], 15107)
	sim.state.enemies.clear()
	sim.events.clear()
	for player: Dictionary in sim.state.players.values():
		player.weapon = weapon
		player.pos = Vector2(700 + int(player.id) * 120, float(sim.state.floor_y) - 21)
		player.vel = Vector2.ZERO
		player.aim = Vector2.RIGHT
		player.grounded = true
		player.invuln = 0.0
	game.online = false
	game.hosting = false
	game.local_id = 1
	game.screen = "playing"
	game._local_fire_timer = 0.0
	game._predicted_attack_count = 0
	world.interpolate_remote_entities = false
	world.combat_paused = false
	world._combat_clock = 0.0
	world._clock = 0.0
	world._last_snapshot_time = -1.0
	world._render_stage = -1
	world._weapon_tracks.clear()
	world._weapon_predictions.clear()
	world._effects.clear()
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	return sim.state.players[1]

func _primary(events: Array, owner: int) -> Dictionary:
	for event: Dictionary in events:
		if event.has("weapon") and int(event.get("player", -1)) == owner: return event
	return {}

func _sample(owner: int = 1) -> Dictionary:
	return world.weapon_draw_pose(world._frame.players[owner])

func _actual_actions(weapon: String) -> void:
	var player: Dictionary = _fresh(weapon)
	sim._fire_weapon(player)
	var event: Dictionary = _primary(sim.events, 1)
	_check(not event.is_empty() and player.has("attack_pose") and event.get("attack_id", -1) == player.attack_pose.id and float(event.get("duration", 0.0)) > 0.0, weapon + ": actual authority fire publishes a matching action ID and duration")
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	game._consume_events(sim.events)
	var duration: float = float(event.get("duration", 0.1))
	world._process(duration * 0.20)
	var before_state: PackedByteArray = var_to_bytes(sim.state)
	var before_frame: PackedByteArray = var_to_bytes(world._frame)
	var pose: Dictionary = _sample()
	_check(pose.ranged.active and Vector2(pose.ranged.offset).length() > 0.5 and Vector2(pose.weapon_origin).distance_to(pose.shoulder) > 0.5, weapon + ": the actual World pose moves the visible weapon during follow-through")
	var joined: bool = true
	var turns: bool = true
	var track_start: float = float(world._weapon_tracks[1].start)
	var initial_tip: Vector2 = pose.muzzle
	for aim: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2(-1, -1).normalized()]:
		player.aim = aim
		world.set_frame(sim.get_snapshot(), 1, 0.0)
		pose = _sample()
		var axis := Vector2.from_angle(float(pose.get("weapon_angle", 0.0)))
		var tip: Vector2 = Vector2(pose.get("weapon_origin", Vector2.INF)) + axis * Pose.muzzle_length(weapon)
		var flash: Dictionary = world.muzzle_effect_pose({"weapon": weapon, "owner": 1, "pos": Vector2.ZERO})
		joined = joined and Vector2(pose.muzzle).is_equal_approx(tip) and Vector2(flash.pos).is_equal_approx(tip) and Vector2(flash.aim).is_equal_approx(axis)
		turns = turns and bool(pose.ranged.active) and Vector2(pose.aim).is_equal_approx(aim) and is_equal_approx(float(world._weapon_tracks[1].start), track_start)
	_check(joined, weapon + ": the moving muzzle and flash equal weapon origin + current weapon axis × barrel length in five aim directions")
	_check(turns and initial_tip.distance_to(pose.muzzle) > 10.0, weapon + ": live aim turns immediately without cancelling or restarting the active action")
	# Only our explicit aim changes above are allowed; rendering is read-only.
	player.aim = Vector2.RIGHT
	_check(before_state == var_to_bytes(sim.state), weapon + ": all presentation sampling leaves the authority snapshot unchanged")
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	_sample()
	_check(before_frame == var_to_bytes(world._frame), weapon + ": repeated pose/flash sampling never annotates the render snapshot")
	world.combat_paused = true
	var frozen: float = float(_sample().ranged.elapsed)
	world._process(0.2)
	_check(is_equal_approx(float(_sample().ranged.elapsed), frozen), weapon + ": solo combat pause freezes the action timeline")
	world.combat_paused = false
	world._process(duration + 0.001)
	_check(not _sample().ranged.active, weapon + ": completed follow-through returns to the normal aim pose")

func _projectile_bridge(weapon: String) -> void:
	var player: Dictionary = _fresh(weapon)
	sim._fire_weapon(player)
	var dt: float = 1.0 / 60.0
	sim._step_player(player, {"aim": Vector2.RIGHT}, dt)
	sim._step_projectiles(dt)
	sim.state.time += dt
	world._process(dt)
	var snapshot: Dictionary = sim.get_snapshot()
	var before: PackedByteArray = var_to_bytes(snapshot)
	world.set_frame(snapshot, 1, 0.0)
	var pose: Dictionary = _sample()
	if weapon == "flamethrower":
		var flash: Dictionary = world.muzzle_effect_pose({"weapon": weapon, "owner": 1})
		_check(sim.state.projectiles.is_empty() and Vector2(flash.pos).is_equal_approx(pose.muzzle) and pose.ranged.active, "flamethrower: the real cone has an animated origin without inventing a projectile")
		return
	var joined: bool = not sim.state.projectiles.is_empty()
	for projectile: Dictionary in sim.state.projectiles:
		var key: String = "b" + str(projectile.id)
		var sample: Dictionary = world._fixed_samples.get(key, {})
		var position: Vector2 = world._entity_draw_position(key, projectile.pos)
		joined = joined and sample.has("launch_origin") and Vector2(sample.get("launch_origin", Vector2.INF)).is_equal_approx(pose.muzzle) and position.is_equal_approx(pose.muzzle)
		joined = joined and is_zero_approx(world.rendered_projectile_trail_length(projectile, position, 80.0))
	_check(joined and pose.ranged.active and before == var_to_bytes(snapshot), weapon + ": every new real projectile begins visually at the active gun tip with zero backward tail")
	world._process(dt * 0.5)
	world.set_frame(snapshot, 1, dt * 0.5)
	var tails_bounded: bool = true
	for projectile: Dictionary in sim.state.projectiles:
		var key: String = "b" + str(projectile.id)
		var sample: Dictionary = world._fixed_samples[key]
		var position: Vector2 = world._entity_draw_position(key, projectile.pos)
		var projected: float = maxf(0.0, (position - Vector2(sample.get("launch_origin", position))).dot(Vector2(projectile.vel).normalized()))
		tails_bounded = tails_bounded and world.rendered_projectile_trail_length(projectile, position, 80.0) <= projected + 0.001
	_check(tails_bounded, weapon + ": the interpolated first-flight tail cannot extend behind its visible launch bridge")

func _prediction(weapon: String) -> void:
	var player: Dictionary = _fresh(weapon)
	game.online = true
	var before: PackedByteArray = var_to_bytes(sim.state)
	game._predict_attack_feedback({"fire": true, "aim": Vector2.RIGHT}, 0.0)
	var initial: Dictionary = _sample()
	_check(initial.ranged.active and initial.ranged.predicted and before == var_to_bytes(sim.state) and sim.state.projectiles.is_empty(), weapon + ": the real main prediction animates immediately without changing authority or spawning bullets")
	var duration: float = initial.ranged.duration
	world._process(duration * 0.25)
	var start: float = world._weapon_tracks[1].start
	var action_id: int = world._weapon_tracks[1].id
	var effect_count: int = world._effects.size()
	game._predict_attack_feedback({"fire": true, "aim": Vector2.UP}, 0.0)
	_check(world._weapon_tracks[1].id == action_id and world._effects.size() == effect_count, weapon + ": holding fire during the existing cooldown does not retrigger predicted actions")
	# Execute the same shot on the authority, then route its response through
	# the actual owning-client event filter and snapshot presentation path.
	sim._fire_weapon(player)
	var event: Dictionary = _primary(sim.events, 1)
	game._consume_events([event])
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	var confirmed: Dictionary = _sample()
	_check(world._effects.size() == effect_count and world._weapon_tracks[1].id == action_id and is_equal_approx(float(world._weapon_tracks[1].start), start) and float(confirmed.ranged.elapsed) > 0.0, weapon + ": its authority reply and snapshot do not replay the predicted action or duplicate the flash")

func _snapshot_only(weapon: String) -> void:
	_fresh(weapon)
	var remote: Dictionary = sim.state.players[2]
	sim._fire_weapon(remote)
	var duration: float = remote.attack_pose.duration
	sim._step_player(remote, {"aim": Vector2.LEFT}, duration * 0.22)
	sim.state.time += duration * 0.22
	world.interpolate_remote_entities = true
	# No push_events/consume_events call: reconstruct solely from a snapshot.
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	var state_before: PackedByteArray = var_to_bytes(sim.state)
	var remote_pose: Dictionary = _sample(2)
	_check(remote_pose.ranged.active and not remote_pose.ranged.predicted and Vector2(remote_pose.ranged.offset).length() > 0.5 and Vector2(remote_pose.aim).is_equal_approx(Vector2.LEFT) and state_before == var_to_bytes(sim.state), weapon + ": a snapshot-only teammate resumes its in-progress action at the live aim direction")
	var start: float = world._weapon_tracks[2].start
	world.push_events([_primary(sim.events, 2)])
	_check(is_equal_approx(float(world._weapon_tracks[2].start), start), weapon + ": a delayed matching remote fire event cannot rewind snapshot-restored animation")

func _cancellation_and_speed() -> void:
	for weapon: String in Motion.WEAPONS:
		var player: Dictionary = _fresh(weapon)
		player.items = {"overclock": 10000}
		player.chrono_timer = 5.0
		sim._fire_weapon(player)
		world.set_frame(sim.get_snapshot(), 1, 0.0)
		var active: Dictionary = _sample().ranged
		var interval: float = sim.attack_interval(player)
		sim._step_player(player, {"aim": Vector2.RIGHT}, interval)
		world._process(interval)
		world.set_frame(sim.get_snapshot(), 1, 0.0)
		_check(active.active and float(active.duration) < interval and not player.has("attack_pose") and not _sample().ranged.active, weapon + ": maximum real stacked attack speed ends one action before the next fire opportunity")
	var player: Dictionary = _fresh("railgun")
	sim._fire_weapon(player)
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	_sample()
	sim._spawn_pickup(player.pos, "item", "scattergun", 1)
	var pickup: Dictionary = sim.state.pickups.back()
	sim._take_loot(player, pickup)
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	_check(player.weapon == "scattergun" and not player.has("attack_pose") and not _sample().ranged.active and not world._weapon_tracks.has(1), "Picking up a different actual weapon cancels the old action on authority and renderer")
	sim._fire_weapon(player)
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	_sample()
	sim._damage_player(player, 99999.0, player.pos + Vector2.RIGHT)
	sim._step_player(player, {}, 1.0 / 60.0)
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	_check(player.dead and not player.has("attack_pose") and not _sample().ranged.active and not world._weapon_tracks.has(1), "Actual lethal damage cancels both the replicated action and visible weapon movement")
	player = _fresh("storm_staff")
	game._predict_attack_feedback({"fire": true, "aim": Vector2.RIGHT}, 0.0)
	_check(not world._weapon_predictions.is_empty(), "Stage-transition fixture contains a live prediction watermark")
	sim._build_stage(2)
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	_check(not player.has("attack_pose") and world._weapon_tracks.is_empty() and world._weapon_predictions.is_empty() and not _sample().ranged.active, "Changing region clears old actions and prediction watermarks before IDs restart")
	sim._fire_weapon(player)
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	_check(_sample().ranged.active, "The first real shot in the new region animates after the attack counter resets")
	var remote: Dictionary = sim.state.players[2]
	sim._fire_weapon(remote)
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	_sample(2)
	sim.state.players.erase(2)
	world.set_frame(sim.get_snapshot(), 1, 0.0)
	_check(not world._weapon_tracks.has(2), "Removing a disconnected teammate also removes its action track")

func _run() -> void:
	var existed: bool = FileAccess.file_exists("user://profile.cfg")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()
	game = load("res://main.tscn").instantiate()
	game._smoke = "ranged-actions"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.shutdown()
	sim = game.sim
	world = game.world
	world.set_process(false)
	world.menu_preview = false
	for weapon: String in Motion.WEAPONS:
		_actual_actions(weapon)
		_projectile_bridge(weapon)
		_prediction(weapon)
		_snapshot_only(weapon)
	_cancellation_and_speed()
	var after: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if FileAccess.file_exists("user://profile.cfg") else PackedByteArray()
	_check(FileAccess.file_exists("user://profile.cfg") == existed and after == saved, "Integrated ranged-action fixtures do not touch the user's profile")
	game.queue_free()
	await process_frame
	print("RANGED_ACTIONS_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)
