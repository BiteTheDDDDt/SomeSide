extends SceneTree

const Pose = preload("res://scripts/weapon_pose.gd")
const Content = preload("res://scripts/content.gd")
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
	var game: Node = load("res://main.tscn").instantiate()
	game.set("_smoke", "ui")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var world: Node = game.get("world")
	world.set_process(false)
	game.get("sound").shutdown()
	var simulation: Variant = game.get("sim")
	simulation.start_run([{"id": 1, "name": "Local", "character": "ranger"}, {"id": 2, "name": "Remote", "character": "ranger"}], 2606)
	simulation.state.enemies.clear()
	var player: Dictionary = simulation.state.players[1]
	player.pos = Vector2(700, 500)
	player.items = {"toxin": 4, "nova": 8}
	var prediction_positions: bool = true
	var authority_positions: bool = true
	var prediction_strengths: bool = true
	var state_untouched: bool = true
	for definition: Dictionary in Content.weapons():
		player.weapon = definition.id
		for index: int in range(8):
			var aim: Vector2 = Vector2.from_angle(float(index) * TAU / 8.0)
			player.aim = aim
			world.call("set_frame", simulation.get_snapshot(), 1, 1.0 / 60.0)
			world.get("_effects").clear()
			game.set("_local_fire_timer", 0.0)
			var before: Dictionary = simulation.get_snapshot()
			game.call("_predict_attack_feedback", {"fire": true, "aim": aim}, 1.0 / 60.0)
			state_untouched = state_untouched and before == simulation.get_snapshot()
			var primary: Dictionary = {}
			for effect: Dictionary in world.get("_effects"):
				if effect.kind in ["muzzle", "slash", "flame"]:
					primary = effect
			prediction_positions = prediction_positions and not primary.is_empty() and Vector2(primary.get("pos", Vector2.ZERO)).is_equal_approx(Pose.muzzle_position(player))
			simulation.events.clear()
			simulation.state.projectiles.clear()
			simulation._fire_weapon(player)
			var authoritative: Dictionary = {}
			for event: Dictionary in simulation.events:
				if event.has("weapon"):
					authoritative = event
			authority_positions = authority_positions and not authoritative.is_empty() and Vector2(authoritative.get("pos", Vector2.ZERO)).is_equal_approx(Vector2(primary.get("pos", Vector2.ZERO)))
			prediction_strengths = prediction_strengths and is_equal_approx(float(primary.get("strength", 0.0)), world.call("effect_strength", authoritative))
	_check(prediction_positions, "Every locally predicted weapon emits feedback at its muzzle in eight aim directions")
	_check(authority_positions, "Actual authority attacks and local prediction share the same origins after every weapon switch")
	_check(prediction_strengths, "Predicted attacks preserve the real high-stack effect strength of newer relics")
	_check(state_untouched, "Predicting attack feedback never changes authoritative players, enemies or projectiles")

	player.weapon = "pulse_rifle"
	player.aim = Vector2.RIGHT
	world.call("set_frame", simulation.get_snapshot(), 1, 1.0 / 60.0)
	game.set("online", true)
	game.set("hosting", false)
	var local_shot: Dictionary = {"type": "shoot", "kind": "bullet", "weapon": "pulse_rifle", "player": 1, "pos": Pose.muzzle_position(player), "aim": Vector2.RIGHT}
	world.get("_effects").clear()
	var counted: int = int(game.get("_events_seen"))
	game.call("_consume_events", [local_shot])
	_check(world.get("_effects").is_empty() and int(game.get("_events_seen")) == counted + 1, "An owning client consumes the authority event without a second predicted muzzle flash")
	var remote_shot: Dictionary = local_shot.duplicate(true)
	remote_shot.player = 2
	game.call("_consume_events", [remote_shot])
	_check(_count_kind(world, "muzzle") == 1, "Another player's primary attack remains visible to the client")
	world.get("_effects").clear()
	var grenade: Dictionary = local_shot.duplicate(true)
	grenade.erase("weapon")
	grenade.kind = "grenade"
	game.call("_consume_events", [grenade])
	_check(_count_kind(world, "muzzle") == 1, "The client's authoritative active equipment effect is not mistaken for a predicted primary attack")
	world.get("_effects").clear()
	game.set("hosting", true)
	game.call("_consume_events", [local_shot])
	_check(_count_kind(world, "muzzle") == 1, "The host still displays its own authoritative muzzle flash")
	world.get("_effects").clear()
	game.set("online", false)
	game.call("_consume_events", [local_shot])
	_check(_count_kind(world, "muzzle") == 1, "Solo play still displays authoritative primary attacks")
	game.queue_free()
	await process_frame
	print("WEAPON_FEEDBACK_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _count_kind(world: Node, kind: String) -> int:
	var count: int = 0
	for effect: Dictionary in world.get("_effects"):
		if effect.kind == kind:
			count += 1
	return count
