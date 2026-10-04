extends SceneTree

## Real ENet input/reconciliation acceptance fixture. The main game's transport,
## RPC input validation, acknowledgements and replay all remain in the base class.
class ControlProbe:
	extends "res://scripts/main.gd"
	var authority_tracks: Dictionary = {}
	var received_tracks: Dictionary = {}
	var predicted_tracks: Dictionary = {}
	var expected_ids: Array = []
	var short_commands: int = 0
	var long_commands: int = 0

	func _ready() -> void:
		super._ready()
		# Direct invocations are bounded too, even without the PowerShell runner.
		_options["duration"] = clampf(float(_options.get("duration", 18.0)), 12.0, 64.0)

	func _begin_local(members: Array, seed_value: int) -> void:
		super._begin_local(members, seed_value)
		authority_tracks.clear()
		received_tracks.clear()
		predicted_tracks.clear()
		expected_ids.clear()
		for player: Dictionary in sim.state.players.values():
			player.invuln = 1000.0
			expected_ids.append(int(player.id))
			_prepare_track(authority_tracks, player)
			_prepare_track(received_tracks, player)
			if int(player.id) == local_id:
				_prepare_track(predicted_tracks, player)

	func _get_command() -> Dictionary:
		var command: Dictionary = {"move": 0.0, "jump": false, "jump_held": false, "drop": false, "aim": Vector2.RIGHT, "fire": false, "skill": false, "dash": false, "interact": false}
		# Leave twelve initial physics ticks for startup/snapshot synchronization.
		if _tick < 12:
			return command
		var elapsed_ticks: int = _tick - 12
		var cycle: int = elapsed_ticks / 90
		var phase: int = elapsed_ticks % 90
		var hold_ticks: int = 3 if cycle % 2 == 0 else 30
		command.jump = phase == 0
		command.jump_held = phase < hold_ticks
		if phase == 0:
			if hold_ticks == 3:
				short_commands += 1
			else:
				long_commands += 1
		return command

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if screen != "playing":
			return
		if hosting:
			for player: Dictionary in sim.state.players.values():
				_sample_track(authority_tracks, player)
		elif sim.state.players.has(local_id):
			_sample_track(predicted_tracks, sim.state.players[local_id])

	func _receive_snapshot(snapshot: Dictionary) -> void:
		var before: int = _snapshots_received
		super._receive_snapshot(snapshot)
		if _snapshots_received != before:
			# Inspect the untouched authority snapshot, before any local predicted
			# position can be mistaken for server proof of jump-height control.
			for player: Dictionary in Dictionary(snapshot.get("players", {})).values():
				_sample_track(received_tracks, player)

	func _prepare_track(tracks: Dictionary, player: Dictionary) -> void:
		tracks[str(player.id)] = {"ground_y": Vector2(player.pos).y, "peak_y": Vector2(player.pos).y, "airborne": false, "heights": [], "samples": 0}

	func _sample_track(tracks: Dictionary, player: Dictionary) -> void:
		var id: String = str(player.id)
		if not tracks.has(id):
			_prepare_track(tracks, player)
		var track: Dictionary = tracks[id]
		track.samples = int(track.samples) + 1
		var y: float = Vector2(player.pos).y
		if bool(player.get("grounded", false)):
			if bool(track.airborne):
				var height: float = float(track.ground_y) - float(track.peak_y)
				if height > 5.0:
					track.heights.append(height)
					if track.heights.size() > 40:
						track.heights.pop_front()
			track.ground_y = y
			track.peak_y = y
			track.airborne = false
		elif bool(track.airborne) or Vector2(player.get("vel", Vector2.ZERO)).y < -1.0:
			track.airborne = true
			track.peak_y = minf(float(track.peak_y), y)

	func _summarize(tracks: Dictionary) -> Dictionary:
		var result: Dictionary = {}
		for id: String in tracks:
			var track: Dictionary = tracks[id]
			var heights: Array = track.heights
			var low: float = float(heights.min()) if not heights.is_empty() else 0.0
			var high: float = float(heights.max()) if not heights.is_empty() else 0.0
			var small: int = 0
			var full: int = 0
			for height: float in heights:
				if height < 90.0:
					small += 1
				if height > 110.0:
					full += 1
			var accepted: bool = heights.size() >= 4 and small >= 2 and full >= 2 and high - low > 30.0 and low >= 5.0 and high < 160.0
			result[id] = {"passed": accepted, "completed_jumps": heights.size(), "short_jumps": small, "long_jumps": full, "minimum_apex_px": low, "maximum_apex_px": high, "range_px": high - low, "heights_px": heights, "samples": track.samples}
		return result

	func _all_expected_pass(summary: Dictionary) -> bool:
		if expected_ids.size() != int(_options.get("expected-players", 2)):
			return false
		for id: int in expected_ids:
			if not bool(Dictionary(summary.get(str(id), {})).get("passed", false)):
				return false
		return true

	func _finish_automation() -> void:
		_smoke_finished = true
		var authority: Dictionary = _summarize(authority_tracks)
		var received: Dictionary = _summarize(received_tracks)
		var prediction: Dictionary = _summarize(predicted_tracks)
		var passed: bool = _started and short_commands >= 2 and long_commands >= 2
		if hosting:
			passed = passed and _inputs_received > 60 and _all_expected_pass(authority)
		else:
			passed = passed and _snapshots_received > 60 and _all_expected_pass(received) and bool(Dictionary(prediction.get(str(local_id), {})).get("passed", false))
		var report: Dictionary = {"passed": passed, "mode": _smoke, "local_id": local_id, "expected_ids": expected_ids, "started": _started, "max_players": _max_players, "inputs": _inputs_received, "snapshots": _snapshots_received, "elapsed": _elapsed, "tick": _tick, "short_commands": short_commands, "long_commands": long_commands, "authoritative": authority if hosting else {}, "received_authority": received if not hosting else {}, "local_prediction": prediction if not hosting else {}, "main_sha256": FileAccess.get_sha256("res://scripts/main.gd"), "simulation_sha256": FileAccess.get_sha256("res://scripts/simulation.gd")}
		if _options.has("report"):
			var file: FileAccess = FileAccess.open(str(_options.report), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(report, "\t"))
		print("NETWORK_CONTROLS_V09_RESULT ", JSON.stringify(report))
		_quit_game(0 if passed else 1)

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.has("--smoke-host") and not arguments.has("--smoke-client"):
		push_error("Use --smoke-host or --smoke-client; this fixture never runs interactively.")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var game := ControlProbe.new()
	# All peers need the same node path for the inherited real RPC endpoints.
	game.name = "NetworkControlProbe"
	root.add_child(game)
