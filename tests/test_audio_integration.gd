extends SceneTree

const Soundscape = preload("res://scripts/soundscape.gd")
const Content = preload("res://scripts/content.gd")

class AudioProbe extends Soundscape:
	var heard: Array = []
	func play_game_event(event: Dictionary, distance: float = 0.0) -> bool:
		heard.append({"event": event.duplicate(true), "distance": distance})
		return true

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
	var game = load("res://main.tscn").instantiate()
	var probe := AudioProbe.new()
	game.sound.free()
	game.sound = probe
	game._smoke = "audio-integration"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game._start_solo()
	var player: Dictionary = game.sim.state.players[1]
	var position_value: Vector2 = player.pos
	for weapon: String in ["pulse_rifle", "scattergun", "railgun", "arc_blade", "flamethrower", "boomerang", "storm_staff", "sun_lance"]:
		player.weapon = weapon
		game._local_fire_timer = 0.0
		probe.heard.clear()
		game._predict_attack_feedback({"fire":true, "aim":Vector2.RIGHT}, 1.0/60.0)
		_check(probe.heard.size() == 1 and probe.heard[0].event.weapon == weapon, "Predicted " + weapon + " preserves its identity through main audio dispatch")
	game.online = true
	game.hosting = false
	probe.heard.clear()
	game._consume_events([
		{"type":"shoot", "weapon":"railgun", "player":1, "pos":position_value},
		{"type":"shoot", "weapon":"scattergun", "player":2, "pos":position_value+Vector2(300,0)}
	])
	_check(probe.heard.size()==1 and probe.heard[0].event.player==2 and probe.heard[0].event.weapon=="scattergun", "Local predicted shots are not heard twice; authoritative teammate weapon identity survives")
	_check(is_equal_approx(probe.heard[0].distance,300.0), "Teammate attack audio keeps world-distance attenuation")
	probe.heard.clear()
	var reward: Dictionary = {"type":"pickup", "kind":"coin", "automatic":true, "player":2, "amount":9, "pos":position_value+Vector2(6000,0)}
	game._consume_events([reward])
	_check(probe.heard.size()==1 and is_zero_approx(probe.heard[0].distance) and probe.heard[0].event.amount==9, "Shared gold is audible even when a teammate's kill is across the map")
	probe.heard.clear()
	var item: Dictionary = {"type":"pickup", "kind":"item", "item":"phoenix", "player":1, "pos":position_value}
	game._consume_events([item])
	_check(probe.heard.size()==1 and probe.heard[0].event.rarity==game.sim.loot_definition("phoenix").rarity, "Actual item pickup dispatch includes the catalog rarity for its sound")
	_check(not item.has("rarity"), "Audio enrichment never changes replicated source events")
	probe.heard.clear()
	game._consume_events([
		{"type":"jump", "double":true, "player":1, "pos":position_value},
		{"type":"land", "player":1, "pos":position_value},
		{"type":"equipment", "equipment":"meteor", "player":1, "pos":position_value}
	])
	_check(probe.heard.size()==3 and probe.heard[0].event.double and probe.heard[2].event.equipment=="meteor", "Movement and delayed-skill activation reach audio with their semantic details")
	probe.heard.clear()
	for source: String in ["missile_pod", "landing_coil", "frost_halo", "pursuit_protocol", "reactive_plating"]:
		var event: Dictionary = {"type":"proc", "kind":source, "player":1, "owner":1, "pos":position_value, "proc_id":100}
		var saved: PackedByteArray = var_to_bytes(event)
		game._consume_events([event])
		_check(var_to_bytes(event)==saved and not Soundscape.event_sound(event).is_empty(), source+" remains immutable and selects an audible trigger cue")
	_check(probe.heard.size()==5, "Authoritative local passive activations are heard by the client rather than suppressed as predicted attacks")
	_check(game.TRANSIENT_EVENT_TYPES.has("proc"), "Old stage passive effects use the transient event filter")
	game.online = false
	probe.shutdown()
	game.queue_free()
	await process_frame
	print("AUDIO_INTEGRATION_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed==0 else 1)
