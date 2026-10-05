extends SceneTree

## Uses the production RPC, input redundancy, authoritative simulation,
## reconciliation, event de-duplication and world melee presentation.
class AudioProbe:
	extends "res://scripts/soundscape.gd"
	var heard: Array = []
	func play_game_event(event: Dictionary, distance: float = 0.0) -> bool:
		if event.get("weapon") == "arc_blade" and event.get("type") == "slash":
			heard.append(event.duplicate(true))
		return true

class MeleeProbe:
	extends "res://scripts/main.gd"
	var expected_ids: Array = []
	var authority_records: Dictionary = {}
	var received_melee: Dictionary = {}
	var visible_melee: Dictionary = {}
	var visible_seconds: Dictionary = {}
	var predicted_durations: Array = []
	var predicted_starts: int = 0
	var received_own_starts: int = 0
	var received_remote_starts: int = 0
	var duplicated_own_audio: int = 0
	var duplicate_attack_ids: int = 0
	var predicted_ids: Dictionary = {}
	var hit_snapshot_updates: int = 0
	var last_enemy_hp: Dictionary = {}

	func _ready() -> void:
		super._ready()
		_options["duration"] = clampf(float(_options.get("duration", 18.0)), 12.0, 40.0)

	func _begin_local(members: Array, seed_value: int) -> void:
		super._begin_local(members, seed_value)
		expected_ids.clear()
		sim.state.world_size = Vector2(4000.0, 1100.0)
		sim.state.floor_y = 1000.0
		sim.state.platforms = [Rect2(0.0, 1000.0, 4000.0, 60.0)]
		sim.state.chests = []
		sim.state.enemies = []
		sim._spawn_clock = 9999.0
		var slot: int = 0
		for player: Dictionary in sim.state.players.values():
			var id: int = int(player.id)
			expected_ids.append(id)
			player.pos = Vector2(500.0 + slot * 700.0, 979.0)
			player.vel = Vector2.ZERO
			player.grounded = true
			player.weapon = "arc_blade"
			player.equipment = "aegis"
			player.aim = Vector2.RIGHT
			player.invuln = 9999.0
			player.explore_anchor = player.pos
			player.explore_sites = [player.pos]
			authority_records[str(id)] = {"starts": 0, "hits": 0, "ids": {}}
			received_melee[str(id)] = 0
			visible_melee[str(id)] = 0
			visible_seconds[str(id)] = 0.0
			if hosting:
				var target: Dictionary = sim._spawn_enemy("crawler", Vector2(player.pos) + Vector2(70.0, 0.0))
				target.hp = 10000.0
				target.max_hp = 10000.0
				target.stun_timer = 9999.0
			slot += 1

	func _get_command() -> Dictionary:
		# A brief held-fire window tolerates transport sampling while remaining
		# shorter than one cooldown. Each separated window can accept one slash.
		return {"move": 0.0, "jump": false, "jump_held": false, "drop": false,
			"aim": Vector2.RIGHT, "fire": _tick > 90 and _tick % 48 < 8,
			"skill": false, "dash": false, "interact": false}

	func _predict_attack_feedback(command: Dictionary, delta: float) -> void:
		var before: int = sound.heard.size()
		super._predict_attack_feedback(command, delta)
		for index in range(before, sound.heard.size()):
			var event: Dictionary = sound.heard[index]
			predicted_starts += 1
			predicted_durations.append(float(event.get("duration", 0.0)))
			var id: int = int(event.get("attack_id", -1))
			if predicted_ids.has(id): duplicate_attack_ids += 1
			predicted_ids[id] = true

	func _consume_events(events: Array) -> void:
		var before: int = sound.heard.size()
		for event: Dictionary in events:
			if event.get("type") == "slash" and event.get("weapon") == "arc_blade":
				var id: String = str(event.get("player", -1))
				if hosting and authority_records.has(id):
					var record: Dictionary = authority_records[id]
					var attack_id: int = int(event.get("attack_id", -1))
					if record.ids.has(str(attack_id)): duplicate_attack_ids += 1
					record.ids[str(attack_id)] = true
					record.starts += 1
				elif not hosting:
					if int(event.get("player", -1)) == local_id: received_own_starts += 1
					else: received_remote_starts += 1
			if hosting and event.get("type") == "hit" and event.has("owner") and not event.get("friendly", false):
				var id: String = str(event.owner)
				if authority_records.has(id): authority_records[id].hits += 1
		super._consume_events(events)
		if not hosting:
			for index in range(before, sound.heard.size()):
				if int(sound.heard[index].get("player", -1)) == local_id: duplicated_own_audio += 1

	func _receive_snapshot(snapshot: Dictionary) -> void:
		var before: int = _snapshots_received
		super._receive_snapshot(snapshot)
		if before == _snapshots_received: return
		for player: Dictionary in Dictionary(snapshot.get("players", {})).values():
			var id: String = str(player.id)
			if not Dictionary(player.get("melee", {})).is_empty():
				received_melee[id] = int(received_melee.get(id, 0)) + 1
		for enemy: Dictionary in Array(snapshot.get("enemies", [])):
			var id: String = str(enemy.id)
			var health: float = float(enemy.hp)
			if health < float(last_enemy_hp.get(id, health)): hit_snapshot_updates += 1
			last_enemy_hp[id] = health

	func _process(delta: float) -> void:
		super._process(delta)
		if screen != "playing": return
		for player: Dictionary in sim.state.players.values():
			if bool(world.melee_pose(player).get("active", false)):
				var id: String = str(player.id)
				visible_melee[id] = int(visible_melee.get(id, 0)) + 1
				visible_seconds[id] = float(visible_seconds.get(id, 0.0)) + minf(delta, 0.1)

	func _finish_automation() -> void:
		_smoke_finished = true
		var accepted: bool = _started and expected_ids.size() == int(_options.get("expected-players", 4)) and duplicate_attack_ids == 0
		for id: int in expected_ids:
			if hosting:
				var record: Dictionary = authority_records[str(id)]
				accepted = accepted and int(record.hits) >= 6 and int(record.starts) - int(record.hits) in [0, 1] and record.ids.size() == int(record.starts)
			else:
				accepted = accepted and int(received_melee.get(str(id), 0)) >= 3 and int(visible_melee.get(str(id), 0)) >= 3
		if hosting:
			accepted = accepted and _inputs_received > 120
		else:
			accepted = accepted and predicted_starts >= 6 and received_own_starts >= 6 and received_remote_starts >= 12 and duplicated_own_audio == 0 and hit_snapshot_updates >= 12 and _snapshots_received > 60
			accepted = accepted and float(visible_seconds.get(str(local_id), 0.0)) / maxf(1.0, predicted_starts) > 0.20
			accepted = accepted and predicted_durations.all(func(value: float): return is_equal_approx(value, 0.36))
		var report: Dictionary = {"passed": accepted, "mode": _smoke, "local_id": local_id, "expected_ids": expected_ids,
			"started": _started, "inputs": _inputs_received, "snapshots": _snapshots_received,
			"predicted_starts": predicted_starts, "received_own_starts": received_own_starts, "received_remote_starts": received_remote_starts,
			"duplicated_own_audio": duplicated_own_audio, "duplicate_attack_ids": duplicate_attack_ids,
			"authority": authority_records if hosting else {}, "received_melee": received_melee, "visible_melee": visible_melee,
			"visible_seconds": visible_seconds, "predicted_durations": predicted_durations,
			"hit_snapshot_updates": hit_snapshot_updates, "elapsed": _elapsed, "tick": _tick,
			"main_sha256": FileAccess.get_sha256("res://scripts/main.gd"), "simulation_sha256": FileAccess.get_sha256("res://scripts/simulation.gd")}
		if _options.has("report"):
			var file: FileAccess = FileAccess.open(str(_options.report), FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(report, "\t"))
		print("NETWORK_MELEE_V015_RESULT ", JSON.stringify(report))
		_quit_game(0 if accepted else 1)

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.has("--smoke-host") and not arguments.has("--smoke-client"):
		push_error("Use --smoke-host or --smoke-client for this bounded network fixture.")
		quit(2)
		return
	var game := MeleeProbe.new()
	game.sound.free()
	game.sound = AudioProbe.new()
	game.name = "NetworkMeleeProbe"
	root.add_child(game)
